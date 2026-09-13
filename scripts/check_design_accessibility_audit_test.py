#!/usr/bin/env python3
from __future__ import annotations

import contextlib
import io
import tempfile
import unittest
from pathlib import Path

from check_design_accessibility_audit import (
    ChangedPath,
    function_declared,
    has_visual_parity,
    main,
    parse_changed_paths,
    passing_snippet,
    validate,
    visual_fingerprint,
    visual_parity_declarations,
    visual_parity_section,
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


# A small excerpt modeled on the real `lib/pages/asset_management_page.dart`
# refactor (PR #5376) that motivated the Visual Parity Exemption: swapping
# `TextFormField(initialValue: ...)` for a persistent `TextEditingController`
# to fix a real-browser input-persistence bug, with zero intended visual
# change. This is the primary case the exemption exists to unblock.
OLD_ASSET_PAGE_SOURCE = """
class _AssetManagementPageState extends State<AssetManagementPage> {
  final Map<String, TextEditingController> _annualRateControllers =
      <String, TextEditingController>{};

  void dispose() {
    _annualRateControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  void _syncPaymentStateControllers() {
    _syncAnnualRateControllers();
  }

  Widget _buildRevolvingField({
    required AssetLiabilityDebtRow row,
    required String label,
    required String hint,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, height: 1.3)),
        Expanded(
          child: TextFormField(
            key: ValueKey('revolving:${row.id}:$label'),
            initialValue: value > 0 ? value.toStringAsFixed(0) : '',
            keyboardType: TextInputType.number,
          ),
        ),
      ],
    );
  }

  Widget _buildDebtCard(AssetLiabilityDebtRow row) {
    return _buildRevolvingField(
      row: row,
      label: '最低返済額',
      hint: '例: 10000',
      value: 1000,
      onChanged: (amount) => _updateRevolvingMonthlyAmount(row.id, amount),
    );
  }
}
"""

NEW_ASSET_PAGE_SOURCE = """
class _AssetManagementPageState extends State<AssetManagementPage> {
  final Map<String, TextEditingController> _annualRateControllers =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _revolvingMonthlyAmountControllers =
      <String, TextEditingController>{};

  void dispose() {
    _annualRateControllers.forEach((_, controller) => controller.dispose());
    _revolvingMonthlyAmountControllers.forEach(
      (_, controller) => controller.dispose(),
    );
    super.dispose();
  }

  void _syncPaymentStateControllers() {
    _syncAnnualRateControllers();
    _syncRevolvingFieldControllers();
  }

  void _syncRevolvingFieldControllers() {
    _revolvingMonthlyAmountControllers.forEach((id, controller) {
      final amount = _revolvingConfigs[id]?.monthlyAmount ?? 0;
      final text = amount > 0 ? amount.round().toString() : '';
      if (controller.text != text) {
        controller.text = text;
      }
    });
  }

  TextEditingController _revolvingMonthlyAmountControllerFor(
    AssetLiabilityDebtRow row,
  ) {
    return _revolvingMonthlyAmountControllers.putIfAbsent(row.id, () {
      final amount = _revolvingConfigs[row.id]?.monthlyAmount ?? 0;
      return TextEditingController(
        text: amount > 0 ? amount.round().toString() : '',
      );
    });
  }

  Widget _buildRevolvingField({
    required Key fieldKey,
    required String label,
    required String hint,
    required TextEditingController controller,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, height: 1.3)),
        Expanded(
          child: TextField(
            key: fieldKey,
            controller: controller,
            keyboardType: TextInputType.number,
          ),
        ),
      ],
    );
  }

  Widget _buildDebtCard(AssetLiabilityDebtRow row) {
    return _buildRevolvingField(
      fieldKey: ValueKey('revolving:${row.id}:最低返済額'),
      label: '最低返済額',
      hint: '例: 10000',
      controller: _revolvingMonthlyAmountControllerFor(row),
      onChanged: (amount) => _updateRevolvingMonthlyAmount(row.id, amount),
    );
  }
}
"""

ASSET_PAGE_EXEMPT_FUNCTIONS = [
    "_buildRevolvingField",
    "_syncRevolvingFieldControllers",
    "_revolvingMonthlyAmountControllerFor",
    "_syncPaymentStateControllers",
    "dispose",
]


class VisualFingerprintTest(unittest.TestCase):
    def test_ignores_key_constructor_calls_and_arguments(self) -> None:
        with_key = "Text('hi', key: ValueKey('unstable-${DateTime.now()}'))"
        without_key = "Text('hi', key: someStableKey)"

        self.assertEqual(visual_fingerprint(with_key), visual_fingerprint(without_key))

    def test_ignores_empty_string_literals_regardless_of_position(self) -> None:
        one_empty = "Text(value.isEmpty ? '' : value)"
        no_empty_but_same_shape = "Text(value.isEmpty ? value : value)"

        # Both have the same call:/non-empty-text: token sequence once the
        # meaningless empty literal is dropped from the first.
        self.assertEqual(
            visual_fingerprint(one_empty), visual_fingerprint(no_empty_but_same_shape)
        )

    def test_ignores_function_type_syntax_and_plain_controller_classes(self) -> None:
        source = (
            "void sync(double Function(Config c) selector) {\n"
            "  final controller = TextEditingController(text: 'x');\n"
            "}"
        )
        fingerprint = visual_fingerprint(source)

        self.assertNotIn("call:Function", fingerprint)
        self.assertNotIn("call:TextEditingController", fingerprint)
        self.assertIn("text:x", fingerprint)

    def test_detects_real_widget_type_change(self) -> None:
        old = "Widget build() => TextField(key: k);"
        new = "Widget build() => CupertinoTextField(key: k);"

        self.assertNotEqual(visual_fingerprint(old), visual_fingerprint(new))

    def test_detects_changed_visible_text(self) -> None:
        old = "Text('最低返済額')"
        new = "Text('最低返済額改')"

        self.assertNotEqual(visual_fingerprint(old), visual_fingerprint(new))


class HasVisualParityTest(unittest.TestCase):
    def test_accepts_textformfield_to_controller_refactor(self) -> None:
        ok, reasons = has_visual_parity(
            OLD_ASSET_PAGE_SOURCE, NEW_ASSET_PAGE_SOURCE, ASSET_PAGE_EXEMPT_FUNCTIONS
        )

        self.assertTrue(ok, reasons)

    def test_rejects_changed_label_text_even_inside_declared_function(self) -> None:
        tampered = NEW_ASSET_PAGE_SOURCE.replace(
            "Text(label, style: const TextStyle(fontSize: 11, height: 1.3)),",
            "Text('固定表示', style: const TextStyle(fontSize: 11, height: 1.3)),",
        )
        self.assertNotEqual(tampered, NEW_ASSET_PAGE_SOURCE)

        ok, reasons = has_visual_parity(
            OLD_ASSET_PAGE_SOURCE, tampered, ASSET_PAGE_EXEMPT_FUNCTIONS
        )

        self.assertFalse(ok, reasons)

    def test_rejects_changed_hint_text_outside_declared_functions(self) -> None:
        tampered = NEW_ASSET_PAGE_SOURCE.replace(
            "hint: '例: 10000',", "hint: '例: 99999',"
        )
        self.assertNotEqual(tampered, NEW_ASSET_PAGE_SOURCE)

        ok, reasons = has_visual_parity(
            OLD_ASSET_PAGE_SOURCE, tampered, ASSET_PAGE_EXEMPT_FUNCTIONS
        )

        self.assertFalse(ok, reasons)

    def test_rejects_unaliased_widget_type_swap(self) -> None:
        tampered = NEW_ASSET_PAGE_SOURCE.replace(
            "child: TextField(", "child: CupertinoTextField(", 1
        )
        self.assertNotEqual(tampered, NEW_ASSET_PAGE_SOURCE)

        ok, reasons = has_visual_parity(
            OLD_ASSET_PAGE_SOURCE, tampered, ASSET_PAGE_EXEMPT_FUNCTIONS
        )

        self.assertFalse(ok, reasons)

    def test_fails_closed_for_new_file(self) -> None:
        ok, reasons = has_visual_parity(
            None, NEW_ASSET_PAGE_SOURCE, ASSET_PAGE_EXEMPT_FUNCTIONS
        )

        self.assertFalse(ok, reasons)

    def test_fails_closed_without_declared_functions(self) -> None:
        ok, reasons = has_visual_parity(OLD_ASSET_PAGE_SOURCE, NEW_ASSET_PAGE_SOURCE, [])

        self.assertFalse(ok, reasons)

    def test_fails_closed_for_a_declared_function_that_does_not_exist(self) -> None:
        ok, reasons = has_visual_parity(
            OLD_ASSET_PAGE_SOURCE,
            NEW_ASSET_PAGE_SOURCE,
            ASSET_PAGE_EXEMPT_FUNCTIONS + ["_thisFunctionDoesNotExist"],
        )

        self.assertFalse(ok)
        self.assertTrue(any("_thisFunctionDoesNotExist" in reason for reason in reasons))

    def test_function_declared_finds_multiline_named_parameter_signature(self) -> None:
        self.assertTrue(function_declared(NEW_ASSET_PAGE_SOURCE, "_buildRevolvingField"))
        self.assertFalse(function_declared(NEW_ASSET_PAGE_SOURCE, "_doesNotExist"))


class VisualParitySectionTest(unittest.TestCase):
    def test_parses_file_and_functions_declaration(self) -> None:
        body = (
            "## Visual Parity Exemption\n\n"
            "- File: lib/pages/asset_management_page.dart; "
            "Functions: _buildRevolvingField, dispose\n"
        )

        declarations = visual_parity_declarations(visual_parity_section(body))

        self.assertEqual(
            declarations,
            {"lib/pages/asset_management_page.dart": ["_buildRevolvingField", "dispose"]},
        )

    def test_missing_section_is_empty(self) -> None:
        self.assertEqual(visual_parity_section("## Some Other Section\n\nhello"), "")


class ValidateWithVisualParityExemptionTest(unittest.TestCase):
    EXEMPTION_BODY = (
        "## Visual Parity Exemption\n\n"
        "- File: lib/pages/asset_management_page.dart; Functions: "
        + ", ".join(ASSET_PAGE_EXEMPT_FUNCTIONS)
        + "\n"
    )

    def test_verified_exemption_skips_the_full_audit(self) -> None:
        ok, messages, required, new_component, microcopy_required, paths = validate(
            self.EXEMPTION_BODY,
            [ChangedPath("M", "lib/pages/asset_management_page.dart")],
            {
                "lib/pages/asset_management_page.dart": (
                    OLD_ASSET_PAGE_SOURCE,
                    NEW_ASSET_PAGE_SOURCE,
                )
            },
        )

        self.assertTrue(ok, messages)
        self.assertTrue(required)
        self.assertFalse(new_component)
        self.assertEqual(paths, ["lib/pages/asset_management_page.dart"])

    def test_unverified_exemption_falls_back_to_requiring_full_audit(self) -> None:
        tampered_new = NEW_ASSET_PAGE_SOURCE.replace(
            "hint: '例: 10000',", "hint: '例: 99999',"
        )
        ok, messages, required, *_ = validate(
            self.EXEMPTION_BODY,
            [ChangedPath("M", "lib/pages/asset_management_page.dart")],
            {"lib/pages/asset_management_page.dart": (OLD_ASSET_PAGE_SOURCE, tampered_new)},
        )

        self.assertFalse(ok)
        self.assertTrue(required)
        self.assertTrue(
            any("Missing `## Design Accessibility Audit`" in message for message in messages)
        )
        self.assertTrue(any("did not verify" in message for message in messages))

    def test_exemption_declared_but_no_file_contents_supplied_falls_back(self) -> None:
        ok, messages, required, *_ = validate(
            self.EXEMPTION_BODY,
            [ChangedPath("M", "lib/pages/asset_management_page.dart")],
            None,
        )

        self.assertFalse(ok)
        self.assertTrue(required)
        self.assertTrue(any("no base/head file content" in message for message in messages))

    def test_exemption_not_covering_every_changed_file_falls_back(self) -> None:
        ok, messages, required, *_ = validate(
            self.EXEMPTION_BODY,
            [
                ChangedPath("M", "lib/pages/asset_management_page.dart"),
                ChangedPath("M", "lib/pages/other_page.dart"),
            ],
            {
                "lib/pages/asset_management_page.dart": (
                    OLD_ASSET_PAGE_SOURCE,
                    NEW_ASSET_PAGE_SOURCE,
                ),
                "lib/pages/other_page.dart": ("old", "new"),
            },
        )

        self.assertFalse(ok)
        self.assertTrue(required)
        self.assertTrue(any("does not cover every changed" in message for message in messages))


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
