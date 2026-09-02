#!/usr/bin/env python3
from __future__ import annotations

import unittest

from check_minimal_e2e_gate import (
    EXCEPTION_REASON_MIN_LENGTH,
    has_visible_exception_reason,
    passing_snippet,
    validate,
)


GOOD_BODY = """
## Minimal E2E Gate
- Implementation-detail independent black-box I/O test.
- Minimal 3 cases: happy path, error path, recovery path.
- E2E: Flutter Integration Test in integration_test/.
"""


class MinimalE2EGateTest(unittest.TestCase):
    def test_passes_when_app_change_has_e2e_file_and_contract(self) -> None:
        ok, messages, app_change = validate(
            GOOD_BODY,
            ["lib/pages/foo.dart", "integration_test/foo_flow_test.dart"],
            set(),
        )

        self.assertTrue(ok, messages)
        self.assertTrue(app_change)

    def test_fails_when_app_change_has_no_e2e_file_or_exception(self) -> None:
        ok, messages, app_change = validate(
            GOOD_BODY,
            ["lib/pages/foo.dart", "test/foo_test.dart"],
            set(),
        )

        self.assertFalse(ok)
        self.assertTrue(app_change)
        self.assertTrue(any("Application-code PRs" in item for item in messages))

    def test_allows_visible_exception_for_non_ui_tooling_change(self) -> None:
        body = GOOD_BODY + "\nE2E-Exception: workflow-only gate change.\n"
        ok, messages, app_change = validate(
            body,
            [".github/workflows/minimal-e2e-gate.yml", "scripts/check_minimal_e2e_gate.py"],
            set(),
        )

        self.assertTrue(ok, messages)
        self.assertFalse(app_change)

    def test_non_app_change_does_not_require_e2e_declaration(self) -> None:
        ok, messages, app_change = validate(
            "",
            [".github/dependabot.yml", ".github/workflows/ci.yml"],
            set(),
        )

        self.assertTrue(ok, messages)
        self.assertFalse(app_change)
        self.assertEqual(
            messages,
            ["Skipped because no application runtime code changed."],
        )

    def test_requires_minimal_black_box_language(self) -> None:
        ok, messages, _ = validate(
            "Tests added.",
            ["lib/pages/foo.dart", "integration_test/foo_flow_test.dart"],
            set(),
        )

        self.assertFalse(ok)
        self.assertGreaterEqual(len(messages), 3)

    def test_empty_exception_placeholder_does_not_bypass_e2e_file(self) -> None:
        body = GOOD_BODY + "\n- [ ] E2E-Exception: <!-- reason -->\n"
        ok, messages, app_change = validate(
            body,
            ["lib/pages/foo.dart"],
            set(),
        )

        self.assertFalse(ok)
        self.assertTrue(app_change)
        self.assertTrue(any("Application-code PRs" in item for item in messages))

    def test_docs_only_label_skips_gate(self) -> None:
        ok, messages, app_change = validate(
            "",
            ["lib/pages/foo.dart"],
            {"docs-only"},
        )

        self.assertTrue(ok, messages)
        self.assertFalse(app_change)


class PassingSnippetTest(unittest.TestCase):
    """The canonical paste-able snippet must always satisfy validate().

    These round-trip tests are the guard against drift: if anyone edits the
    snippet wording or the pattern tables in a way that breaks the contract,
    CI fails here instead of in a developer's PR.
    """

    def test_snippet_passes_for_non_app_change(self) -> None:
        ok, messages, app_change = validate(
            passing_snippet(),
            ["docs/MINIMAL_E2E_ISSUE_GATE.md", "scripts/check_minimal_e2e_gate.py"],
            set(),
        )

        self.assertTrue(ok, messages)
        self.assertFalse(app_change)

    def test_snippet_with_exception_passes_for_app_change_without_e2e_file(self) -> None:
        body = passing_snippet("docs and scripts only; no app runtime code changed")
        ok, messages, app_change = validate(
            body,
            ["lib/pages/foo.dart"],
            set(),
        )

        self.assertTrue(ok, messages)
        self.assertTrue(app_change)
        self.assertTrue(has_visible_exception_reason(body))

    def test_snippet_without_exception_fails_for_app_change_without_e2e_file(self) -> None:
        # Proves the exception line is what carries an E2E-less app PR: the body
        # commitments alone are present, but the missing E2E file is still caught.
        ok, messages, app_change = validate(
            passing_snippet(),
            ["lib/pages/foo.dart"],
            set(),
        )

        self.assertFalse(ok)
        self.assertTrue(app_change)
        self.assertTrue(any("Application-code PRs" in item for item in messages))

    def test_emit_snippet_cli_prints_passing_block(self) -> None:
        import contextlib
        import io

        from check_minimal_e2e_gate import main

        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            exit_code = main(["--emit-snippet"])

        self.assertEqual(exit_code, 0)
        ok, _, _ = validate(buffer.getvalue(), ["docs/x.md"], set())
        self.assertTrue(ok)

    def test_min_length_constant_is_consistent(self) -> None:
        short = "x" * (EXCEPTION_REASON_MIN_LENGTH - 1)
        long = "x" * EXCEPTION_REASON_MIN_LENGTH
        self.assertFalse(has_visible_exception_reason(f"E2E-Exception: {short}"))
        self.assertTrue(has_visible_exception_reason(f"E2E-Exception: {long}"))


if __name__ == "__main__":
    unittest.main()
