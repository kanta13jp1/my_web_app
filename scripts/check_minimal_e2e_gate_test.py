#!/usr/bin/env python3
from __future__ import annotations

import unittest

from check_minimal_e2e_gate import validate


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


if __name__ == "__main__":
    unittest.main()
