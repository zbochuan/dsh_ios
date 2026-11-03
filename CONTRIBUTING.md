# Contributing

English | [中文](CONTRIBUTING.zh.md)

The product direction is an iOS client with a redesigned interface, connected to a computer running Harness and ds-harness-remote. Use the [documentation index](docs/README.md) before changing that boundary.

## Documentation changes

Keep each fact in one owning document and link to it elsewhere. Research records evidence at a fixed upstream revision; current behavior belongs in an architecture or development reference. Record substantial decisions with their rationale and verification requirements under `docs/decisions/` when those decisions are made.

Update both languages in the same change, following the [bilingual contract](docs/i18n/README.md) and [terminology](docs/i18n/terminology.md). Use one physical line per prose paragraph and relative links for repository files. Keep code examples identical in both languages.

After reviewing the pair for equivalent meaning, record only the pairs you changed:

```bash
python3 -I scripts/check_docs.py --record README.md docs/development.md
```

Run the complete check before handing off the change:

```bash
python3 -I scripts/check_docs.py
```

The check validates completeness, structure, synchronization records, local links, and basic Markdown hygiene. It cannot validate translation meaning or confirm remote protocol compatibility.

## Application changes

Run the commands in [development and CI/CD](docs/development.md) for the checked-in Xcode application and Swift package. [Application architecture](docs/architecture.md) owns implementation boundaries. Keep connection state and protocol handling independent from SwiftUI views, and verify protocol changes against upstream fixtures and a documented Host version.

Use [mobile product design](docs/product-design.md) for interface decisions and official reference evidence. Preserve per-conversation drafts, contextual approvals and the compact local-demo boundary. Add controls only for supported actions. Describe native source changes, simulator checks, device runtime and visual/accessibility review separately; screenshots and passing compilation alone cannot establish interaction quality.

## Review and publication

Explain the resulting behavior, relevant checks, and any unverified boundaries. Keep credentials, signing files, and generated build products out of Git. Pull request checks must run without deployment credentials; a signed release uses a separate workflow and protected environment after the application and signing setup exist.
