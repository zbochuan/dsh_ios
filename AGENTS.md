# Repository instructions

- Build a redesigned iOS client for a computer running DeepSeek Harness with ds-harness-remote; keep agent execution and model credentials on the computer. Start with [docs/README.md](docs/README.md).
- Keep source-based research distinct from verified application behavior. SwiftUI and Relay-first transport remain proposals until implemented.
- Follow [docs/AGENTS.md](docs/AGENTS.md) for documentation edits and run `python3 -I scripts/check_docs.py` after changing docs or their checker.
- Add iOS build and release checks with the actual project; [docs/development.md](docs/development.md) owns the CI/CD integration requirements.
- Preserve upstream license notices when copying code. Never commit credentials, signing files, or generated build products.
