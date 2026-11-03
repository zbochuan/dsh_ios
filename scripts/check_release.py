#!/usr/bin/env python3
"""Validate both build configurations and require a matching release tag."""
import json
import os
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parents[1]
project = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(root / 'DSH.xcodeproj/project.pbxproj')]))
settings = [obj['buildSettings'] for obj in project['objects'].values() if obj.get('isa') == 'XCBuildConfiguration' and obj.get('buildSettings', {}).get('PRODUCT_NAME') == 'DSH']
assert len(settings) == 2, 'Expected Debug and Release app configurations'
versions = {item['MARKETING_VERSION'] for item in settings}
builds = {item['CURRENT_PROJECT_VERSION'] for item in settings}
assert len(versions) == len(builds) == 1, 'Configuration versions differ'
version = versions.pop()
build = builds.pop()
assert re.fullmatch(r'\d+\.\d+\.\d+', version), 'Invalid marketing version'
assert re.fullmatch(r'[1-9]\d*', build), 'Build number must be positive'
ref = os.environ.get('GITHUB_REF', '')
if ref:
    assert ref == f'refs/tags/ios-v{version}', f'Select tag ios-v{version} when dispatching the rehearsal'
revision = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip()
print(f'Version {version}, build {build}, revision {revision}')
print('Unsigned rehearsal only; App Store Connect build-number availability is not checked.')
