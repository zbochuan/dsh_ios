# Documentation instructions

- Keep each fact in its owning document; use the placement rules in [README.md](README.md).
- Maintain English `name.md`, Chinese `name.zh.md`, and `name.i18n.yaml` together. Either language may be authored first. Read [i18n/README.md](i18n/README.md) and [i18n/terminology.md](i18n/terminology.md).
- Preserve heading hierarchy, list and table structure, code fences, and corresponding link targets across each pair. Use one physical line per prose paragraph.
- Review meaning before running `python3 -I scripts/check_docs.py --record <english-path...>`; a hash does not prove translation quality.
- Run `python3 -I scripts/check_docs.py` across the complete corpus. Instruction files and the bilingual terminology table are intentionally unpaired.
- Research cites fixed revisions and states verification limits. Current references describe actual behavior; substantial decisions record rationale and verification under `docs/decisions/`.
