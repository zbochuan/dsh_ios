# Documentation

English | [中文](README.zh.md)

## Product and research

The product is a redesigned iOS client for a computer running Harness with ds-harness-remote. The computer owns agent execution and project files. SwiftUI and a Relay-first implementation are proposals, pending implementation and interoperability checks.

- [Remote client research](research/ds-harness-remote-ios.md) owns the proposed client responsibilities, protocol mapping, interface direction, and compatibility evidence.
- [Web and Desktop research](research/deepseek-harness-web-desktop.md) records the official runtime and client implementation at the cited revision.
- [Documentation and CI/CD research](research/documentation-and-ci.md) records the upstream engineering conventions and their adaptation to this repository.

## Engineering references

- [Development and CI/CD](development.md) owns local validation, current CI, and requirements for adding iOS builds and releases.
- [Bilingual documentation](i18n/README.md) owns pairing, synchronization, and review rules.
- [Terminology](i18n/terminology.md) defines shared English and Chinese terms.

## Placement

Use `docs/research/` for revision-scoped evidence and proposals. Use `docs/decisions/` for substantial decisions once made, with context, tradeoffs, and required verification. Add an architecture reference with the application implementation; link to the owning reference instead of turning research into a second implementation manual. Each human-facing document has an English page, a Chinese page, and a sibling synchronization record.
