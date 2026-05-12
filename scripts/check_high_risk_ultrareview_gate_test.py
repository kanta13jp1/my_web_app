#!/usr/bin/env python3
from __future__ import annotations

import unittest

from check_high_risk_ultrareview_gate import validate


GOOD_BODY = """
## High-risk Ultrareview Gate
- Reviewer: Claude Code #1
- Evidence: Claude ultrareview completed for this PR.
- Perspectives covered: security, rollback, data migration, prod smoke, observability.
- Unresolved findings: none.
"""


class HighRiskUltrareviewGateTest(unittest.TestCase):
    def test_low_risk_docs_change_passes_without_declaration(self) -> None:
        ok, messages, high_risk, reasons = validate(
            "",
            ["docs/automation/example.md"],
            set(),
        )

        self.assertTrue(ok, messages)
        self.assertFalse(high_risk)
        self.assertEqual(reasons, [])

    def test_migration_change_requires_ultrareview_evidence(self) -> None:
        ok, messages, high_risk, reasons = validate(
            "Routine schema update.",
            ["supabase/migrations/20260508090000_add_table.sql"],
            set(),
        )

        self.assertFalse(ok)
        self.assertTrue(high_risk)
        self.assertTrue(any("High-risk path" in item for item in reasons))
        self.assertTrue(any("ultrareview evidence" in item for item in messages))

    def test_complete_ultrareview_evidence_passes(self) -> None:
        ok, messages, high_risk, _ = validate(
            GOOD_BODY,
            [".github/workflows/deploy-prod.yml"],
            {"security"},
        )

        self.assertTrue(ok, messages)
        self.assertTrue(high_risk)

    def test_missing_review_perspectives_fail(self) -> None:
        body = """
        ## High-risk Ultrareview Gate
        - Reviewer: Claude Code #1
        - Evidence: Claude ultrareview completed.
        - Unresolved findings: 0
        """
        ok, messages, high_risk, _ = validate(
            body,
            ["supabase/functions/foo/index.ts"],
            set(),
        )

        self.assertFalse(ok)
        self.assertTrue(high_risk)
        self.assertTrue(any("security" in item and "observability" in item for item in messages))

    def test_visible_exception_passes_when_review_owner_is_named(self) -> None:
        body = """
        ## High-risk Ultrareview Gate
        - Reviewer: Claude Code #1
        - High-Risk-Ultrareview-Exception: workflow-only bootstrap; Claude Code #1 review will be requested after merge.
        """
        ok, messages, high_risk, _ = validate(
            body,
            [".github/workflows/claude-agent-review.yml"],
            set(),
        )

        self.assertTrue(ok, messages)
        self.assertTrue(high_risk)

    def test_exception_without_visible_reason_does_not_pass(self) -> None:
        body = """
        ## High-risk Ultrareview Gate
        - Reviewer: Claude Code #1
        - High-Risk-Ultrareview-Exception: <!-- reason -->
        """
        ok, messages, high_risk, _ = validate(
            body,
            [".github/workflows/claude-agent-review.yml"],
            set(),
        )

        self.assertFalse(ok)
        self.assertTrue(high_risk)
        self.assertTrue(any("exception reason" in item for item in messages))


if __name__ == "__main__":
    unittest.main()
