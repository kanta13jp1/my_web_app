#!/usr/bin/env python3
from __future__ import annotations

import unittest
from unittest.mock import patch

from pre_commit_quality_gate import commands_for_paths, resolve_executable


class PreCommitQualityGateTest(unittest.TestCase):
    @patch("pre_commit_quality_gate.shutil.which")
    @patch("pre_commit_quality_gate.os.name", "nt")
    def test_windows_resolves_dart_batch_shim(self, which: object) -> None:
        which.side_effect = lambda name: (
            r"C:\app\flutter\bin\dart.bat" if name == "dart.bat" else None
        )

        self.assertEqual(
            resolve_executable(["dart", "format", "lib/example.dart"]),
            [r"C:\app\flutter\bin\dart.bat", "format", "lib/example.dart"],
        )

    def test_workflow_change_uses_fast_policy_checks_without_flutter(self) -> None:
        commands = commands_for_paths([".github/workflows/ci.yml"])
        flattened = "\n".join(" ".join(command) for command in commands)

        self.assertIn("cicd_efficiency_test.py", flattened)
        self.assertNotIn("flutter analyze", flattened)
        self.assertNotIn("flutter test", flattened)

    @patch("pre_commit_quality_gate.Path.is_file", return_value=True)
    def test_dart_change_defers_version_pinned_format_to_ci(self, _: object) -> None:
        commands = commands_for_paths(["lib/pages/ai_university_page.dart"])

        self.assertEqual(commands, [])

    @patch("pre_commit_quality_gate.Path.is_file", return_value=True)
    def test_edge_change_lints_only_staged_edge_file(self, _: object) -> None:
        commands = commands_for_paths(["supabase/functions/app-hub/index.ts"])

        self.assertEqual(
            commands[0],
            [
                "deno",
                "lint",
                "--config",
                "supabase/functions/deno.json",
                "supabase/functions/app-hub/index.ts",
            ],
        )


if __name__ == "__main__":
    unittest.main()
