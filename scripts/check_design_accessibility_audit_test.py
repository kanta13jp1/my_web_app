#!/usr/bin/env python3
from __future__ import annotations

import contextlib
import io
import tempfile
import unittest
from pathlib import Path

from check_design_accessibility_audit import (
    ChangedPath,
    main,
    parse_changed_paths,
    passing_snippet,
    validate,
)


GOOD_BODY = """
## Design Accessibility Audit

- Scope: routes=/checkout; components=CheckoutErrorPanel; states=error,recovery; viewports=desktop,mobile
- Surface-Type: checkout-form — the changed surface submits payment details and displays decline errors.
- Design-Plugin-Status: pass
- Design-Plugin-Reviewed-At: 2026-08-25
- Design-Plugin-Evidence: https://github.com/kanta13jp1/my_web_app/pull/999#issuecomment-123
- WCAG-2.1-AA-Findings: result=pass; unresolved-high=0; one low-risk implementation check is recorded.
- Remediation: resolved=3; added visible focus, persistent field help, and a recovery action.
- Deterministic-Evidence: tests=widget semantics pass; keyboard-contrast=pass; AT=not-run — release owner will run NVDA before merge.
- Error-Microcopy-Review: reviewed — changed the decline error to explain that no charge occurred and how to retry.
"""


class DesignAccessibilityAuditGateTest(unittest.TestCase):
    def test_non_ui_change_is_not_applicable(self) -> None:
        ok, messages, required, new_component, microcopy_required, paths = validate(
            "", [ChangedPath("M", "docs/DESIGN.md")]
        )

        self.assertTrue(ok, messages)
        self.assertFalse(required)
        self.assertFalse(new_component)
        self.assertFalse(microcopy_required)
        self.assertEqual(paths, [])

    def test_modified_view_requires_complete_audit(self) -> None:
        ok, messages, required, new_component, microcopy_required, paths = validate(
            "", [ChangedPath("M", "lib/ui/features/home/views/home_page.dart")]
        )

        self.assertFalse(ok)
        self.assertTrue(required)
        self.assertFalse(new_component)
        self.assertFalse(microcopy_required)
        self.assertEqual(paths, ["lib/ui/features/home/views/home_page.dart"])
        self.assertTrue(any("Missing" in message for message in messages))

    def test_new_checkout_component_requires_reviewed_microcopy(self) -> None:
        ok, messages, required, new_component, microcopy_required, _ = validate(
            GOOD_BODY,
            [ChangedPath("A", "lib/ui/features/checkout/views/checkout_error_page.dart")],
        )

        self.assertTrue(ok, messages)
        self.assertTrue(required)
        self.assertTrue(new_component)
        self.assertTrue(microcopy_required)

    def test_checkout_component_rejects_not_applicable_microcopy(self) -> None:
        body = GOOD_BODY.replace(
            "reviewed — changed the decline error to explain that no charge occurred and how to retry.",
            "not-applicable — this checkout screen has no error state in the supplied design.",
        )
        ok, messages, *_ = validate(
            body,
            [ChangedPath("A", "lib/ui/features/checkout/views/checkout_page.dart")],
        )

        self.assertFalse(ok)
        self.assertTrue(any("Checkout/form-related" in message for message in messages))

    def test_regular_ui_accepts_specific_not_applicable_reason(self) -> None:
        body = (
            GOOD_BODY.replace(
                "Surface-Type: checkout-form — the changed surface submits payment details and displays decline errors.",
                "Surface-Type: other — the changed surface is a read-only status badge.",
            )
            .replace("routes=/checkout", "routes=/status")
            .replace(
                "reviewed — changed the decline error to explain that no charge occurred and how to retry.",
                "not-applicable — the read-only status badge has no input, checkout, or error state.",
            )
        )
        ok, messages, required, new_component, microcopy_required, _ = validate(
            body, [ChangedPath("A", "lib/widgets/status_badge.dart")]
        )

        self.assertTrue(ok, messages)
        self.assertTrue(required)
        self.assertTrue(new_component)
        self.assertFalse(microcopy_required)

    def test_performance_named_view_does_not_false_trigger_form_review(self) -> None:
        body = (
            GOOD_BODY.replace(
                "Surface-Type: checkout-form — the changed surface submits payment details and displays decline errors.",
                "Surface-Type: other — the changed surface is a read-only performance chart.",
            )
            .replace("routes=/checkout", "routes=/performance")
            .replace(
                "reviewed — changed the decline error to explain that no charge occurred and how to retry.",
                "not-applicable — the read-only performance chart has no input or error state.",
            )
        )
        ok, messages, required, _, microcopy_required, _ = validate(
            body, [ChangedPath("M", "lib/pages/performance_dashboard.dart")]
        )

        self.assertTrue(ok, messages)
        self.assertTrue(required)
        self.assertFalse(microcopy_required)

    def test_sign_in_view_requires_microcopy_review(self) -> None:
        ok, messages, _, _, microcopy_required, _ = validate(
            GOOD_BODY, [ChangedPath("M", "lib/pages/sign_in_page.dart")]
        )

        self.assertTrue(ok, messages)
        self.assertTrue(microcopy_required)

    def test_placeholder_evidence_is_rejected(self) -> None:
        body = GOOD_BODY.replace(
            "https://github.com/kanta13jp1/my_web_app/pull/999#issuecomment-123",
            "<link later>",
        )
        ok, messages, *_ = validate(
            body, [ChangedPath("M", "lib/ui/features/home/views/home_page.dart")]
        )

        self.assertFalse(ok)
        self.assertTrue(any("Design-Plugin-Evidence" in message for message in messages))

    def test_non_pass_status_is_rejected(self) -> None:
        body = GOOD_BODY.replace(
            "Design-Plugin-Status: pass", "Design-Plugin-Status: pending"
        )
        ok, messages, *_ = validate(
            body, [ChangedPath("M", "lib/ui/features/home/views/home_page.dart")]
        )

        self.assertFalse(ok)
        self.assertTrue(any("exactly `pass`" in message for message in messages))

    def test_deletion_only_ui_change_still_requires_audit(self) -> None:
        ok, messages, required, *_ = validate(
            GOOD_BODY,
            [ChangedPath("D", "lib/ui/features/checkout/views/legacy_page.dart")],
        )

        self.assertTrue(ok, messages)
        self.assertTrue(required)

    def test_data_and_view_model_files_are_not_ui_surfaces(self) -> None:
        ok, messages, required, *_ = validate(
            "",
            [
                ChangedPath("A", "lib/ui/features/shop/data/shop_gateway.dart"),
                ChangedPath("M", "lib/ui/features/shop/view_models/shop_view_model.dart"),
            ],
        )

        self.assertTrue(ok, messages)
        self.assertFalse(required)

    def test_ui_suffix_outside_standard_root_still_requires_audit(self) -> None:
        ok, messages, required, new_component, _, paths = validate(
            GOOD_BODY, [ChangedPath("A", "lib/dev/claude_design/importer_page.dart")]
        )

        self.assertTrue(ok, messages)
        self.assertTrue(required)
        self.assertTrue(new_component)
        self.assertEqual(paths, ["lib/dev/claude_design/importer_page.dart"])

    def test_app_shell_change_requires_audit_even_without_ui_suffix(self) -> None:
        body = (
            GOOD_BODY.replace(
                "Surface-Type: checkout-form — the changed surface submits payment details and displays decline errors.",
                "Surface-Type: other — the app shell change only registers a read-only route.",
            )
            .replace("routes=/checkout", "routes=/status")
            .replace(
                "reviewed — changed the decline error to explain that no charge occurred and how to retry.",
                "not-applicable — the read-only route has no input, checkout, or error state.",
            )
        )
        ok, messages, required, _, microcopy_required, paths = validate(
            body, [ChangedPath("M", "lib/main.dart")]
        )

        self.assertTrue(ok, messages)
        self.assertTrue(required)
        self.assertFalse(microcopy_required)
        self.assertEqual(paths, ["lib/main.dart"])

    def test_generic_shell_checkout_scope_cannot_declare_other(self) -> None:
        body = GOOD_BODY.replace(
            "Surface-Type: checkout-form — the changed surface submits payment details and displays decline errors.",
            "Surface-Type: other — the generic app shell file name does not identify its UI.",
        )
        ok, messages, *_ = validate(body, [ChangedPath("M", "lib/main.dart")])

        self.assertFalse(ok)
        self.assertTrue(any("cannot declare" in message for message in messages))

    def test_plain_evidence_claim_without_reference_is_rejected(self) -> None:
        body = GOOD_BODY.replace(
            "https://github.com/kanta13jp1/my_web_app/pull/999#issuecomment-123",
            "Final Design plugin report was reviewed by the team.",
        )
        ok, messages, *_ = validate(
            body, [ChangedPath("M", "lib/pages/checkout_page.dart")]
        )

        self.assertFalse(ok)
        self.assertTrue(any("HTTPS URL" in message for message in messages))

    def test_deterministic_evidence_requires_at_boundary(self) -> None:
        body = GOOD_BODY.replace(
            "tests=widget semantics pass; keyboard-contrast=pass; AT=not-run — release owner will run NVDA before merge.",
            "tests=widget semantics pass; keyboard-contrast=pass",
        )
        ok, messages, *_ = validate(
            body, [ChangedPath("M", "lib/pages/checkout_page.dart")]
        )

        self.assertFalse(ok)
        self.assertTrue(any("`AT=`" in message for message in messages))

    def test_parses_git_name_status_and_rename_destination(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "changes.txt"
            path.write_text(
                "A\tlib\\widgets\\new_card.dart\n"
                "R100\tlib/ui/old.dart\tlib/ui/new.dart\n",
                encoding="utf-8",
            )
            changes = parse_changed_paths(str(path))

        self.assertEqual(
            changes,
            [
                ChangedPath("A", "lib/widgets/new_card.dart"),
                ChangedPath("R100", "lib/ui/new.dart"),
            ],
        )

    def test_emit_snippet_is_parseable_but_requires_replacement(self) -> None:
        snippet = passing_snippet(microcopy_required=True)
        ok, messages, required, *_ = validate(
            snippet, [ChangedPath("A", "lib/pages/checkout_page.dart")]
        )

        self.assertFalse(ok)
        self.assertTrue(required)
        self.assertTrue(any("placeholder" in message for message in messages))

    def test_emit_snippet_cli_exits_zero(self) -> None:
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            exit_code = main(["--emit-snippet", "--microcopy-required"])

        self.assertEqual(exit_code, 0)
        self.assertIn("Error-Microcopy-Review: reviewed", buffer.getvalue())

    def test_cli_fails_closed_without_changed_file_input(self) -> None:
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            exit_code = main([])

        self.assertEqual(exit_code, 2)
        self.assertIn("refusing to skip UI detection", buffer.getvalue())


if __name__ == "__main__":
    unittest.main()
