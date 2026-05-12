#!/usr/bin/env python3
from __future__ import annotations

import unittest

from low_risk_pr_digest import classify_issue, classify_pr


class LowRiskPrDigestTest(unittest.TestCase):
    def test_docs_only_pr_is_candidate(self) -> None:
        result = classify_pr(
            {
                "number": 1,
                "title": "docs: update runbook",
                "labels": [{"name": "documentation"}],
                "files": [{"path": "docs/automation/example.md", "additions": 12, "deletions": 2}],
            }
        )

        self.assertTrue(result["candidate"])
        self.assertEqual(result["risk"], "low")

    def test_migration_path_blocks_candidate(self) -> None:
        result = classify_pr(
            {
                "number": 2,
                "title": "fix migration",
                "labels": [{"name": "automation"}],
                "files": [{"path": "supabase/migrations/20260501000000_change.sql"}],
            }
        )

        self.assertFalse(result["candidate"])
        self.assertTrue(any("High-risk path" in reason for reason in result["stop_reasons"]))

    def test_workflow_with_secrets_keyword_blocks_candidate(self) -> None:
        result = classify_pr(
            {
                "number": 3,
                "title": "ci: adjust secret deploy",
                "labels": [{"name": "automation"}],
                "files": [{"path": ".github/workflows/deploy-prod.yml"}],
            }
        )

        self.assertFalse(result["candidate"])
        self.assertGreaterEqual(len(result["stop_reasons"]), 2)

    def test_large_file_count_blocks_candidate(self) -> None:
        result = classify_pr(
            {
                "number": 4,
                "title": "docs: bulk update",
                "labels": [{"name": "documentation"}],
                "files": [{"path": f"docs/bulk/{idx}.md"} for idx in range(13)],
            }
        )

        self.assertFalse(result["candidate"])
        self.assertTrue(any("Changed file count" in reason for reason in result["stop_reasons"]))

    def test_low_risk_issue_requires_low_risk_label(self) -> None:
        result = classify_issue(
            {
                "number": 5,
                "title": "Document a workflow",
                "labels": [{"name": "documentation"}],
            }
        )

        self.assertTrue(result["candidate"])

    def test_secret_issue_is_not_candidate(self) -> None:
        result = classify_issue(
            {
                "number": 6,
                "title": "Rotate production secret",
                "labels": [{"name": "documentation"}],
            }
        )

        self.assertFalse(result["candidate"])


if __name__ == "__main__":
    unittest.main()
