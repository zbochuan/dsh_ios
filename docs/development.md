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

The [bilingual contract](i18n/README.md) defines what the checker verifies and what review still owns. No Xcode project, application build command, or release automation exists yet.

## Active CI

[Documentation CI](../.github/workflows/docs.yml) runs on pull requests, pushes to `main`, and manual dispatch. It checks the complete Markdown corpus with Python 3.13 on Ubuntu. Read-only repository permissions, disabled persisted checkout credentials, and per-ref cancellation keep this validation independent from publishing.

The same script runs locally and in CI. A documentation-only change does not allocate a macOS runner. Passing this workflow proves documentation consistency under the documented checks; it says nothing about an iOS build or Host interoperability. Making the check required for merges is a repository setting and has not been configured here.

## iOS CI integration plan

Add the following with the actual iOS project so each command can be exercised against a real target. These are integration requirements, not active workflows.

| Stage | Trigger and runner | Required evidence |
|---|---|---|
| Documentation | Pull requests and `main`; Ubuntu | Complete bilingual, structure, hash, and local file-link checks. |
| Simulator build and tests | Application changes on pull requests and `main`; hosted macOS | Explicit Xcode version, committed shared scheme, named simulator/runtime, unsigned build, and relevant unit/UI tests. |
| Remote interoperability | Protocol changes or manual dispatch; isolated test Host | Recorded Harness/plugin/Server versions; Noise vectors, session stream, approval lifecycle, transfers, and reconnect behavior. |
| Release rehearsal | A selected release revision; hosted macOS | Verified version/build number, archive/export rehearsal once signing exists, checksums, source revision, and retained diagnostics. |
| TestFlight upload | Manual dispatch from a version tag; protected release environment | Required validation repeated at the selected revision, matching signed artifact, App Store Connect upload, and traceable run. |

Simulator tests should cover meaningful behavior: message state under stream completion, expired approvals, unknown mutation results after disconnection, and navigation/accessibility paths. Stub-based protocol tests do not replace a real Host test. Keep external credentials out of pull request jobs, and never depend on the user's daily Harness installation for automated tests.

Add `Package.resolved` when Swift package dependencies appear, pin the Xcode toolchain in CI, and use the same checked-in commands locally and in workflows. Preserve `.xcresult` bundles when diagnosing test failures. Document the selected scheme, deployment target, simulator, and Host compatibility versions when they are verified.

## Release requirements

Use a separate manual release workflow after an application target exists. A version tag such as `ios-v0.1.0` must match the app's marketing version; its build number must be valid and unused in App Store Connect. Build and validate the exact selected revision. Retain the artifact identity and source revision so a retry uploads the intended build rather than silently rebuilding another revision.

TestFlight requires an Apple Developer team, a bundle identifier, signing certificates/profiles or an approved signing service, App Store Connect authentication, and a configured protected release environment. These have not been supplied or configured. No deployment credentials, Apple account changes, uploads, GitHub Pages deployment, or App Store submission are part of the current repository setup.

The upstream [documentation and release research](research/documentation-and-ci.md) explains the conventions behind this split. Simulator validation can be added as soon as the iOS project exists; signed publication follows when its concrete configuration is available.
