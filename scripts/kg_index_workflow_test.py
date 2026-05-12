#!/usr/bin/env python3
"""Regression tests for kg-indexer-nightly workflow resilience."""

from __future__ import annotations

import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = REPO_ROOT / ".github" / "workflows" / "kg-indexer-nightly.yml"


class KgIndexerWorkflowTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.text = WORKFLOW.read_text(encoding="utf-8")

    def test_run_indexers_has_github_token(self) -> None:
        self.assertIn("GH_TOKEN: ${{ github.token }}", self.text)

    def test_indexers_run_fail_soft(self) -> None:
        for marker in [
            "failures=()",
            "run_indexer()",
            "artifact_count=",
            "No kg-indexer artifacts were produced",
            "uploaded partial artifacts before opening the failure issue",
        ]:
            self.assertIn(marker, self.text)

    def test_all_expected_indexers_are_invoked(self) -> None:
        for script in [
            "scripts/kg_index_github_issues.py",
            "scripts/kg_index_wbs_tasks.py",
            "scripts/kg_index_docs.py",
            "scripts/kg_index_memory_vault.py",
            "scripts/kg_index_notebooklm_intake.py",
        ]:
            self.assertIn(script, self.text)

    def test_failure_issue_step_is_preserved(self) -> None:
        self.assertIn("Open or update failure issue", self.text)
        self.assertIn("if: failure()", self.text)
        self.assertIn("[Schedule監視] kg-indexer-nightly failure", self.text)


if __name__ == "__main__":
    unittest.main()
