#!/usr/bin/env python3
"""Pin ready-event wiring and credential boundaries without running workflows."""
from __future__ import annotations

import re
import unittest
from pathlib import Path

WORKFLOW = Path(__file__).resolve().parent.parent / ".github/workflows/claude-agent-review.yml"


def event_block(source: str, event: str) -> str:
    match = re.search(
        r"(?ms)^  " + re.escape(event) + r":[ \t]*\n(.*?)(?=^  [a-z_]+:|\Z)",
        source,
    )
    if not match:
        raise AssertionError(f"missing event {event}")
    return match.group(1)


def job_block(source: str, job: str) -> str:
    match = re.search(
        r"(?ms)^  " + re.escape(job) + r":[ \t]*\n(.*?)(?=^  [a-z0-9_-]+:[ \t]*\n|\Z)",
        source,
    )
    if not match:
        raise AssertionError(f"missing job {job}")
    return match.group(1)


def types(block: str) -> set[str]:
    match = re.search(r"(?m)^    types:[ \t]*\[([^\]]+)\]", block)
    if not match:
        raise AssertionError("missing event types")
    return {value.strip() for value in match.group(1).split(",")}


def permissions(block: str) -> set[str]:
    match = re.search(
        r"(?m)^    permissions:[ \t]*\n((?:^      [a-z-]+: [a-z]+\n)+)",
        block,
    )
    if not match:
        raise AssertionError("missing job permissions")
    return set(line.strip() for line in match.group(1).splitlines())


class ClaudeReviewWorkflowTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.workflow = WORKFLOW.read_text(encoding="utf-8")

    def test_ready_event_runs_the_contract_on_pull_request(self) -> None:
        self.assertEqual(
            types(event_block(self.workflow, "pull_request")),
            {"opened", "synchronize", "reopened", "ready_for_review"},
        )
        contract = job_block(self.workflow, "high-risk-ultrareview-gate")
        self.assertIn("    if: github.event_name == 'pull_request'\n", contract)
        self.assertIn("python scripts/check_high_risk_ultrareview_gate.py", contract)
        self.assertIn("persist-credentials: false", contract)

    def test_wiring_check_runs_in_contract_and_independent_ci(self) -> None:
        contract = job_block(self.workflow, "high-risk-ultrareview-gate")
        step = (
            "      - name: Verify high-risk workflow event and security boundaries\n"
            "        run: python -B scripts/check_claude_review_workflow_test.py\n"
        )
        self.assertEqual(contract.count(step), 1)
        self.assertNotIn("secrets.", contract)
        self.assertNotIn("github.token", contract)
        self.assertNotRegex(contract, r"(?m)^\s*env:[ \t]*$")
        ci = (WORKFLOW.parent / "ci.yml").read_text(encoding="utf-8")
        lint = job_block(ci, "lint-and-test")
        self.assertIn("    steps:\n", lint)
        job_settings = lint.split("    steps:\n", 1)[0]
        self.assertNotRegex(job_settings, r"""(?m)^    ['"]?(?:if|continue-on-error)['"]?[ \t]*:""")
        step_name = "      - name: Test CI scope classifier\n"
        self.assertEqual(lint.count(step_name), 1)
        start = lint.index(step_name)
        end = lint.index("\n      - name:", start + len(step_name))
        ci_step = lint[start:end]
        self.assertNotRegex(ci_step, r"""(?m)^        ['"]?(?:if|continue-on-error|shell)['"]?[ \t]*:""")
        self.assertRegex(ci_step, r"(?m)^        run: \|$")
        self.assertNotRegex(ci_step, r"(?m)^\s*set\s+\+e(?:\s|$)")
        self.assertEqual(
            ci_step.count(
                "          python -B scripts/check_claude_review_workflow_test.py\n"
            ),
            1,
        )

    def test_ready_event_does_not_expand_trusted_review(self) -> None:
        self.assertEqual(
            types(event_block(self.workflow, "pull_request_target")),
            {"opened", "synchronize", "reopened", "ready_for_review"},
        )
        trusted = job_block(self.workflow, "review")
        self.assertIn("github.event_name == 'pull_request_target'", trusted)
        self.assertIn("github.event_name == 'workflow_dispatch' && inputs.ultrareview != 'true'", trusted)
        self.assertNotIn("github.event_name == 'pull_request'", trusted)
        self.assertEqual(
            permissions(trusted),
            {"contents: read", "pull-requests: read", "checks: write"},
        )

    def test_pull_request_contract_remains_read_only_and_secret_free(self) -> None:
        self.assertRegex(self.workflow, r"(?m)^permissions: \{\}$")
        contract = job_block(self.workflow, "high-risk-ultrareview-gate")
        self.assertEqual(permissions(contract), {"contents: read", "pull-requests: read"})
        self.assertNotIn("secrets.", contract)
        self.assertNotIn("github.token", contract)

    def test_paid_ultrareview_stays_dispatch_and_opt_in_only(self) -> None:
        paid = job_block(self.workflow, "ultrareview")
        self.assertIn(
            "    if: github.event_name == 'workflow_dispatch' && "
            "github.event.inputs.ultrareview == 'true' && "
            "github.ref == 'refs/heads/main'\n",
            paid,
        )
        self.assertEqual(
            permissions(paid),
            {"contents: read", "issues: read", "pull-requests: write"},
        )
        self.assertIn("requested: ${{ vars.PAID_AI_CLAUDE_CODEX_ENABLED || 'false' }}", paid)
        for name in ("ANTHROPIC_API_KEY", "CLAUDE_CODE_OAUTH_TOKEN"):
            self.assertIn(
                "${{ vars.PAID_AI_CLAUDE_CODEX_ENABLED == 'true' && "
                "steps.paid_ai_policy.outputs.enabled == 'true' && secrets."
                + name + " || '' }}",
                paid,
            )


if __name__ == "__main__":
    unittest.main()
