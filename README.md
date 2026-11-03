# DSH iOS

English | [中文](README.zh.md)

An independently designed iOS client for [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness), connecting to a computer through [ds-harness-remote](https://github.com/liguobao/ds-harness-remote).

The computer runs the agent, model requests, project files, and tools. The iOS client provides conversations, task activity, approvals, and file viewing. The interface is being designed for iPhone and iPad; SwiftUI is the proposed implementation framework.

## Project state

This repository contains source-based research, bilingual documentation, and documentation CI. It does not yet contain an iOS application or a verified connection to a Remote Host. Relay with Noise encryption is the proposed first transport; WebRTC follows after interoperability is verified.

## Documentation

- [Documentation index](docs/README.md): product direction, research, and engineering references.
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

This is an independent project and does not claim affiliation with DeepSeek or the Remote project. Research cites fixed upstream revisions. Any future source reuse must preserve the applicable upstream license notices; the repository has not yet selected a license for its own application code.
