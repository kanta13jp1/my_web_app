"""Regression tests for bootstrap, fail-closed routing, and anonymous probes."""
import fnmatch
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import production_core_hub_scope as target

ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATHS = {
    ".github/workflows/deploy-prod.yml",
    ".github/workflows/deploy-core-hub.yml",
    "scripts/production_core_hub_scope.py",
    "scripts/production_core_hub_scope_test.py",
}


def ignored_paths(workflow: str) -> list[str]:
    block = workflow.split("    paths-ignore:\n", 1)[1].split("  workflow_dispatch:", 1)[0]
    return [line.strip()[2:].strip("'\"") for line in block.splitlines() if line.strip().startswith("- ")]


class RoutingTests(unittest.TestCase):
    def test_bootstrap_and_blog_pushes_do_not_start_general_deploy(self):
        workflow = (ROOT / ".github/workflows/deploy-prod.yml").read_text(encoding="utf-8")
        patterns = ignored_paths(workflow)
        for paths in [CONFIG_PATHS, target.BLOG_PATHS]:
            self.assertTrue(all(any(fnmatch.fnmatchcase(path, p) for p in patterns) for path in paths))

    def test_pure_blog_routes_only_to_core_hub(self):
        self.assertEqual(target.scope(list(target.BLOG_PATHS)), "core-hub")
        self.assertEqual(target.scope([target.BLOG_SOURCE]), "core-hub")

    def test_bootstrap_does_not_start_dedicated_push(self):
        workflow = (ROOT / ".github/workflows/deploy-core-hub.yml").read_text(encoding="utf-8")
        block = workflow.split("  push:\n", 1)[1].split("  pull_request:\n", 1)[0]
        paths = {line.strip()[2:] for line in block.splitlines() if line.strip().startswith("- ")}
        self.assertEqual(paths, target.BLOG_PATHS)
        self.assertTrue(paths.isdisjoint(CONFIG_PATHS))

    def test_existing_isolated_db_edge_gate_precedes_deploy(self):
        workflow = (ROOT / ".github/workflows/deploy-core-hub.yml").read_text(encoding="utf-8")
        deployment = workflow.index("Deploy core-hub only")
        for command in ["python test/scripts/test_testcontainers_supabase_smoke.py",
                        "python scripts/testcontainers_supabase_smoke.py --plan",
                        "python scripts/testcontainers_supabase_smoke.py --artifacts-dir .testcontainers-logs"]:
            self.assertLess(workflow.index(command), deployment)
        self.assertIn('TESTCONTAINERS_RYUK_DISABLED: "true"', workflow)

    def test_mixed_paths_fail_including_ignored_docs(self):
        for other in ["docs/note.md", "web/index.html", "lib/main.dart", "supabase/functions/ai-hub/index.ts",
                      "supabase/functions/_shared/saas_human_approval.ts", "supabase/functions/deno.lock",
                      "supabase/migrations/anything.sql", "unknown/path", *CONFIG_PATHS]:
            with self.subTest(other=other), self.assertRaises(ValueError):
                target.scope([target.BLOG_SOURCE, other])

    def test_missing_evidence_and_tests_only_fail(self):
        for paths in [[], [""], [" "], [" " + target.BLOG_SOURCE], ["supabase/functions/core-hub/index_test.ts"]]:
            with self.subTest(paths=paths), self.assertRaises(ValueError):
                target.scope(paths)
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaises(FileNotFoundError):
                target.checked_paths(Path(folder) / "missing")

    def test_non_blog_general_deploy_is_preserved(self):
        self.assertEqual(target.scope(["supabase/functions/ai-hub/index.ts"]), "general")
        self.assertEqual(target.scope(["web/index.html"]), "general")
        self.assertEqual(target.scope(list(CONFIG_PATHS)), "general")

    def test_general_lane_checks_complete_diff_before_any_production_step(self):
        workflow = (ROOT / ".github/workflows/deploy-prod.yml").read_text(encoding="utf-8")
        guard = workflow.index("Reject mixed public-blog deployments")
        for step in ["Run Supabase migrations", "Cleanup consolidated Edge Functions", "Deploy Supabase Edge Functions", "Deploy to Firebase"]:
            self.assertLess(guard, workflow.index(step))
        self.assertIn('git diff --name-only "$BEFORE_SHA" "$GITHUB_SHA"', workflow)
        self.assertNotIn("compareCommitsWithBasehead", workflow)

    def test_dedicated_deploy_has_no_broad_or_database_commands(self):
        workflow = (ROOT / ".github/workflows/deploy-core-hub.yml").read_text(encoding="utf-8")
        for forbidden in ["supabase db", "supabase link", "supabase secrets", "functions delete", "--prune", "firebase", "update-wbs", "SERVICE_ROLE"]:
            self.assertNotIn(forbidden, workflow)
        self.assertIn('supabase functions deploy core-hub --project-ref "$SUPABASE_PROJECT_ID_PROD" --no-verify-jwt --use-api', workflow)
        self.assertNotIn("continue-on-error", workflow)
        self.assertNotIn("workflow_dispatch", workflow)
        self.assertNotIn("workflow_run", workflow)
        self.assertLess(workflow.index("require exact scope"), workflow.index("Deploy core-hub only"))
        self.assertLess(workflow.index("Recheck core-hub"), workflow.index("Deploy core-hub only"))
        self.assertIn("name: production", workflow)
        self.assertNotIn("contents: write", workflow)
        self.assertNotIn("actions: write", workflow)

    def test_no_mutual_cancel_and_multi_pending_queue(self):
        for name in ["deploy-prod.yml", "deploy-core-hub.yml"]:
            workflow = (ROOT / ".github/workflows" / name).read_text(encoding="utf-8")
            self.assertIn("group: deploy-prod", workflow)
            self.assertIn("cancel-in-progress: false", workflow)
            self.assertIn("queue: max", workflow)


class ProbeTests(unittest.TestCase):
    def responses(self):
        post_id = "11111111-1111-4111-8111-111111111111"
        return [(200, {"success": True, "posts": [{"id": post_id}]}),
                (200, {"success": True, "post": {"id": post_id}}),
                (404, {"error": "not found"}), (200, {"success": True})]

    def test_four_anonymous_contracts(self):
        with patch.object(target, "request", side_effect=self.responses()) as request:
            target.probe()
        self.assertEqual([call.args[0] for call in request.call_args_list],
                         ["blog.public.list", "blog.public.view", "blog.public.view", "memo.public.list"])

    def test_old_500_is_failure(self):
        with patch.object(target, "request", return_value=(500, {"error": "Internal server error"})):
            with self.assertRaises(ValueError):
                target.probe()

    def test_wrong_article_missing_or_memo_status_is_failure(self):
        for index in [1, 2, 3]:
            responses = self.responses()
            responses[index] = (500, {})
            with self.subTest(index=index), patch.object(target, "request", side_effect=responses):
                with self.assertRaises(ValueError):
                    target.probe()


if __name__ == "__main__":
    unittest.main(verbosity=2)
