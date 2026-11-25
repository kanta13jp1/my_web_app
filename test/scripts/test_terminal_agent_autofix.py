#!/usr/bin/env python3
"""Tests for scripts/terminal_agent_autofix.py and terminal-agent-autofix workflow."""

from __future__ import annotations

import contextlib
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts import terminal_agent_autofix as autofix  # noqa: E402


class TerminalAgentAutofixTests(unittest.TestCase):
    def _create_sample_repo(self, root: Path) -> None:
        (root / "pubspec.yaml").write_text("name: my_web_app\n", encoding="utf-8")
        service = root / "lib" / "services" / "balance_sync_service.dart"
        service.parent.mkdir(parents=True, exist_ok=True)
        service.write_text(
            "\n".join(
                [
                    "import 'dart:ui';",
                    "",
                    "class BalanceSyncService {",
                    "  Color indicatorColor(Color base) {",
                    "    return base.withOpacity(0.5);",
                    "  }",
                    "",
                    "  List<String> tags() => ['sync'];",
                    "}",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        other = root / "lib" / "pages" / "settings_page.dart"
        other.parent.mkdir(parents=True, exist_ok=True)
        other.write_text(
            "class SettingsPage {\n  final String label = 'Settings';\n}\n",
            encoding="utf-8",
        )

    def test_issue_discovery_ranks_matching_lib_file_and_detects_missing_test(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            repo_root = Path(tmp_dir)
            self._create_sample_repo(repo_root)

            issue = autofix.parse_issue_payload(
                {
                    "issue": {
                        "number": 2675,
                        "title": "残高同期サービス BalanceSyncService の色更新とテスト追加",
                        "body": (
                            "## Additional Request\n"
                            "Fix deprecated color opacity inside `lib/services/balance_sync_service.dart`.\n"
                        ),
                        "labels": [{"name": "ai-autofix"}],
                    }
                }
            )
            self.assertEqual(issue.number, 2675)
            self.assertIn("lib/services/balance_sync_service.dart", issue.paths)
            self.assertIn("BalanceSyncService", issue.symbols)

            matches = autofix.discover_target_files(repo_root, issue)
            self.assertGreaterEqual(len(matches), 1)
            top = matches[0]
            self.assertEqual(top.path, "lib/services/balance_sync_service.dart")
            self.assertEqual(top.companion_test_path, "test/services/balance_sync_service_test.dart")
            self.assertFalse(top.has_companion_test)

    def test_plan_repairs_generates_clean_companion_test_scaffold(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            repo_root = Path(tmp_dir)
            self._create_sample_repo(repo_root)
            issue = autofix.parse_issue_payload(
                {
                    "number": 42,
                    "title": "BalanceSyncService scaffold",
                    "body": "Target `lib/services/balance_sync_service.dart`",
                }
            )
            matches = autofix.discover_target_files(repo_root, issue)
            planned_files, actions, blocked = autofix.plan_repairs(repo_root, issue, matches)

            self.assertEqual(blocked, [])
            self.assertIn("lib/services/balance_sync_service.dart", planned_files)
            self.assertIn("test/services/balance_sync_service_test.dart", planned_files)
            self.assertIn(
                ".withValues(alpha: 0.5)",
                planned_files["lib/services/balance_sync_service.dart"],
            )
            scaffold = planned_files["test/services/balance_sync_service_test.dart"]
            self.assertIn("package:my_web_app/services/balance_sync_service.dart", scaffold)
            self.assertIn("BalanceSyncService", scaffold)

            ok, findings, redactions = autofix.validate_file_contents(planned_files)
            self.assertTrue(ok, findings)
            self.assertEqual(findings, [])
            self.assertEqual(redactions, 0)
            self.assertTrue(any(a.kind == "generate_test_scaffold" for a in actions))

    def test_extract_build_diagnostics_and_iterative_convergence(self) -> None:
        raw_output = "\n".join(
            [
                "  info - Use withValues - lib/widgets/card.dart:4:17 - deprecated_member_use",
                "  info - Prefer const - lib/widgets/card.dart:5:25 - prefer_const_literals_to_create_immutables",
                "  info - Trailing comma - lib/widgets/card.dart:6:30 - require_trailing_commas",
                "  info - Final param - lib/widgets/card.dart:7:10 - prefer_final_parameters",
                "  info - Unused param 'unusedArg' - lib/widgets/card.dart:8:12 - unused_element_parameter",
                "lib/widgets/card.dart:9:14: Error: The method 'withOpacity' isn't defined.",
            ]
        )
        diags = autofix.extract_build_diagnostics(raw_output)
        self.assertEqual(len(diags), 6)
        self.assertEqual(diags[0].code, "deprecated_member_use")
        self.assertEqual(diags[5].severity, "error")
        self.assertEqual(diags[5].code, "withOpacity_error")

        initial_card = "\n".join(
            [
                "import 'dart:ui';",
                "class DemoCard {",
                "  Color a(Color c) {",
                "    return c.withOpacity(0.2);",
                "    final items = ['a', 'b'];",
                "    helper(items)",
                "  void run(String param) {}",
                "  void _priv(int unusedArg) {}",
                "  Color b(Color d) => d.withOpacity(0.8);",
                "}",
            ]
        )

        with tempfile.TemporaryDirectory() as tmp_dir:
            repo_root = Path(tmp_dir)
            card_file = repo_root / "lib" / "widgets" / "card.dart"
            card_file.parent.mkdir(parents=True, exist_ok=True)
            card_file.write_text(initial_card, encoding="utf-8")

            eval_calls = 0

            def reevaluate(updated_map: dict[str, str]) -> list[autofix.BuildDiagnostic]:
                nonlocal eval_calls
                eval_calls += 1
                text = updated_map["lib/widgets/card.dart"]
                self.assertIn(".withValues(alpha: 0.2)", text)
                self.assertIn("const ['a', 'b']", text)
                self.assertIn("helper(items,)", text)
                self.assertIn("final String param", text)
                self.assertIn("_unusedArg", text)
                self.assertIn(".withValues(alpha: 0.8)", text)
                return []

            files, actions, iterations, converged, blocked = autofix.run_self_repair_loop(
                repo_root,
                diags,
                max_iterations=3,
                reevaluate=reevaluate,
            )
            self.assertTrue(converged)
            self.assertEqual(blocked, [])
            self.assertEqual(eval_calls, 1)
            self.assertEqual(len(iterations), 2)
            self.assertEqual(iterations[0].repaired_count, 6)
            self.assertEqual(iterations[1].diagnostic_count, 0)
            self.assertEqual(len(actions), 6)
            self.assertIn("lib/widgets/card.dart", files)

    def test_dry_run_vs_apply_writes_only_on_apply(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            repo_root = Path(tmp_dir)
            self._create_sample_repo(repo_root)
            issue = autofix.parse_issue_payload(
                {
                    "number": 2675,
                    "title": "Fix BalanceSyncService",
                    "body": "Check `lib/services/balance_sync_service.dart`",
                }
            )

            dry = autofix.run_autofix(repo_root, issue, apply=False)
            self.assertEqual(dry.mode, "dry_run")
            self.assertTrue(dry.validation_passed)
            self.assertFalse((repo_root / "test" / "services" / "balance_sync_service_test.dart").exists())

            applied = autofix.run_autofix(repo_root, issue, apply=True)
            self.assertEqual(applied.mode, "apply")
            self.assertTrue(applied.validation_passed)
            self.assertTrue((repo_root / "test" / "services" / "balance_sync_service_test.dart").is_file())
            self.assertIn(
                ".withValues(alpha: 0.5)",
                (repo_root / "lib" / "services" / "balance_sync_service.dart").read_text(encoding="utf-8"),
            )

    def test_path_traversal_outside_scope_and_symlinks_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            repo_root = Path(tmp_dir)
            (repo_root / "lib").mkdir()
            (repo_root / "scripts").mkdir()
            outside = repo_root / "outside.dart"
            outside.write_text("// outside\n", encoding="utf-8")

            for bad_path in (
                "",
                "../outside.dart",
                "lib/../../outside.dart",
                "/abs/path.dart",
                "C:\\Windows\\system32\\foo.dart",
                ".github/workflows/terminal-agent-autofix.yml",
                "scripts/terminal_agent_autofix.py",
                "lib/not_dart.txt",
            ):
                with self.assertRaises(autofix.PathBoundaryError, msg=f"Should reject {bad_path!r}"):
                    autofix.resolve_editable_repo_path(repo_root, bad_path)

            link_path = repo_root / "lib" / "escape_link.dart"
            symlink_created = False
            try:
                os.symlink(outside, link_path)
                symlink_created = True
            except OSError:
                symlink_created = False

            if symlink_created:
                with self.assertRaises(autofix.PathBoundaryError):
                    autofix.resolve_editable_repo_path(repo_root, "lib/escape_link.dart")

            with mock.patch.object(
                Path,
                "is_symlink",
                autospec=True,
                side_effect=lambda self_path: self_path.name == "mock_link.dart",
            ):
                with self.assertRaises(autofix.PathBoundaryError):
                    autofix.resolve_editable_repo_path(repo_root, "lib/mock_link.dart")

            diags = autofix.extract_build_diagnostics(
                "info - Bad edit - .github/workflows/ci.yml:1:1 - error\n"
                "../escape.dart:2:1: Error: Invalid\n"
            )
            # Only .dart paths parse cleanly; explicitly test a traversal .dart diagnostic:
            traversal_diag = [
                autofix.BuildDiagnostic(
                    severity="error",
                    message="Escape",
                    path="../escape.dart",
                    line=1,
                    column=1,
                    code="prefer_final_parameters",
                )
            ]
            _, _, _, converged, blocked = autofix.run_self_repair_loop(
                repo_root,
                traversal_diag,
            )
            self.assertFalse(converged)
            self.assertEqual(len(blocked), 1)
            self.assertEqual(len(diags), 1)

    def test_cli_reports_redact_secrets_and_self_test_passes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            self._create_sample_repo(root)
            fake_key = "sk-" + "proj-" + "1234567890abcdef"
            issue_path = root / "issue.json"
            issue_path.write_text(
                json.dumps(
                    {
                        "number": 2675,
                        "title": "Autofix BalanceSyncService",
                        "body": f"Target `lib/services/balance_sync_service.dart` key={fake_key}",
                    }
                ),
                encoding="utf-8",
            )
            json_out = root / "report.json"
            md_out = root / "report.md"
            gh_out = root / "github_output.txt"

            exit_code = autofix.main(
                [
                    "--repo-root",
                    str(root),
                    "--issue-json",
                    str(issue_path),
                    "--dry-run",
                    "--json-out",
                    str(json_out),
                    "--markdown-out",
                    str(md_out),
                    "--github-output",
                    str(gh_out),
                ]
            )
            self.assertEqual(exit_code, 0)
            json_text = json_out.read_text(encoding="utf-8")
            md_text = md_out.read_text(encoding="utf-8")
            self.assertNotIn(fake_key, json_text)
            self.assertNotIn(fake_key, md_text)
            parsed = json.loads(json_text)
            self.assertGreaterEqual(parsed["redaction_count"], 1)
            self.assertIn("converged=true", gh_out.read_text(encoding="utf-8"))

        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(autofix.main(["--self-test"]), 0)

    def test_workflow_contract_security_and_opt_in_trigger(self) -> None:
        wf_path = ROOT / ".github" / "workflows" / "terminal-agent-autofix.yml"
        self.assertTrue(wf_path.is_file())
        content = wf_path.read_text(encoding="utf-8")
        self.assertIn("types: [labeled]", content)
        self.assertIn("github.event.label.name == 'ai-autofix'", content)
        self.assertIn("workflow_dispatch:", content)
        self.assertIn("default: 'true'", content)
        self.assertIn("permissions: {}", content)
        self.assertIn("contents: read", content)
        self.assertIn("issues: read", content)
        for forbidden_secret in (
            "SUPABASE_SERVICE_ROLE_KEY",
            "ANTHROPIC_API_KEY",
            "OPENAI_API_KEY",
            "CLAUDE_CODE_OAUTH_TOKEN",
        ):
            self.assertNotIn(forbidden_secret, content)


if __name__ == "__main__":
    unittest.main()
