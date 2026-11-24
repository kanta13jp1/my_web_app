from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts import claude_design_to_theme_data as converter
from scripts import fix_design_tokens_generic as fixer


class FixDesignTokensGenericTests(unittest.TestCase):
    def test_normalizes_deprecated_flutter_web_apis_and_colors(self) -> None:
        raw = (
            "final c = Colors.indigo.shade700.withOpacity(0.5);\n"
            "final d = Colors.grey[700].withAlpha(128);\n"
            "final s = MaterialStateProperty.all(Colors.orange);\n"
            "final t = ThemeData(cardTheme: const CardTheme(elevation: 0));\n"
        )
        out = fixer.fix_design_tokens(raw)
        self.assertIn("Color(0xFF4338CA).withValues(alpha: 0.5)", out)
        self.assertIn("Color(0xFF334155).withValues(alpha: 0.5)", out)
        self.assertIn("WidgetStateProperty.all(const Color(0xFFFF6B35))", out)
        self.assertIn("CardThemeData(elevation: 0)", out)
        self.assertNotIn(".withOpacity(", out)

    def test_cli_backward_compatible_and_check_mode(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            sample = Path(tmp) / "sample_widget.dart"
            sample.write_text("final c = Colors.blue;\n", encoding="utf-8")

            self.assertEqual(fixer.main(["--check", str(sample)]), 1)
            self.assertEqual(fixer.main([str(sample)]), 0)
            self.assertEqual(
                sample.read_text(encoding="utf-8"),
                "final c = const Color(0xFF6366F1);\n",
            )
            self.assertEqual(fixer.main(["--check", str(sample)]), 0)

    def test_self_test_flag_passes(self) -> None:
        self.assertEqual(fixer.main(["--self-test"]), 0)


class ClaudeDesignToThemeDataTests(unittest.TestCase):
    def test_canonical_tokens_match_checked_in_generated_theme(self) -> None:
        rc = converter.main(
            [
                "--input",
                str(ROOT / "config/claude_design_tokens.json"),
                "--out",
                str(ROOT / "lib/theme/claude_design_generated_theme.dart"),
                "--check",
            ]
        )
        self.assertEqual(rc, 0)

    def test_rejects_malicious_or_invalid_tokens(self) -> None:
        for bad_payload in (
            [],
            {"tokens": {"colors": {"primary": "not-a-color'; exit(1);"}}},
            {"tokens": {"spacing": {"md": -10}}},
            {"sourceBundleId": "bad id with space"},
        ):
            with self.subTest(bad_payload=str(bad_payload)), self.assertRaises(
                converter.TokenSchemaError
            ):
                converter.generate_theme_data_dart(bad_payload)

    def test_cli_dry_run_write_and_check_cycle(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            inp = root / "tokens.json"
            out = root / "theme.dart"
            json_out = root / "summary.json"
            md_out = root / "summary.md"
            inp.write_text(
                json.dumps(
                    {
                        "sourceBundleId": "custom-bundle",
                        "tokens": {
                            "colors": {"primary": "#112233", "secondary": "#445566"},
                            "spacing": {"sm": 6, "md": 12},
                            "radius": {"md": 10, "lg": 14},
                        },
                    }
                ),
                encoding="utf-8",
            )
            self.assertEqual(
                converter.main(["--input", str(inp), "--out", str(out), "--dry-run"]),
                0,
            )
            self.assertFalse(out.exists())
            self.assertEqual(
                converter.main(
                    [
                        "--input",
                        str(inp),
                        "--out",
                        str(out),
                        "--class-name",
                        "CustomBrandTheme",
                        "--json-out",
                        str(json_out),
                        "--markdown-out",
                        str(md_out),
                    ]
                ),
                0,
            )
            generated = out.read_text(encoding="utf-8")
            self.assertIn("class CustomBrandTheme", generated)
            self.assertIn("0xFF112233", generated)
            self.assertEqual(
                json.loads(json_out.read_text(encoding="utf-8"))["status"],
                "generated",
            )
            self.assertIn("Claude Design ThemeData Conversion Summary", md_out.read_text(encoding="utf-8"))
            self.assertEqual(
                converter.main(
                    [
                        "--input",
                        str(inp),
                        "--out",
                        str(out),
                        "--class-name",
                        "CustomBrandTheme",
                        "--check",
                    ]
                ),
                0,
            )

    def test_self_test_flag_passes(self) -> None:
        self.assertEqual(converter.main(["--self-test"]), 0)


if __name__ == "__main__":
    unittest.main()
