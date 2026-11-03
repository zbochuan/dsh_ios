# Bilingual documentation

English | [中文](README.zh.md)

## Pairing contract

English and Simplified Chinese carry equal authority. Either may be written first; review ensures that both express the same facts and verification limits. Every human-facing Markdown page is a sibling triplet: `name.md`, `name.zh.md`, and `name.i18n.yaml`. Language directories and interleaved translations are not used.

Immediately after the H1, the English page links to Chinese and the Chinese page links back to English. Internal links to paired pages use the reader's language. Heading depths and order, list structure, table dimensions, and link targets correspond; fenced code blocks are byte-identical, including their language labels.

Instruction files named `AGENTS.md` or `CLAUDE.md` and the bilingual [terminology table](terminology.md) are excluded from pairing. Other Markdown pages are discovered automatically, including future research and decision records. A translation or record without its English sibling is an error.

## Edit and verify

Read the terminology table, update both pages, and review their meaning. Record only the pairs whose translations you have checked:

```bash
python3 -I scripts/check_docs.py --record README.md docs/development.md
```

Run the complete corpus check:

```bash
python3 -I scripts/check_docs.py
```

The checker uses only Python's standard library. Each record has one English-heading-path entry per section, containing the first 16 hexadecimal characters of each side's SHA-256 hash. Our small implementation hashes the complete section, including code blocks, but excludes the language switcher. This is a local format inspired by upstream, not a drop-in replacement for its verifier. Recording validates structure first and never translates text.

CI rejects missing pairs, stale records, mismatched structures, broken local file links, wrong-language internal links, malformed fences, trailing whitespace, non-LF line endings, and missing final newlines. The supported Markdown subset uses ATX headings, simple inline links, fenced code, lists, and pipe tables. Links may have plain labels and optional double-quoted titles; unsupported link forms, reference-style links, and raw HTML links are rejected. Link explicitly to a localized README rather than its directory. Local fragments are neither validated nor compared across languages; remote URLs are compared exactly but not fetched.

Discovery includes tracked and non-ignored untracked files through Git, with build output and local tool directories excluded at the repository root. Documentation paths such as `docs/build/` remain in scope. Temporary checker tests without a Git repository use filesystem discovery with the same root exclusions.

## Review responsibility

Hashes prove that these exact contents were recorded together; they do not prove equivalent meaning. Review owns technical accuracy, natural language, terminology, and the distinction between proposals and verified behavior. Never refresh records just to silence CI. Resolve both texts before recording a merge conflict.

Update the translation minimally when a section changes. Add a term to the shared table when it needs a stable translation. Code identifiers, protocol methods, paths, version strings, and exact commands remain unchanged.
