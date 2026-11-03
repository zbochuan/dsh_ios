# Upstream documentation and CI/CD conventions

English | [中文](documentation-and-ci.zh.md)

Research date: 2026-11-03. Sources are pinned to DeepSeek Harness revision [`ce7073d51254c26cd63b22a60835b8f948deb447`](https://github.com/deepseek-ai/deepseek-harness/tree/ce7073d51254c26cd63b22a60835b8f948deb447). This is a static review of documentation and workflow definitions; upstream builds and publication were not executed.

## Documentation ownership

The upstream [documentation standard](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/docs/AGENTS.md) gives each fact one home: root instructions hold short standing rules, architecture maps the runtime, subsystem references own contracts, package READMEs own package behavior, tutorials own procedures, and Agent Notes own decisions and rationale. Current references describe current behavior; historical evidence belongs in scoped records. Prose uses one physical line per paragraph and relative links within the repository.

This repository adopts the ownership principle with a smaller tree. Research lives under `docs/research/`; engineering rules live in development and bilingual references; substantial decisions will live under `docs/decisions/`. We do not create empty subsystem or package documentation before an application exists. Research remains revision-scoped evidence rather than proof of a working iOS client.

## English and Chinese pairing

The upstream [bilingual contract](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/docs/i18n/README.md) makes both languages equally authoritative. A pair is three sibling files: `name.md`, `name.zh.md`, and `name.i18n.yaml`. Language switchers, corresponding structure and link destinations, exact code blocks, and per-section recorded hashes are mechanically checked. Review still owns semantic accuracy.

Our [local contract](../i18n/README.md) adopts the triplet, equal authority, terminology, same-change updates, and explicit confirmation records. The small standard-library Python checker uses its own record format: complete section hashes rather than upstream's prose-block-only hashes. It is independently implemented for the documented Markdown subset and does not import upstream's TypeScript tooling or claim identical coverage.

## CI validation

Upstream [pull request CI](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/.github/workflows/ci.yml) separates static analysis, coverage, lint, and build consumers. It uses locked dependency installs, read-only default permissions, disabled persisted checkout credentials, and cancellation of superseded runs. The [development guide](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/docs/development.md) connects local commands with the exhaustive CI checks; documentation synchronization is a required engineering check.

We adopt shared local/CI commands and independent validation jobs. Documentation runs on Ubuntu without Node dependencies. Simulator builds belong on macOS once an Xcode project and shared scheme exist; protocol interoperability requires an isolated Host with recorded versions. The upstream enterprise runners and Node monorepo build graph do not apply to this repository.

## Build and publication

Upstream [release rehearsal](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/.github/workflows/release.yml) builds and verifies npm packages without publication credentials on pull requests and the main development branch. A separate [manual publish workflow](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/.github/workflows/release-publish.yml) verifies the selected version and packages before publishing; it also exposes an explicit tag-check bypass, so tag-only publication is not an unconditional rule across upstream workflows.

Upstream [macOS packaging](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/.github/workflows/macos-package.yml) is manually selected by source ref and test/production preset, then validates configuration, signs installers, and retains artifacts and diagnostics. The separate [documentation deployment](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/.github/workflows/docs-pages.yml) is manual from a verified release tag and uses the GitHub Pages environment; normal pull request CI still builds the site.

For iOS we adopt build validation before publication, traceable artifacts, a separate manual release workflow, and a protected signing environment. Electron installers, npm publication, and the upstream website deployment are not copied. The proposed TestFlight sequence and its missing prerequisites are owned by [development and CI/CD](../development.md); no signed workflow is active yet.
