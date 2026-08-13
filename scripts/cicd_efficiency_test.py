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

    def test_deploy_reuses_protected_pr_ci_result(self) -> None:
        deploy = self.read(".github/workflows/deploy-prod.yml")
        self.assertIn("if: github.event_name == 'workflow_dispatch'", deploy)
        self.assertIn("needs.ci.result == 'skipped'", deploy)
        self.assertIn("if: steps.changes.outputs.web == 'true'", deploy)
        self.assertIn("if: steps.changes.outputs.edge == 'true'", deploy)
        self.assertIn("if: steps.changes.outputs.migration == 'true'", deploy)

    def test_minimal_gate_does_not_poll_ci(self) -> None:
        workflow = self.read(".github/workflows/minimal-e2e-gate.yml")
        self.assertNotIn("Wait for deterministic CI checks", workflow)
        self.assertNotIn("check_pr_deterministic_ci.py", workflow)
        self.assertIn("workflow_run:", workflow)
        self.assertIn("public E2E runs after production deployment", workflow)

    def test_ga_gate_does_not_run_for_every_test_file(self) -> None:
        workflow = self.read(".github/workflows/ga-readiness-gate.yml")
        self.assertNotIn('- "test/**"', workflow)

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


if __name__ == "__main__":
    unittest.main()
