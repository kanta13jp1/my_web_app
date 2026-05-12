from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "scripts" / "validate_blog_draft.py"


def make_draft(title: str = "Quality Gate Test", body_seed: str = "automation") -> str:
    body = " ".join([body_seed] * 950)
    return f"""---
title: "{title}"
tags: Flutter,Supabase,buildinpublic
published: false
---

# {title}

## Problem

{body}

## Solution

{body}
"""


class ValidateBlogDraftTest(unittest.TestCase):
    def run_gate(self, args: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(SCRIPT), *args],
            cwd=cwd,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )

    def test_passes_structured_traceable_draft(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            tmp = Path(raw_tmp)
            draft = tmp / "docs" / "blog-drafts" / "2026-05-05-quality.md"
            draft.parent.mkdir(parents=True)
            draft.write_text(make_draft(), encoding="utf-8")
            report = tmp / "tmp" / "quality.json"

            result = self.run_gate(
                [
                    "--draft",
                    str(draft),
                    "--trace-id",
                    "blog-publish-test",
                    "--source-ref",
                    "abc1234",
                    "--report",
                    str(report),
                    "--corpus-root",
                    str(tmp / "docs" / "blog-drafts"),
                ],
                cwd=tmp,
            )

            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn('"status": "pass"', report.read_text(encoding="utf-8"))

    def test_rejects_duplicate_title(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            tmp = Path(raw_tmp)
            corpus = tmp / "docs" / "blog-drafts"
            corpus.mkdir(parents=True)
            draft = corpus / "2026-05-05-quality.md"
            duplicate = corpus / "2026-04-30-quality.md"
            draft.write_text(make_draft("Same Title", "alpha"), encoding="utf-8")
            duplicate.write_text(make_draft("Same Title", "beta"), encoding="utf-8")

            result = self.run_gate(
                [
                    "--draft",
                    str(draft),
                    "--trace-id",
                    "blog-publish-test",
                    "--source-ref",
                    "abc1234",
                    "--report",
                    str(tmp / "tmp" / "quality.json"),
                    "--corpus-root",
                    str(corpus),
                ],
                cwd=tmp,
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("duplicate_topic", result.stdout)

    def test_rejects_missing_traceability(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            tmp = Path(raw_tmp)
            draft = tmp / "draft.md"
            draft.write_text(make_draft(), encoding="utf-8")

            result = self.run_gate(
                [
                    "--draft",
                    str(draft),
                    "--report",
                    str(tmp / "quality.json"),
                    "--corpus-root",
                    str(tmp / "empty"),
                ],
                cwd=tmp,
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("missing_trace_id", result.stdout)
            self.assertIn("missing_source_ref", result.stdout)


if __name__ == "__main__":
    unittest.main()
