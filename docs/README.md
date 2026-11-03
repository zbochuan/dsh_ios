# Documentation

English | [中文](README.zh.md)

## Product and research

The product is a redesigned iOS client for a computer running Harness with ds-harness-remote. The computer owns agent execution and project files. The SwiftUI application provides a conversation-focused local demonstration, plus Server login and discovery; Relay integration and Host interoperability remain pending. [Application architecture](architecture.md) owns current behavior and verification boundaries.

- [Mobile product design](product-design.md) owns the current conversation-focused direction, official Claude/ChatGPT reference evidence, and interaction acceptance criteria.
- [Remote client research](research/ds-harness-remote-ios.md) owns the proposed client responsibilities, protocol mapping, and compatibility evidence; its early interface proposals are historical context.
- [Web and Desktop research](research/deepseek-harness-web-desktop.md) records the official runtime and client implementation at the cited revision.
- [Documentation and CI/CD research](research/documentation-and-ci.md) records the upstream engineering conventions and their adaptation to this repository.

## Engineering references

- [Application architecture](architecture.md) owns implemented behavior, source responsibilities, and integration boundaries.
- [Development and CI/CD](development.md) owns local validation, current build workflows, and release requirements.
- [Bilingual documentation](i18n/README.md) owns pairing, synchronization, and review rules.
- [Terminology](i18n/terminology.md) defines shared English and Chinese terms.

## Placement

Use `docs/research/` for revision-scoped evidence and proposals. Use `docs/decisions/` for substantial decisions once made, with context, tradeoffs, and required verification. Keep the architecture reference current with application changes; link to the owning reference instead of turning research into a second implementation manual. Each human-facing document has an English page, a Chinese page, and a sibling synchronization record.
