#!/usr/bin/env python3
from __future__ import annotations

import contextlib
import io
import unittest

from check_high_risk_ultrareview_gate import (
    EXCEPTION_REASON_MIN_LENGTH,
    REQUIRED_PERSPECTIVES,
    main,
    missing_perspectives,
    passing_evidence_block,
    passing_exception_block,
    validate,
)


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


class PassingBlockTest(unittest.TestCase):
    """The emit-able blocks must always satisfy validate() on a high-risk PR.

    These round-trip tests guard against drift between the generated wording and
    the pattern tables: break either and CI fails here, not in a developer's PR.
    """

    HIGH_RISK_FILES = [".github/workflows/deploy-prod.yml"]

    def test_exception_block_passes_high_risk_pr(self) -> None:
        body = passing_exception_block(
            "prose-only trigger; no high-risk path touched, review after merge"
        )
        ok, messages, high_risk, _ = validate(body, self.HIGH_RISK_FILES, set())

        self.assertTrue(ok, messages)
        self.assertTrue(high_risk)

    def test_exception_block_with_short_reason_is_not_visible(self) -> None:
        # A reason below the threshold must not silently pass the gate.
        short = "x" * (EXCEPTION_REASON_MIN_LENGTH - 1)
        ok, _, high_risk, _ = validate(
            passing_exception_block(short), self.HIGH_RISK_FILES, set()
        )

        self.assertFalse(ok)
        self.assertTrue(high_risk)

    def test_evidence_block_passes_high_risk_pr(self) -> None:
        ok, messages, high_risk, _ = validate(
            passing_evidence_block(), self.HIGH_RISK_FILES, set()
        )

        self.assertTrue(ok, messages)
        self.assertTrue(high_risk)

    def test_evidence_block_covers_every_required_perspective(self) -> None:
        # Derived from REQUIRED_PERSPECTIVES, so it can never miss one.
        self.assertEqual(missing_perspectives(passing_evidence_block()), [])
        for name in REQUIRED_PERSPECTIVES:
            self.assertIn(name.split()[0], passing_evidence_block().lower())

    def test_emit_exception_cli_prints_passing_block(self) -> None:
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            exit_code = main(["--emit-exception", "prose trigger only; no high-risk path"])

        self.assertEqual(exit_code, 0)
        ok, messages, _, _ = validate(buffer.getvalue(), self.HIGH_RISK_FILES, set())
        self.assertTrue(ok, messages)

    def test_emit_evidence_cli_prints_passing_block(self) -> None:
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            exit_code = main(["--emit-evidence"])

        self.assertEqual(exit_code, 0)
        ok, messages, _, _ = validate(buffer.getvalue(), self.HIGH_RISK_FILES, set())
        self.assertTrue(ok, messages)


if __name__ == "__main__":
    unittest.main()
