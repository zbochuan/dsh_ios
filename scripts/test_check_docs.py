#!/usr/bin/env python3
"""Exercise documentation checks against temporary valid and invalid corpora."""

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("check_docs", Path(__file__).with_name("check_docs.py"))
CHECKER = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = CHECKER
SPEC.loader.exec_module(CHECKER)

ENGLISH = "# Example\n\nEnglish | [中文](example.zh.md)\n\nA paragraph.\n\n## Usage\n\n- One\n- Two\n\n```bash\ncommand\n```\n"
CHINESE = "# 示例\n\n[English](example.md) | 中文\n\n一个段落。\n\n## 使用\n\n- 一\n- 二\n\n```bash\ncommand\n```\n"


class DocumentationChecks(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.english = self.root / "example.md"
        self.chinese = self.root / "example.zh.md"
        self.english.write_text(ENGLISH, encoding="utf-8")
        self.chinese.write_text(CHINESE, encoding="utf-8")
        self.assertEqual(CHECKER.check(self.root, ["example.md"]), [])

    def change(self, path, old, new):
        path.write_text(path.read_text(encoding="utf-8").replace(old, new), encoding="utf-8")

    def assert_failure(self, expected, record=None):
        errors = CHECKER.check(self.root, record)
        self.assertTrue(any(expected in error for error in errors), errors)

    def test_valid_pair(self):
        self.assertEqual(CHECKER.check(self.root), [])

    def test_changed_prose_requires_review_record(self):
        self.change(self.english, "A paragraph.", "A revised paragraph.")
        self.assert_failure("stale synchronization record")
        self.assertEqual(CHECKER.check(self.root, ["example.md"]), [])
        self.assertEqual(CHECKER.check(self.root), [])

    def test_missing_translation(self):
        self.chinese.unlink()
        self.assert_failure("missing Chinese counterpart")

    def test_orphan_translation(self):
        self.english.unlink()
        self.assert_failure("orphan or excluded translation")

    def test_missing_switcher(self):
        self.change(self.chinese, "[English](example.md) | 中文", "中文")
        self.assert_failure("missing language switcher")

    def test_code_mismatch_cannot_be_recorded(self):
        record = self.root / "example.i18n.yaml"
        original = record.read_bytes()
        self.change(self.chinese, "\ncommand\n", "\nother-command\n")
        self.assert_failure("structure differs", ["example.md"])
        self.assertEqual(record.read_bytes(), original)

    def test_list_structure(self):
        self.change(self.chinese, "- 二\n", "")
        self.assert_failure("structure differs")

    def test_heading_structure(self):
        self.change(self.chinese, "## 使用", "### 使用")
        self.assert_failure("structure differs")

    def test_table_dimensions(self):
        with self.english.open("a", encoding="utf-8") as file:
            file.write("\n| A | B |\n|---|---|\n")
        with self.chinese.open("a", encoding="utf-8") as file:
            file.write("\n| 甲 |\n|---|\n")
        self.assert_failure("structure differs")

    def test_broken_local_link(self):
        self.change(self.english, "A paragraph.", "[Missing](missing.md)")
        self.assert_failure("missing local target")

    def test_links_with_code_labels_are_checked(self):
        self.change(self.english, "A paragraph.", "[`Missing`](missing.md)")
        self.assert_failure("missing local target")

    def test_wrong_language_link(self):
        self.change(self.english, "A paragraph.", "[Self](example.md)")
        self.change(self.chinese, "一个段落。", "[自身](example.md)")
        self.assert_failure("wrong-language document link")

    def test_different_external_targets(self):
        self.change(self.english, "A paragraph.", "[Source](https://example.com/one)")
        self.change(self.chinese, "一个段落。", "[来源](https://example.com/two)")
        self.assert_failure("bilingual link targets differ")

    def test_trailing_whitespace(self):
        self.change(self.english, "A paragraph.\n", "A paragraph. \n")
        self.assert_failure("trailing whitespace")

    def test_final_newline(self):
        self.english.write_text(ENGLISH.rstrip(), encoding="utf-8")
        self.assert_failure("exactly one final newline")

    def test_wrapped_paragraph(self):
        self.change(self.english, "A paragraph.", "A paragraph\ncontinued here.")
        self.assert_failure("one physical line")

    def test_unclosed_fence(self):
        self.change(self.english, "command\n```\n", "command\n")
        self.assert_failure("unclosed code fence")

    def test_reference_links_rejected(self):
        self.change(self.english, "A paragraph.", "[Source][ref]")
        self.assert_failure("use inline Markdown links")

    def test_record_requires_english_path(self):
        self.assert_failure("English document path", ["example.zh.md"])

    def test_inline_examples_are_not_links(self):
        self.change(self.english, "A paragraph.", "A paragraph with `[example](missing.md)`.")
        self.assertEqual(CHECKER.check(self.root, ["example.md"]), [])


    def test_unsupported_inline_links_cannot_silently_pass(self):
        for link in ["[x](missing.md 'Title')", "[x](missing.md (Title))",
                     "[the [spec] page](missing.md)"]:
            with self.subTest(link=link):
                self.english.write_text(ENGLISH.replace("A paragraph.", link), encoding="utf-8")
                self.assert_failure("unsupported link syntax", ["example.md"])

    def test_localized_cross_document_fragments(self):
        self.change(self.english, "A paragraph.", "[Usage](example.md#usage)")
        self.change(self.chinese, "一个段落。", "[用法](example.zh.md#使用)")
        self.assertEqual(CHECKER.check(self.root, ["example.md"]), [])

    def test_docs_build_directory_is_checked(self):
        directory = self.root / "docs/build"
        directory.mkdir(parents=True)
        (directory / "guide.md").write_text("No heading\n", encoding="utf-8")
        self.assert_failure("missing Chinese counterpart")

    def test_local_tool_directories_are_excluded(self):
        for name in [".claude/worktrees/scratch", ".venv/lib/site-packages"]:
            directory = self.root / name
            directory.mkdir(parents=True)
            (directory / "readme.md").write_text("Not project docs\n", encoding="utf-8")
        self.assertEqual(CHECKER.check(self.root), [])

    def test_gitignored_files_are_excluded(self):
        CHECKER.subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        (self.root / ".gitignore").write_text("scratch/\n", encoding="utf-8")
        directory = self.root / "scratch"
        directory.mkdir()
        (directory / "readme.md").write_text("Not project docs\n", encoding="utf-8")
        self.assertEqual(CHECKER.check(self.root), [])

    def test_directory_links_require_localized_readme(self):
        directory = self.root / "docs"
        directory.mkdir()
        (directory / "README.md").write_text(
            "# Docs\n\nEnglish | [中文](README.zh.md)\n", encoding="utf-8")
        (directory / "README.zh.md").write_text(
            "# 文档\n\n[English](README.md) | 中文\n", encoding="utf-8")
        self.assertEqual(CHECKER.check(self.root, ["docs/README.md"]), [])
        self.change(self.english, "A paragraph.", "[Docs](docs/)")
        self.change(self.chinese, "一个段落。", "[文档](docs/)")
        self.assert_failure("localized README")

    def test_switcher_requires_h1_first(self):
        self.change(self.english, "# Example\n\n", "Intro.\n\n")
        with self.english.open("a", encoding="utf-8") as file:
            file.write("\n# Example\n")
        self.assert_failure("H1 title on the first line")

    def test_crlf_is_rejected(self):
        self.english.write_bytes(ENGLISH.replace("\n", "\r\n").encode())
        self.assert_failure("LF line endings")

    def test_array_prose_is_not_a_reference_link(self):
        self.change(self.english, "A paragraph.", "Inspect a[0][1] here.")
        self.assertEqual(CHECKER.check(self.root, ["example.md"]), [])

    def test_double_backtick_literals(self):
        self.change(self.english, "A paragraph.", "Example: ``[x](`y`.md)``.")
        self.assertEqual(CHECKER.check(self.root, ["example.md"]), [])

    def test_orphan_record(self):
        (self.root / "orphan.i18n.yaml").write_text("/orphan:\n", encoding="utf-8")
        self.assert_failure("orphan or excluded synchronization record")

    def test_instruction_files_are_unpaired_but_link_checked(self):
        instructions = self.root / "AGENTS.md"
        instructions.write_text("# Instructions\n\nRead [the page](example.md).\n", encoding="utf-8")
        self.assertEqual(CHECKER.check(self.root), [])
        self.change(instructions, "example.md", "missing.md")
        self.assert_failure("missing local target")


if __name__ == "__main__":
    unittest.main()
