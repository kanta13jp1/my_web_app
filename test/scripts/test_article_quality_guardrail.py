#!/usr/bin/env python3
"""Offline unit tests for scripts/article_quality_guardrail.py (#2648)."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from article_quality_guardrail import evaluate_article, main  # noqa: E402


def _rich_body(seed_phrase: str, repeat: int = 16) -> str:
    return (
        "# " + seed_phrase + "\n\n"
        "## 背景と課題\n\n"
        + (f"{seed_phrase}における設計上の観点と定量的評価基準を整理しています。" * repeat)
        + "\n\n## 実装と検証結果\n\n"
        + (f"{seed_phrase}のパイプライン統合テストと監査ログの再現性を確認しました。" * repeat)
        + "\n"
    )


class ArticleQualityGuardrailTest(unittest.TestCase):
    def test_rejects_short_hollow_and_placeholder_drafts(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            corpus = root / "docs" / "blog-drafts"
            corpus.mkdir(parents=True)
            short_draft = corpus / "short.md"
            short_draft.write_text(
                "# 短すぎる記事\n\n## 概要\n\n## まとめ\n\nTODO: 後で追記する。\n",
                encoding="utf-8",
            )
            res = evaluate_article(short_draft, corpus_roots=[corpus], min_chars=600)
            self.assertFalse(res.passed)
            self.assertTrue(any(f.startswith("insufficient_length:") for f in res.failures))
            self.assertTrue(any(f.startswith("placeholder_detected:") for f in res.failures))

    def test_rejects_missing_title_and_missing_h2_structure(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            corpus = root / "docs" / "blog-drafts"
            corpus.mkdir(parents=True)
            no_headings = corpus / "no-headings.md"
            no_headings.write_text(
                "見出しが存在しない単なる長文本文テキストです。" * 30,
                encoding="utf-8",
            )
            res = evaluate_article(no_headings, corpus_roots=[corpus], min_chars=300)
            self.assertFalse(res.passed)
            self.assertTrue(any(f.startswith("missing_title_or_h1:") for f in res.failures))
            self.assertTrue(any(f.startswith("missing_h2_sections:") for f in res.failures))

    def test_detects_near_duplicate_and_excludes_self_path(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            corpus = root / "docs" / "blog-drafts"
            zenn = root / "docs" / "blog" / "zenn"
            corpus.mkdir(parents=True)
            zenn.mkdir(parents=True)

            existing = zenn / "cicd-guard.md"
            existing.write_text(
                "---\n"
                "title: Automated CI Quality Gate for Supabase Pipelines\n"
                "---\n\n"
                "## Architecture\n\n"
                + ("Deterministic validation checks block insecure migrations and stale tokens across deployment workflows. " * 12)
                + "\n\n## Observability\n\n"
                + ("Structured audit logs preserve exact commit SHAs and error traces for every gate rejection. " * 12)
                + "\n",
                encoding="utf-8",
            )

            # Self evaluation must exclude self-path and pass
            self_res = evaluate_article(existing, corpus_roots=[corpus, zenn], min_chars=600)
            self.assertTrue(self_res.passed, self_res.failures)

            # Near-duplicate in another file must fail with top match
            near_dup = corpus / "dup-cicd-guard.md"
            near_dup.write_text(
                "# Automated CI Quality Gate for Supabase Release Workflows\n\n"
                "## Architecture\n\n"
                + ("Deterministic validation checks block insecure migrations and stale tokens across deployment workflows. " * 12)
                + "\n\n## Observability\n\n"
                + ("Structured audit logs preserve exact commit SHAs and error traces for every gate rejection. " * 12)
                + "\n",
                encoding="utf-8",
            )
            dup_res = evaluate_article(near_dup, corpus_roots=[corpus, zenn], min_chars=600)
            self.assertFalse(dup_res.passed)
            self.assertTrue(any("topic_overlap" in f for f in dup_res.failures))
            self.assertEqual(dup_res.top_matches[0]["path"], existing.as_posix())

            # Distinct Japanese article must pass cleanly
            distinct = corpus / "flutter-contrast.md"
            distinct.write_text(
                _rich_body("モバイル環境における高コントラストUI配色とタイポグラフィ検証"),
                encoding="utf-8",
            )
            distinct_res = evaluate_article(distinct, corpus_roots=[corpus, zenn], min_chars=600)
            self.assertTrue(distinct_res.passed, distinct_res.failures)

    def test_fail_closed_cli_writes_json_markdown_logs_and_traceability(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            subprocess.run(["git", "init"], cwd=root, check=True, stdout=subprocess.DEVNULL)
            subprocess.run(["git", "config", "user.email", "ci@example.com"], cwd=root, check=True)
            subprocess.run(["git", "config", "user.name", "CI"], cwd=root, check=True)
            draft = root / "draft.md"
            draft.write_text("# Stub\n\nComing soon.\n", encoding="utf-8")
            subprocess.run(["git", "add", "draft.md"], cwd=root, check=True)
            subprocess.run(["git", "commit", "-m", "add stub draft"], cwd=root, check=True, stdout=subprocess.DEVNULL)

            json_out = root / "out" / "guardrail.json"
            md_out = root / "out" / "guardrail.md"
            gh_out = root / "out" / "gh_output.txt"
            code = main(
                [
                    "--files",
                    str(draft),
                    "--corpus-root",
                    str(root),
                    "--json-out",
                    str(json_out),
                    "--markdown-out",
                    str(md_out),
                    "--github-output",
                    str(gh_out),
                ]
            )
            self.assertEqual(code, 1)
            payload = json.loads(json_out.read_text(encoding="utf-8"))
            self.assertEqual(payload["status"], "fail")
            self.assertEqual(payload["failed_count"], 1)
            trace = payload["articles"][0]["traceability"]
            self.assertTrue(len(trace["commit_sha"]) >= 7)
            self.assertIn("FAIL", md_out.read_text(encoding="utf-8"))
            self.assertIn("guardrail_status=fail", gh_out.read_text(encoding="utf-8"))

    def test_empty_target_scope_gracefully_passes_and_self_test_passes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            json_out = root / "skip.json"
            self.assertEqual(main(["--json-out", str(json_out)]), 0)
            data = json.loads(json_out.read_text(encoding="utf-8"))
            self.assertEqual(data["status"], "skipped")
        self.assertEqual(main(["--self-test"]), 0)


if __name__ == "__main__":
    unittest.main()
