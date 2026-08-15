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
    strip_collapsed_sections,
    text_risk_reasons,
    validate,
)

# Trimmed from the real body of #4257 ("deps: update google-genai requirement"),
# a one-line version bump that the gate used to flag high-risk. All keyword hits
# live inside the <details> blocks dependabot pastes upstream release notes into.
DEPENDABOT_BODY = """\
Updates the requirements on [google-genai](https://github.com/googleapis/python-genai) to permit the latest version.
<details>
<summary>Release notes</summary>
<blockquote>
<li>Support mTLS in custom client using google auth mtls.get_default_ssl_context</li>
<li>Populate per-modality prompt token count in embedding responses</li>
</blockquote>
</details>
"""


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


class CollapsedSectionTextRiskTest(unittest.TestCase):
    """#4257 regression: quoted upstream notes must not make a PR high-risk."""

    def test_dependabot_release_notes_do_not_trigger_text_risk(self) -> None:
        self.assertEqual(
            text_risk_reasons(
                "deps: update google-genai requirement from <3.0.0,>=2.12.0",
                DEPENDABOT_BODY,
            ),
            [],
        )

    def test_keywords_written_by_the_author_still_trigger(self) -> None:
        self.assertTrue(
            text_risk_reasons("fix: rotate key", "This changes the auth flow.")
        )

    def test_title_keywords_still_trigger(self) -> None:
        self.assertTrue(text_risk_reasons("fix(billing): stripe webhook", "see below"))

    def test_author_text_outside_details_still_counts(self) -> None:
        # A risky sentence next to quoted notes must not be masked by the strip.
        body = "We rotate the service role token here.\n" + DEPENDABOT_BODY
        self.assertTrue(text_risk_reasons("deps: bump x", body))

    def test_unclosed_details_drops_the_remainder(self) -> None:
        # Truncated bodies keep the quoted tail out of the scan.
        self.assertEqual(
            strip_collapsed_sections("visible part\n<details>\n<p>auth token</p>"),
            "visible part\n",
        )

    def test_body_without_details_is_unchanged(self) -> None:
        self.assertEqual(strip_collapsed_sections("plain body"), "plain body")

    def test_multiple_details_blocks_are_all_removed(self) -> None:
        body = "<details>auth</details>middle<details>token</details>"
        self.assertNotIn("auth", strip_collapsed_sections(body))
        self.assertNotIn("token", strip_collapsed_sections(body))
        self.assertIn("middle", strip_collapsed_sections(body))

    def test_details_with_attributes_is_removed(self) -> None:
        self.assertEqual(
            text_risk_reasons("deps: bump x", '<details open id="n">auth</details>'),
            [],
        )


if __name__ == "__main__":
    unittest.main()
