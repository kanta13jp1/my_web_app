#!/usr/bin/env python3
from __future__ import annotations

import unittest
from fnmatch import fnmatchcase
from pathlib import Path

from check_cicd_path_filters import _extract_paths_ignore
from classify_ci_changes import NOTION_AUDIT_TESTS, SKILL_CONTRACT_TESTS, classify


class ClassifyCiChangesTest(unittest.TestCase):
    def test_playwright_evidence_repair_does_not_deploy_application(self) -> None:
        evidence_paths = [
            "playwright.config.ts",
            "scripts/summarize_playwright_results.mjs",
            "scripts/summarize_playwright_results_test.mjs",
            "scripts/playwright_report_persistence_test.mjs",
        ]
        changed_paths = [
            *evidence_paths,
            ".github/workflows/minimal-e2e-gate.yml",
            ".github/workflows/e2e-smoke.yml",
            ".github/workflows/deploy-prod.yml",
            "scripts/classify_ci_changes_test.py",
            "memory/vault/2026-09-21-palm-reading-integration-audit.md",
        ]
        result = classify(changed_paths)
        self.assertFalse(result["deployable"])
        root = Path(__file__).resolve().parents[1]
        workflow = (root / ".github/workflows/deploy-prod.yml").read_text(
            encoding="utf-8"
        )
        ignores = _extract_paths_ignore(workflow)
        for path in changed_paths:
            with self.subTest(path=path):
                self.assertTrue(any(fnmatchcase(path, pattern) for pattern in ignores))
        for path in evidence_paths:
            self.assertIn(path, ignores, "CI evidence exceptions must be explicit")
        for path in [
            "scripts/render_web_supabase_config.py", "web/index.html",
            "supabase/functions/ai-hub/index.ts",
            "supabase/migrations/20260921041500_create_palm_reading_history.sql",
        ]:
            with self.subTest(runtime_path=path):
                self.assertFalse(any(fnmatchcase(path, pattern) for pattern in ignores))
        self.assertTrue(classify([*changed_paths, "web/index.html"])["deployable"])

    def test_migration_does_not_start_flutter_deno_or_web(self) -> None:
        result = classify(["supabase/migrations/20260814000000_seed.sql"])

        self.assertTrue(result["migration"])
        self.assertFalse(result["flutter"])
        self.assertFalse(result["web"])
        self.assertFalse(result["edge"])
        self.assertFalse(result["caption"])
        self.assertTrue(result["deployable"])

    def test_seed_test_needs_flutter_but_not_web_build(self) -> None:
        result = classify(["test/services/ai_university_video_seed_test.dart"])

        self.assertTrue(result["flutter"])
        self.assertFalse(result["web"])
        self.assertFalse(result["deployable"])

    def test_app_code_needs_flutter_and_web(self) -> None:
        result = classify(["lib/pages/ai_university_page.dart"])

        self.assertTrue(result["flutter"])
        self.assertTrue(result["web"])

    def test_hosting_config_needs_web_deploy(self) -> None:
        result = classify(["firebase.json"])

        self.assertTrue(result["flutter"])
        self.assertTrue(result["web"])
        self.assertTrue(result["deployable"])

    def test_edge_and_caption_are_independent(self) -> None:
        edge = classify(["supabase/functions/app-hub/index.ts"])
        caption = classify(["services/caption-transcoder/test.js"])

        self.assertTrue(edge["edge"])
        self.assertFalse(edge["caption"])
        self.assertTrue(caption["caption"])
        self.assertFalse(caption["edge"])

    def test_tiger_status_triggers_tiger_group_only(self) -> None:
        result = classify(["assets/data/tiger_remediation_status.json"])

        self.assertTrue(result["tiger"])
        self.assertFalse(result["flutter"])
        self.assertFalse(result["web"])
        self.assertFalse(result["deployable"])

    def test_skill_python_suites_do_not_start_flutter(self) -> None:
        workflow = (Path(__file__).resolve().parents[1] /
                    ".github/workflows/agent-skill-contract.yml").read_text(encoding="utf-8")
        pr_paths = workflow.split("  pull_request:", 1)[1].split("  push:", 1)[0]
        for path in SKILL_CONTRACT_TESTS:
            with self.subTest(path=path):
                self.assertFalse(classify([path])["flutter"])
                self.assertFalse(classify([path])["deployable"])
                self.assertIn('"' + path + '"', pr_paths)
                self.assertIn("python " + path, workflow)

    def test_mixed_app_or_dart_changes_still_require_flutter(self) -> None:
        for path in ["lib/main.dart", "test/scripts/tool_test.dart",
                     "test/services/example_test.dart", "pubspec.lock"]:
            with self.subTest(path=path):
                self.assertTrue(classify([*SKILL_CONTRACT_TESTS, path])["flutter"])

    def test_notion_suites_have_dedicated_pr_validation(self) -> None:
        self.assertEqual(NOTION_AUDIT_TESTS, (
            "test/scripts/test_notion_migration_cloud_audit.py",
            "test/scripts/test_notion_wbs_import_plan.py",
        ))
        workflow = (Path(__file__).resolve().parents[1] /
                    ".github/workflows/notion-migration-cloud-audit.yml").read_text(
                        encoding="utf-8")
        pr_paths = workflow.split("  pull_request:\n    paths:\n", 1)[1].split(
            "  workflow_dispatch:", 1)[0]
        paths = [line.strip().removeprefix("- ") for line in pr_paths.splitlines()
                 if line.strip().startswith("- ")]
        validate = workflow.split("  validate:\n", 1)[1].split("  audit:\n", 1)[0]
        self.assertIn("if: github.event_name == 'pull_request'", validate)
        self.assertNotIn("continue-on-error", validate)
        for path in NOTION_AUDIT_TESTS:
            with self.subTest(path=path):
                self.assertIn(path, paths)
                self.assertIn("          PYTHONPATH=. python " + path + "\n", validate)
                self.assertFalse(any(classify([path]).values()))
        self.assertFalse(any(classify([
            "scripts/notion_migration_cloud_audit.py", *NOTION_AUDIT_TESTS,
        ]).values()))

    def test_notion_exceptions_preserve_mixed_and_forced_validation(self) -> None:
        for path in ["lib/main.dart", "web/index.html", "pubspec.lock",
                     "test/scripts/tool_test.dart", "test/unknown_test.py",
                     "test/scripts/test_notion_other.py"]:
            with self.subTest(path=path):
                self.assertTrue(classify([*NOTION_AUDIT_TESTS, path])["flutter"])
        self.assertTrue(classify([*NOTION_AUDIT_TESTS, "lib/main.dart"])["web"])
        self.assertTrue(all(classify(list(NOTION_AUDIT_TESTS), force_all=True).values()))

    def test_unknown_python_tests_remain_conservative(self) -> None:
        self.assertTrue(classify(["test/scripts/new_tool_test.py"])["flutter"])

    def test_manual_gate_still_includes_all_toolchains(self) -> None:
        self.assertTrue(all(classify(list(SKILL_CONTRACT_TESTS), force_all=True).values()))

    def test_force_all_enables_every_group(self) -> None:
        self.assertTrue(all(classify([], force_all=True).values()))


if __name__ == "__main__":
    unittest.main()
