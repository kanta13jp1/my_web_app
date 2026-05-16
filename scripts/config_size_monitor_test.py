#!/usr/bin/env python3
"""Unit tests for config_size_monitor.py."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import config_size_monitor as monitor


def write(path: Path, body: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body, encoding="utf-8")


class ConfigSizeMonitorTest(unittest.TestCase):
    def test_counts_lines_and_passes_at_limit(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write(root / "CLAUDE.md", "a\nb\n")
            write(root / ".claude/inject-rules.txt", "rule\n")
            write(root / "docs/PHILOSOPHY.md", "# Philosophy\n")

            report = monitor.evaluate(
                root=root,
                claude_path=root / "CLAUDE.md",
                inject_rules_path=root / ".claude/inject-rules.txt",
                claude_limit=2,
                inject_rules_limit=1,
                required_pointers=(),
            )

            self.assertFalse(report["has_warnings"])
            self.assertEqual(report["size_checks"][0]["lines"], 2)
            self.assertEqual(report["size_checks"][0]["status"], "ok")

    def test_warns_when_claude_md_exceeds_limit(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write(root / "CLAUDE.md", "a\nb\nc\n")
            write(root / ".claude/inject-rules.txt", "rule\n")

            report = monitor.evaluate(
                root=root,
                claude_path=root / "CLAUDE.md",
                inject_rules_path=root / ".claude/inject-rules.txt",
                claude_limit=2,
                inject_rules_limit=10,
                required_pointers=(),
            )

            self.assertTrue(report["has_warnings"])
            self.assertEqual(report["size_checks"][0]["status"], "over_limit")

    def test_warns_for_missing_required_pointer(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write(root / "CLAUDE.md", "[Other](docs/OTHER.md)\n")
            write(root / ".claude/inject-rules.txt", "")
            write(root / "docs/OTHER.md", "# Other\n")

            report = monitor.evaluate(
                root=root,
                claude_path=root / "CLAUDE.md",
                inject_rules_path=root / ".claude/inject-rules.txt",
                claude_limit=100,
                inject_rules_limit=100,
                required_pointers=("docs/PHILOSOPHY.md",),
            )

            self.assertTrue(report["has_warnings"])
            self.assertEqual(report["missing_required_pointers"], ["docs/PHILOSOPHY.md"])

    def test_warns_for_dangling_doc_pointer(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write(root / "CLAUDE.md", "[Missing](docs/MISSING.md)\n")
            write(root / ".claude/inject-rules.txt", "")

            report = monitor.evaluate(
                root=root,
                claude_path=root / "CLAUDE.md",
                inject_rules_path=root / ".claude/inject-rules.txt",
                claude_limit=100,
                inject_rules_limit=100,
                required_pointers=(),
            )

            self.assertTrue(report["has_warnings"])
            self.assertEqual(report["dangling_pointers"], ["docs/MISSING.md"])


if __name__ == "__main__":
    unittest.main()
