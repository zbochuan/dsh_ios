#!/usr/bin/env python3
"""Generate the dependency-free Xcode project; --check detects source drift."""
import hashlib
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]


def identifier(value):
    return hashlib.sha256(value.encode()).hexdigest()[:24].upper()


def quote(value):
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'


def generate():
    objects = []

    def add(key, content):
        objects.append(f'\t\t{identifier(key)} = {{ {content} }};')
        return identifier(key)

    def array(ids):
        return '( ' + ', '.join(ids) + (',' if ids else '') + ' )'

    app_sources = sorted(ROOT.glob('App/**/*.swift'))
    test_sources = sorted(ROOT.glob('AppUITests/*.swift'))
    resources = [ROOT / 'App/Resources/Assets.xcassets', ROOT / 'App/Resources/PrivacyInfo.xcprivacy']
    references = []
    build_ids = {}
    for path in app_sources + test_sources + resources + [ROOT / 'App/Resources/Info.plist']:
        relative = path.relative_to(ROOT).as_posix()
        kind = 'sourcecode.swift' if path.suffix == '.swift' else 'folder.assetcatalog' if path.suffix == '.xcassets' else 'text.plist.xml'
        ref = add(relative, f'isa = PBXFileReference; lastKnownFileType = {kind}; path = {quote(relative)}; sourceTree = SOURCE_ROOT;')
        references.append(ref)
        build_ids[relative] = add('build:' + relative, f'isa = PBXBuildFile; fileRef = {ref};')

    app_product = add('app-product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = DSH.app; sourceTree = BUILT_PRODUCTS_DIR;')
    test_product = add('test-product', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = DSHUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
    products = add('products', f'isa = PBXGroup; children = {array([app_product, test_product])}; name = Products; sourceTree = "<group>";')
    main = add('main', f'isa = PBXGroup; children = {array(references + [products])}; sourceTree = "<group>";')
    package = add('package', 'isa = XCLocalSwiftPackageReference; relativePath = Packages/DSHCore;')
    dependency = add('core-product', f'isa = XCSwiftPackageProductDependency; package = {package}; productName = DSHCore;')
    core_build = add('core-build', f'isa = PBXBuildFile; productRef = {dependency};')

    def phase(key, kind, files):
        return add(key, f'isa = {kind}; buildActionMask = 2147483647; files = {array(files)}; runOnlyForDeploymentPostprocessing = 0;')

    app_phases = [phase('app-sources', 'PBXSourcesBuildPhase', [build_ids[p.relative_to(ROOT).as_posix()] for p in app_sources]), phase('app-frameworks', 'PBXFrameworksBuildPhase', [core_build]), phase('app-resources', 'PBXResourcesBuildPhase', [build_ids[p.relative_to(ROOT).as_posix()] for p in resources])]
    test_phases = [phase('test-sources', 'PBXSourcesBuildPhase', [build_ids[p.relative_to(ROOT).as_posix()] for p in test_sources]), phase('test-frameworks', 'PBXFrameworksBuildPhase', [])]

    def configurations(key, settings):
        ids = []
        for name in ['Debug', 'Release']:
            values = dict(settings)
            values.update({'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if name == 'Debug' else '-O', 'DEBUG_INFORMATION_FORMAT': 'dwarf' if name == 'Debug' else 'dwarf-with-dsym', 'ENABLE_TESTABILITY': 'YES' if name == 'Debug' else 'NO'})
            if name == 'Debug':
                values['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
            body = ' '.join(f'{k} = {quote(v)};' for k, v in sorted(values.items()))
            ids.append(add(key + name, f'isa = XCBuildConfiguration; buildSettings = {{ {body} }}; name = {name};'))
        return add(key + 'configs', f'isa = XCConfigurationList; buildConfigurations = {array(ids)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')

    project_configs = configurations('project', {'CLANG_ENABLE_MODULES': 'YES', 'SWIFT_VERSION': '6.0', 'IPHONEOS_DEPLOYMENT_TARGET': '17.0', 'SDKROOT': 'iphoneos', 'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator', 'TARGETED_DEVICE_FAMILY': '1,2', 'CODE_SIGN_STYLE': 'Automatic'})
    app_configs = configurations('app', {'PRODUCT_NAME': 'DSH', 'PRODUCT_BUNDLE_IDENTIFIER': 'app.dsh.ios', 'MARKETING_VERSION': '0.1.0', 'CURRENT_PROJECT_VERSION': '1', 'INFOPLIST_FILE': 'App/Resources/Info.plist', 'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon', 'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/Frameworks', 'GENERATE_INFOPLIST_FILE': 'NO', 'SWIFT_EMIT_LOC_STRINGS': 'YES'})
    test_configs = configurations('tests', {'PRODUCT_NAME': 'DSHUITests', 'PRODUCT_BUNDLE_IDENTIFIER': 'app.dsh.ios.uitests', 'GENERATE_INFOPLIST_FILE': 'YES', 'TEST_TARGET_NAME': 'DSH', 'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/Frameworks @loader_path/Frameworks'})
    proxy = add('proxy', f'isa = PBXContainerItemProxy; containerPortal = {identifier("project")}; proxyType = 1; remoteGlobalIDString = {identifier("app-target")}; remoteInfo = DSH;')
    target_dependency = add('test-dependency', f'isa = PBXTargetDependency; target = {identifier("app-target")}; targetProxy = {proxy};')
    app = add('app-target', f'isa = PBXNativeTarget; buildConfigurationList = {app_configs}; buildPhases = {array(app_phases)}; buildRules = (); dependencies = (); name = DSH; packageProductDependencies = {array([dependency])}; productName = DSH; productReference = {app_product}; productType = "com.apple.product-type.application";')
    tests = add('test-target', f'isa = PBXNativeTarget; buildConfigurationList = {test_configs}; buildPhases = {array(test_phases)}; buildRules = (); dependencies = {array([target_dependency])}; name = DSHUITests; productName = DSHUITests; productReference = {test_product}; productType = "com.apple.product-type.bundle.ui-testing";')
    project = add('project', f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2620; TargetAttributes = {{ {app} = {{ CreatedOnToolsVersion = 26.2; }}; {tests} = {{ CreatedOnToolsVersion = 26.2; TestTargetID = {app}; }}; }}; }}; buildConfigurationList = {project_configs}; compatibilityVersion = "Xcode 14.0"; developmentRegion = zh_CN; hasScannedForEncodings = 0; knownRegions = (en, zh_CN, Base); mainGroup = {main}; packageReferences = {array([package])}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = {array([app, tests])};')
    return '// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n' + '\n'.join(objects) + f'\n\t}};\n\trootObject = {project};\n}}\n'


if __name__ == '__main__':
    path = ROOT / 'DSH.xcodeproj/project.pbxproj'
    content = generate()
    if '--check' in sys.argv:
        if not path.exists() or path.read_text() != content:
            sys.exit('Xcode project is stale. Run python3 -I scripts/generate_xcode_project.py')
        print('Xcode source references are current.')
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        print('Generated DSH.xcodeproj/project.pbxproj')
