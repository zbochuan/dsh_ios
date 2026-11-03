#!/usr/bin/env python3
"""Check the repository's Markdown subset and reviewed bilingual records."""

import argparse
import hashlib
import re
import subprocess
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
IGNORED_ROOTS = {".git", ".claude", ".venv", ".build", "build", "DerivedData", "node_modules", "__pycache__"}
UNPAIRED = {"docs/i18n/terminology.md"}
HEADING = re.compile(r"^(#{1,6})\s+(.+?)(?:\s+#+)?\s*$")
FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")
INLINE_CODE = re.compile(r"(`+)(?!`)(.+?)(?<!`)\1(?!`)")
LINK = re.compile(r"!?\[[^\]\n]*\]\((<[^>\n]+>|[^\s)]+)(?:\s+\"[^\"]*\")?\)")
LIST = re.compile(r"^(\s*)([-+*]|\d+[.)])\s+")


@dataclass
class Page:
    path: Path
    text: str
    headings: list[tuple[int, str]]
    sections: list[str]
    signature: list[tuple]
    links: list[tuple[int, str]]


def excluded(path: Path, root: Path) -> bool:
    return path.name in {"AGENTS.md", "CLAUDE.md"} or path.relative_to(root).as_posix() in UNPAIRED


def discover(root: Path, suffix: str) -> list[Path]:
    if (root / ".git").exists():
        result = subprocess.run(["git", "-C", str(root), "ls-files", "-co", "--exclude-standard", "-z"],
                                check=True, stdout=subprocess.PIPE)
        candidates = {root / name for name in result.stdout.decode("utf-8").split("\0") if name}
    else:
        candidates = set(root.rglob(f"*{suffix}"))
    return sorted(path for path in candidates if path.name.endswith(suffix) and path.is_file()
                  and path.relative_to(root).parts[0] not in IGNORED_ROOTS)


def switcher(path: Path) -> str:
    if path.name.endswith(".zh.md"):
        return f"[English]({path.name.removesuffix('.zh.md')}.md) | 中文"
    return f"English | [中文]({path.stem}.zh.md)"


def parse_page(path: Path, root: Path) -> tuple[Page, list[str]]:
    text = path.read_bytes().decode("utf-8")
    label = path.relative_to(root).as_posix()
    errors = []
    if "\r" in text:
        errors.append(f"{label}: use LF line endings")
    if not text.endswith("\n") or text.endswith("\n\n"):
        errors.append(f"{label}: use exactly one final newline")
    headings, sections, signature, links = [], [], [], []
    section: list[str] = []
    active_fence = None
    code: list[str] = []
    previous_prose = False
    expected_switcher = switcher(path)
    lines = text.splitlines()
    for number, line in enumerate(lines, 1):
        if line.rstrip() != line:
            errors.append(f"{label}:{number}: trailing whitespace")
        if line == expected_switcher:
            previous_prose = False
            continue
        marker = FENCE.match(line)
        if active_fence:
            section.append(line)
            if (marker and marker[1][0] == active_fence[0][0]
                    and len(marker[1]) >= len(active_fence[0]) and not marker[2].strip()):
                signature.append(("code", active_fence[1], "\n".join(code)))
                active_fence = None
                code = []
            else:
                code.append(line)
            previous_prose = False
            continue
        if marker:
            active_fence = (marker[1], marker[2].strip())
            section.append(line)
            previous_prose = False
            continue
        heading = HEADING.match(line)
        if heading:
            if section:
                sections.append("\n".join(section).strip())
            section = [line]
            headings.append((len(heading[1]), heading[2]))
            signature.append(("heading", len(heading[1])))
            previous_prose = False
        else:
            section.append(line)
            item = LIST.match(line)
            table = line.strip().startswith("|") and line.strip().endswith("|")
            if item:
                signature.append(("list", len(item[1].expandtabs(4)), item[2]))
            elif table:
                # Ignore pipes inside inline code and escaped literal pipes.
                cells = INLINE_CODE.sub("CODE", line.strip())
                signature.append(("table", len(re.split(r"(?<!\\)\|", cells)) - 2))
            prose = bool(line.strip()) and not item and not table and not line.startswith((">", "<!--"))
            if prose and previous_prose:
                errors.append(f"{label}:{number}: keep one physical line per prose paragraph")
            previous_prose = prose
        # Code spans are literal examples, not links or syntax to validate.
        visible = INLINE_CODE.sub("CODE", line)
        if re.search(r"^\s*\[[^]]+\]:|(?<![A-Za-z0-9_])\[[^]]+\]\[[^]]*\]|<a\s", visible, re.IGNORECASE):
            errors.append(f"{label}:{number}: use inline Markdown links")
        unmatched = LINK.sub("", visible)
        if "](" in unmatched or re.search(r"!?\[[^\n]*\[[^\n]*\]\]\(", visible):
            errors.append(f"{label}:{number}: unsupported link syntax; use simple inline links")
        links.extend((number, match[1].strip("<>")) for match in LINK.finditer(visible))
    if section:
        sections.append("\n".join(section).strip())
    if active_fence:
        errors.append(f"{label}: unclosed code fence")
    first_heading = HEADING.match(lines[0]) if lines else None
    if not first_heading or len(first_heading[1]) != 1 or sum(depth == 1 for depth, _ in headings) != 1:
        errors.append(f"{label}: use one H1 title on the first line")
    if not excluded(path, root) and (len(lines) < 3 or lines[1] != "" or lines[2] != expected_switcher):
        errors.append(f"{label}: missing language switcher immediately after H1")
    return Page(path, text, headings, sections, signature, links), errors


def resolve_link(page: Page, target: str, root: Path) -> tuple[str, Path | None, str]:
    parsed = urlsplit(target)
    if parsed.scheme or parsed.netloc:
        return target, None, ""
    resolved = (page.path.parent / unquote(parsed.path)).resolve() if parsed.path else page.path
    try:
        relative = resolved.relative_to(root.resolve()).as_posix()
    except ValueError:
        return target, resolved, "target is outside the repository"
    canonical = relative.removesuffix(".zh.md") + ".md" if relative.endswith(".zh.md") else relative
    if parsed.query:
        canonical += "?" + parsed.query
    # Localized heading slugs are review-owned, including cross-document links.
    return canonical, resolved, ""


def check_links(page: Page, root: Path, paired: set[Path]) -> tuple[list[str], list[str]]:
    errors, targets = [], []
    for number, target in page.links:
        canonical, resolved, error = resolve_link(page, target, root)
        if error:
            errors.append(f"{page.path.relative_to(root)}:{number}: {error}: {target}")
        elif resolved is not None:
            if not resolved.exists():
                errors.append(f"{page.path.relative_to(root)}:{number}: missing local target: {target}")
            if resolved.is_dir() and (resolved / "README.md") in paired:
                errors.append(f"{page.path.relative_to(root)}:{number}: link explicitly to the localized README: {target}")
            if not urlsplit(target).path:
                # Translated heading slugs are review-owned; do not compare them.
                targets.append("<local-fragment>")
                continue
            source = (resolved.with_name(resolved.name.removesuffix(".zh.md") + ".md")
                      if resolved.name.endswith(".zh.md") else resolved)
            if source in paired and page.path in paired | {p.with_suffix('.zh.md') for p in paired}:
                expected = source.with_suffix(".zh.md") if page.path.name.endswith(".zh.md") else source
                if resolved != expected:
                    errors.append(f"{page.path.relative_to(root)}:{number}: wrong-language document link: {target}")
        targets.append(canonical)
    return targets, errors


def section_keys(page: Page) -> list[str]:
    keys, stack, seen = [], [], Counter()
    if len(page.sections) > len(page.headings):
        keys.append("/")
    for depth, title in page.headings:
        slug = re.sub(r"[^\w\s-]", "", title.lower())
        slug = re.sub(r"\s+", "-", slug).strip("-") or "section"
        while stack and stack[-1][0] >= depth:
            stack.pop()
        stack.append((depth, slug))
        key = "/" + "/".join(part for _, part in stack)
        seen[key] += 1
        keys.append(key if seen[key] == 1 else f"{key}~{seen[key]}")
    return keys


def render_record(english: Page, chinese: Page) -> str:
    lines = ["# Reviewed bilingual contents; see docs/i18n/README.md.",
             "# Refresh only after reviewing both languages: --record <english-path>"]
    for key, en, zh in zip(section_keys(english), english.sections, chinese.sections, strict=True):
        lines.extend([f"{key}:", f"  en: {hashlib.sha256(en.encode()).hexdigest()[:16]}",
                      f"  zh: {hashlib.sha256(zh.encode()).hexdigest()[:16]}"])
    return "\n".join(lines) + "\n"


def check(root: Path, record: list[str] | None = None) -> list[str]:
    root = root.resolve()
    paths = discover(root, ".md")
    sources = {p for p in paths if not p.name.endswith(".zh.md") and not excluded(p, root)}
    requested = {(root / name).resolve() for name in record or []}
    errors = [f"{path}: --record requires an English document path" for path in requested - sources]
    pages, target_lists = {}, {}
    for path in paths:
        page, issues = parse_page(path, root)
        pages[path] = page
        errors.extend(issues)
        targets, issues = check_links(page, root, sources)
        target_lists[path] = targets
        errors.extend(issues)
    for path in paths:
        if path.name.endswith(".zh.md"):
            source = path.with_name(path.name.removesuffix(".zh.md") + ".md")
            if source not in sources:
                errors.append(f"{path.relative_to(root)}: orphan or excluded translation")
    for path in discover(root, ".i18n.yaml"):
        source = path.with_name(path.name.removesuffix(".i18n.yaml") + ".md")
        if source not in sources:
            errors.append(f"{path.relative_to(root)}: orphan or excluded synchronization record")
    records = {}
    for source in sorted(sources):
        chinese = source.with_suffix(".zh.md")
        meta = source.with_suffix(".i18n.yaml")
        label = source.relative_to(root)
        if chinese not in pages:
            errors.append(f"{label}: missing Chinese counterpart")
            continue
        en, zh = pages[source], pages[chinese]
        if en.signature != zh.signature:
            errors.append(f"{label}: bilingual heading/list/table/code structure differs")
            continue
        if target_lists[source] != target_lists[chinese]:
            errors.append(f"{label}: bilingual link targets differ")
            continue
        if len(en.sections) != len(zh.sections):
            errors.append(f"{label}: bilingual section counts differ")
            continue
        expected = render_record(en, zh)
        if source in requested:
            records[meta] = expected
        elif not meta.exists() or meta.read_text(encoding="utf-8") != expected:
            errors.append(f"{label}: missing or stale synchronization record; review both languages before --record")
    # Never partially refresh records when structure or another check fails.
    if not errors:
        for meta, content in records.items():
            meta.write_text(content, encoding="utf-8")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--record", nargs="+", metavar="ENGLISH_PATH", help="record explicitly reviewed pairs")
    args = parser.parse_args()
    try:
        errors = check(ROOT, args.record)
    except (OSError, UnicodeError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Documentation check failed: {error}", file=sys.stderr)
        return 1
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    count = sum(not p.name.endswith(".zh.md") and not excluded(p, ROOT) for p in discover(ROOT, ".md"))
    print(f"Documentation check passed: {count} bilingual pairs; local links, structure, records, and Markdown hygiene.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
