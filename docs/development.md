# Development and CI/CD

English | [中文](development.zh.md)

## Local documentation checks

Use Python 3.11 or newer from the repository root. The checker has no third-party dependencies:

```bash
python3 -I scripts/check_docs.py
```

After updating and reviewing both languages, refresh the named synchronization records and run the complete check again:

```bash
python3 -I scripts/check_docs.py --record README.md docs/development.md
```

When changing the checker, also run its failure-case tests:

```bash
python3 -I scripts/test_check_docs.py
```

The [bilingual contract](i18n/README.md) defines what the checker verifies and what review still owns.

## Application development

Open `DSH.xcodeproj`, select the shared `DSH` scheme, and choose an iPhone or iPad simulator. The deployment target is iOS 17.0; source uses Swift 6. The bundle identifier `app.dsh.ios` is a development placeholder. No signing team or device identifier is stored in the project; supply device-test signing through local build settings and keep it out of Git. Open the example task on the first screen to load local example tasks, including a pending approval. Server login and discovery require an explicitly entered HTTPS Remote Server and its account, not a DeepSeek model key.

Run the independent core tests on macOS:

```bash
swift test --package-path Packages/DSHCore
```

The Xcode project has no generator dependency. After adding or removing Swift source files, regenerate its deterministic references:

```bash
python3 -I scripts/generate_xcode_project.py
```

Run the same core and simulator checks as CI, with Xcode 26.2 and the iOS 26.2 iPhone 17 Pro runtime installed:

```bash
bash scripts/check_ios.sh
```

Override `DSH_SIMULATOR_DESTINATION` when using another installed simulator, for example `platform=iOS Simulator,name=iPhone 18 Pro,OS=27.2`. The script adds the native host architecture when `arch` is omitted and sets `ONLY_ACTIVE_ARCH=YES`; an explicit destination architecture is preserved. This avoids ambiguous simulator selection choosing x86_64 on Apple silicon. An unsigned compile does not need a bootable simulator runtime:

```bash
xcodebuild -project DSH.xcodeproj -scheme DSH -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

The app icon is original vector geometry rasterized by [the generator](../scripts/generate_app_icon.swift); its PNG is a source asset, not a build product. There are no external Swift package dependencies, so no `Package.resolved` is needed yet. Generated build directories, test results and signing material are ignored by Git.

## Active CI

[Documentation CI](../.github/workflows/docs.yml) runs on pull requests, pushes to `main`, and manual dispatch. It checks the complete Markdown corpus with Python 3.13 on Ubuntu. Read-only repository permissions, disabled persisted checkout credentials, and per-ref cancellation keep validation independent from publishing.

[iOS CI](../.github/workflows/ios.yml) runs for application changes and manual dispatch on `macos-15`, explicitly selecting Xcode 26.2 and iPhone 17 Pro / iOS 26.2. It invokes [check_ios.sh](../scripts/check_ios.sh), checking project references, core tests and unsigned simulator UI tests. Result bundles are retained for seven days. Documentation-only changes do not allocate a macOS runner. These workflows have been added but no GitHub run is claimed until they are pushed and executed.

The core tests cover Server request shapes, invalid responses, redirect rejection, identity/credential lifecycle, Noise vectors and corruption, secure fragmentation, demo completion without duplicate messages, late chunks after interruption, and stale/consumed approvals. The task-console UI suite covers the connect and example entries, pairing, blank input, send/stop/continuation, starting a task from home, draft retention across new tasks and cancelled login, approval close/allow/reject/reject-with-note, the home waiting card, background invalidation, the permission menu without bypass, fork, drawer search and primary actions at the largest text size. It attaches light, dark and accessibility screenshots. Tests override connection defaults for their process and never submit login credentials. Stub and local cryptographic tests do not replace a real Host test. No job uses the user's daily Harness installation or deployment credentials.

## Verification record

On 2026-11-03, local validation used Xcode 27.2 against the uncommitted conversation redesign based on `c66f94d95eaacb9ca64850a51ff1f55c2fe61565`. This identifies the base commit, not a committed snapshot of the tested changes. The simulator destination was iPhone 18 Pro / iOS 27.2 with `arm64` and `ONLY_ACTIVE_ARCH=YES`. These results do not establish execution on the CI-configured Xcode 26.2 runtime.

| Check | Result and scope | Local evidence |
|---|---|---|
| Task-console redesign | On 2026-11-03, `check_ios.sh` exited successfully against commit `9874ecf` on the same Xcode 27.2 / iPhone 18 Pro / iOS 27.2 destination: 43 core tests and all 15 UI tests passed, with no failures or skipped tests. Home, task detail, dark approval and dark pairing screenshots were visually inspected. iPad layout, VoiceOver order and physical devices were not checked for this revision. | `build/task-console-validation.log`, `build/Tests-1793686209.xcresult`, `build/screenshots/` |
| Core and simulator UI | `check_ios.sh` exited successfully: 30 core tests and all eight UI tests passed, with no failures or skipped tests. This establishes the redesign baseline before the final large-text layout corrections. | `build/redesign-validation.log`, `build/Tests-1793677716.xcresult`, seven screenshot attachments indexed by `build/redesign-ui-attachments/manifest.json` |
| Corrected largest-text layout | After correcting truncated entry text and an oversized send glyph found in screenshot review, both the largest-text and send/stop/continuation tests passed in 48.092 seconds. New screenshots were visually checked for complete entry labels and a bounded send glyph. | `build/redesign-accessibility-validation.log`, `build/RedesignAccessibility-1793678863.xcresult`, `build/redesign-accessibility-attachments/` |
| Signed physical-device build and launch | The delivery Debug build, including the layout and login-error corrections, succeeded; `app.dsh.ios` was installed and launched on iPhone 14 Pro / iOS 26.6.1. The entry screenshot from the preceding layout-corrected build was visually inspected; the final login-error correction changes no UI. Preservation of an existing session after account-login failure was source-reviewed and compiled, not tested against a live service. | `build/delivery-device-build.log`, `build/dsh-iphone-final.png` |
| Physical-device UI automation | The runner failed to initialize before executing tests: “Timed out while enabling automation mode.” No physical tap, send or stop test passed. | `build/redesign-device-smoke.log`, `build/RedesignDeviceSmoke.xcresult` |
| Local unsigned Release archive | `xcodebuild archive` succeeded before the final layout corrections and subsequent login-error review. AppIntents metadata extraction was skipped because the app has no AppIntents dependency. This was a local archive, not GitHub workflow execution, signed IPA export or upload. | `build/redesign-archive.log`, `build/RedesignRehearsal.xcarchive`, `build/RedesignArchive.xcresult` |

Project-reference consistency, version validation, shell syntax and property-list checks also passed. Earlier validation found an x86_64 simulator-linking failure; the current script selects the native architecture and passed the complete run above. An earlier signed version also launched on iPhone 14 Pro / iOS 26.6.1 after system trust was established and the device unlocked. No signing identity or device identifier is recorded here or in the shared project. Evidence under `build/` is local and ignored by Git; a fresh clone does not include these logs, result bundles, screenshots or archives.

The passing simulator run has an automation caveat: XCTest repeatedly waited about 60 seconds for missing “App animations complete” notifications during navigation. The history/new-conversation/demo-exit draft test took 689.835 seconds and the full UI suite took 887.466 seconds. These are test-run durations affected by automation waits, not measured application animation latency; the cause of the missing notifications remains unresolved.

The [interactive HTML review](../design/product-review.html) was checked separately in a browser: suggestion visibility and its draft-preservation guard, textarea identity/focus/selection and Chinese draft retention through streaming completion and Stop, and one-time approval consumption passed. Synthetic `compositionstart`/`compositionend` events disabled and re-enabled Send. A 375-pixel viewport had no horizontal overflow, and the iPad HTML layout was visually inspected. These checks establish browser behavior only; synthetic composition events do not validate a person's real Chinese input method. Static theme-color calculations met contrast ratios of at least 4.5:1 for checked body/secondary/action text pairs and 3:1 for send glyphs, without establishing full native contrast acceptance.

Physical-device Keychain and connection recovery, physical interaction beyond launch, native small-iPhone and iPad layouts, real keyboard/IME behavior, full Dynamic Type layout, VoiceOver and Reduce Motion remain unverified. Use the [product acceptance criteria](product-design.md) for those checks. Browser layout, synthetic events, static contrast calculations and passing UI assertions do not establish complete native usability or accessibility acceptance.

The protocol source baseline is ds-harness-remote `c374397dea2bea0e5a81adc993553be992102bc6` / plugin `0.6.2`. No Harness/plugin/Server combination has been run for this application. [Application architecture](architecture.md) owns implemented behavior and the remaining encrypted session integration.

## Release rehearsal and publication

[Release rehearsal](../.github/workflows/release-rehearsal.yml) is manual and requires dispatch from `ios-v<marketing-version>`. [check_release.py](../scripts/check_release.py) validates both build configurations and the selected tag. The workflow repeats documentation/core validation, creates an unsigned device archive, and retains the ZIP, SHA-256 checksum, source revision and diagnostics for fourteen days. It does not export an installable signed IPA or upload to TestFlight, and it cannot check whether a build number is unused in App Store Connect.

TestFlight remains unconfigured. It requires an Apple Developer team, final bundle identifier, signing certificates/profiles or an approved signing service, App Store Connect authentication, and a protected release environment. Future upload must repeat required validation at the selected version tag and use the matching signed artifact. No deployment credentials, Apple account changes, uploads, GitHub Pages deployment or App Store submission are part of this implementation.

The upstream [documentation and release research](research/documentation-and-ci.md) explains the split. Keep remote interoperability validation separate: record versions and exercise real session streams, approval lifecycle, transfers, stop and reconnect before a release claims support.
