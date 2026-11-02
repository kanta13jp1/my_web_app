"""Shared formatter configuration contract; does not launch editor toolchains."""

import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class FormatterSettingsTest(unittest.TestCase):
    def test_shared_formatter_contract(self):
        settings = json.loads((ROOT / ".vscode/settings.json").read_text())
        recommendations = json.loads(
            (ROOT / ".vscode/extensions.json").read_text()
        )["recommendations"]
        self.assertIs(settings["editor.formatOnSave"], True)
        expected = {
            "dart": "Dart-Code.dart-code",
            "javascript": "denoland.vscode-deno",
            "typescript": "denoland.vscode-deno",
            "json": "vscode.json-language-features",
            "jsonc": "vscode.json-language-features",
            "java": "redhat.java",
        }
        for language, formatter in expected.items():
            with self.subTest(language=language):
                self.assertEqual(
                    settings[f"[{language}]"]["editor.defaultFormatter"], formatter
                )
                if not formatter.startswith("vscode."):
                    self.assertIn(formatter, recommendations)

    def test_no_machine_specific_sdk_paths(self):
        settings = json.loads((ROOT / ".vscode/settings.json").read_text())
        for key in ("java.home", "java.jdt.ls.java.home", "java.configuration.runtimes",
                    "dart.sdkPath", "dart.flutterSdkPath", "deno.path"):
            self.assertNotIn(key, settings)


if __name__ == "__main__":
    unittest.main()
