# DSH iOS

English | [中文](README.zh.md)

An independently designed iOS client for [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness), connecting to a computer through [ds-harness-remote](https://github.com/liguobao/ds-harness-remote).

The computer runs the agent, model requests, project files, and tools. The Swift 6 / SwiftUI interface targets iPhone and iPad on iOS 17 and later. The client centers on a conversation, its history and one composer, with local demonstrations of replies, task activity and approvals. Remote Server login and computer discovery are implemented separately; remote conversations remain unavailable.

## Project state

The repository now includes an Xcode application, shared scheme, testable Swift core, UI tests, and documentation/build/release-rehearsal workflows. Open `DSH.xcodeproj` and select the `DSH` scheme. [Application architecture](docs/architecture.md) records implemented behavior and remaining integration work; [development](docs/development.md) records validation and commands. Noise encryption has an isolated implementation; Control/Relay and actual Harness sessions are not connected yet. No real Host interoperability is claimed.

## Documentation

- [Documentation index](docs/README.md): product direction, research, and engineering references.
- [Mobile product design](docs/product-design.md): Claude and ChatGPT official screenshot references, interaction decisions, and native acceptance criteria.
- [Remote client research](docs/research/ds-harness-remote-ios.md): deployment, protocol, iOS interaction proposals, and compatibility limits.
- [Web and Desktop research](docs/research/deepseek-harness-web-desktop.md): upstream runtime, persistence, and client architecture.
- [Development and CI/CD](docs/development.md): local checks, active CI, and the planned iOS release sequence.
- [Bilingual documentation contract](docs/i18n/README.md): paired files, terminology, and synchronization records.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md). Run the same documentation check used by CI from the repository root:

```bash
python3 -I scripts/check_docs.py
```

## Upstream projects

This is an independent project and does not claim affiliation with DeepSeek or the Remote project. Research cites fixed upstream revisions. Upstream fixture and protocol adaptation notices are preserved in [third-party notices](THIRD_PARTY_NOTICES.txt); the repository has not yet selected a license for its own application code.
