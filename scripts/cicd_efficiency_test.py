#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class CicdEfficiencyTest(unittest.TestCase):
    def read(self, relative: str) -> str:
        return (ROOT / relative).read_text(encoding="utf-8")

    def test_push_does_not_repeat_full_local_gate(self) -> None:
        lefthook = self.read("lefthook.yml")
        self.assertNotIn("pre-push:", lefthook)
        self.assertNotIn("quality_gate.py --full", lefthook)
        pre_commit = self.read("scripts/pre_commit_quality_gate.py")
        self.assertNotIn('quality_gate.main(["--fast"])', pre_commit)
        self.assertNotIn('"flutter", "analyze"', pre_commit)
        self.assertNotIn('["dart", "format"', pre_commit)

    def test_deploy_reuses_protected_pr_ci_result(self) -> None:
        deploy = self.read(".github/workflows/deploy-prod.yml")
        self.assertIn("if: github.event_name == 'workflow_dispatch'", deploy)
        self.assertIn("needs.ci.result == 'skipped'", deploy)
        self.assertIn("if: steps.changes.outputs.web == 'true'", deploy)
        self.assertIn("if: steps.changes.outputs.edge == 'true'", deploy)
        self.assertIn("if: steps.changes.outputs.migration == 'true'", deploy)

    def test_manual_web_only_deploy_skips_database_and_edge_scope(self) -> None:
        deploy = self.read(".github/workflows/deploy-prod.yml")
        self.assertIn("deploy_scope:", deploy)
        self.assertIn("- web_only", deploy)
        self.assertIn(
            "WEB_ONLY: ${{ github.event_name == 'workflow_dispatch' && "
            "inputs.deploy_scope == 'web_only' }}",
            deploy,
        )
        self.assertEqual(
            deploy.count(
                "FORCE_ALL: ${{ github.event_name != 'push' && "
                "inputs.deploy_scope != 'web_only' }}"
            ),
            2,
        )
        self.assertIn("printf 'web/index.html\\n'", deploy)
    def test_deploy_uses_global_semver_and_rejects_tag_mismatch(self) -> None:
        deploy = self.read(".github/workflows/deploy-prod.yml")
        self.assertNotIn("git describe --tags", deploy)
        self.assertIn("git tag --list 'v[0-9]*.[0-9]*.[0-9]*'", deploy)
        self.assertIn("grep -E '^v[0-9]+\\.[0-9]+\\.[0-9]+$'", deploy)
        self.assertIn("sort -V", deploy)
        self.assertIn(
            "Existing tag $TAG points to $EXISTING_TARGET, expected $GITHUB_SHA",
            deploy,
        )

        tag_step = deploy.split("- name: Push Release Tag", 1)[1].split(
            "- name: Create GitHub Release", 1
        )[0]
        self.assertNotIn("continue-on-error", tag_step)
        self.assertIn(
            'gh api --method POST "repos/$GITHUB_REPOSITORY/git/refs"',
            tag_step,
        )
        self.assertIn('-f sha="$GITHUB_SHA"', tag_step)
        self.assertIn("target_commitish: ${{ github.sha }}", deploy)
        self.assertIn("- name: Verify Release Tag Target", deploy)
        self.assertIn(
            "Release tag $TAG points to $REF_SHA, expected $GITHUB_SHA",
            deploy,
        )

    def test_minimal_gate_does_not_poll_ci(self) -> None:
        workflow = self.read(".github/workflows/minimal-e2e-gate.yml")
        self.assertNotIn("Wait for deterministic CI checks", workflow)
        self.assertNotIn("check_pr_deterministic_ci.py", workflow)
        self.assertIn("workflow_run:", workflow)
        public_job = workflow.split("  public-e2e-stability:", maxsplit=1)[1]
        self.assertNotIn("github.event_name == 'pull_request'", public_job)
        self.assertNotIn("Select deployed E2E scope", public_job)

    def test_non_app_prs_skip_minimal_e2e_declaration(self) -> None:
        script = self.read("scripts/check_minimal_e2e_gate.py")
        self.assertIn("if not app_change:", script)
        self.assertIn("no application runtime code changed", script)

    def test_ga_gate_does_not_run_for_every_test_file(self) -> None:
        workflow = self.read(".github/workflows/ga-readiness-gate.yml")
        self.assertNotIn('- "test/**"', workflow)
        self.assertNotIn("flutter analyze", workflow)
        self.assertNotIn("flutter test", workflow)
        self.assertIn("cancel-in-progress: ${{ github.event_name == 'pull_request' }}", workflow)

    def test_auto_fix_is_operator_initiated(self) -> None:
        workflow = self.read(".github/workflows/ci-auto-fix.yml")
        self.assertIn("workflow_dispatch:", workflow)
        self.assertNotIn("workflow_run:", workflow)

    def test_ci_expensive_steps_are_path_scoped(self) -> None:
        workflow = self.read(".github/workflows/ci.yml")
        self.assertIn("if: steps.changes.outputs.flutter == 'true'", workflow)
        self.assertIn("if: steps.changes.outputs.edge == 'true'", workflow)
        self.assertIn("if: steps.changes.outputs.caption == 'true'", workflow)
        self.assertIn("steps.changes.outputs.web == 'true'", workflow)

    def test_cloud_first_manual_gate_is_available(self) -> None:
        workflow = self.read(".github/workflows/ci.yml")
        self.assertIn("  workflow_dispatch:\n", workflow)
        self.assertIn(
            "github.event_name == 'pull_request' || "
            "github.event_name == 'workflow_dispatch'",
            workflow,
        )
        self.assertIn("python scripts/cloud_first_route_test.py", workflow)
        self.assertIn(
            "python scripts/generate_infrastructure_map_test.py", workflow
        )
        precommit = self.read("scripts/pre_commit_quality_gate.py")
        self.assertIn(
            "scripts/generate_infrastructure_map_test.py", precommit
        )
        self.assertIn("expected_head_sha:", workflow)
        self.assertIn('ref="${GITHUB_SHA}"', workflow)

        guide = self.read("docs/CLOUD_FIRST_DEVELOPMENT.md")
        self.assertIn(
            "python scripts/cloud_ci_handoff.py --execute --watch",
            guide,
        )
        self.assertIn("30 GiB", guide)
        self.assertIn("4 GiB", guide)

    def test_required_ci_checks_are_emitted_for_docs_only_prs(self) -> None:
        workflow = self.read(".github/workflows/ci.yml")
        pull_request = workflow.split("  pull_request:", 1)[1].split(
            "  push:", 1
        )[0]
        push = workflow.split("  push:", 1)[1].split("  workflow_call:", 1)[0]
        lint_job = workflow.split("  lint-and-test:", 1)[1].split(
            "  security-check:", 1
        )[0]
        security_job = workflow.split("  security-check:", 1)[1].split(
            "  pr-comment:", 1
        )[0]

        self.assertNotIn("paths-ignore:", pull_request)
        self.assertIn("paths-ignore:", push)
        self.assertIn("  workflow_call:", workflow)
        self.assertIn(
            "FORCE_ALL: ${{ github.event_name != 'pull_request' }}", workflow
        )
        self.assertIn("name: Lint, Format, and Test", workflow)
        self.assertIn("name: Security Check", workflow)
        self.assertNotIn("\n    if:", lint_job)
        self.assertNotIn("\n    if:", security_job)


if __name__ == "__main__":
    unittest.main()
