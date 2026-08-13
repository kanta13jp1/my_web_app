#!/usr/bin/env python3
from __future__ import annotations

import unittest
from unittest.mock import patch

from pre_commit_quality_gate import commands_for_paths


class PreCommitQualityGateTest(unittest.TestCase):
    def test_workflow_change_uses_fast_policy_checks_without_flutter(self) -> None:
        commands = commands_for_paths([".github/workflows/ci.yml"])
        flattened = "\n".join(" ".join(command) for command in commands)

        self.assertIn("cicd_efficiency_test.py", flattened)
        self.assertNotIn("flutter analyze", flattened)
        self.assertNotIn("flutter test", flattened)

    @patch("pre_commit_quality_gate.Path.is_file", return_value=True)
    def test_dart_change_formats_only_staged_file(self, _: object) -> None:
        commands = commands_for_paths(["lib/pages/ai_university_page.dart"])

        self.assertEqual(
            commands,
            [[
                "dart",
                "format",
                "--output=none",
                "--set-exit-if-changed",
                "lib/pages/ai_university_page.dart",
            ]],
        )

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
