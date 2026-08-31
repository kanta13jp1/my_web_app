from __future__ import annotations

from pathlib import Path
import tempfile
import unittest

from paid_ai_policy import audit_workflows, decide_policy


class PolicyDecisionTest(unittest.TestCase):
    def test_owner_disabled_does_not_need_issue_lookup(self) -> None:
        decision = decide_policy("false")
        self.assertFalse(decision.enabled)
        self.assertEqual(decision.reason, "owner-disabled")
        self.assertIsNone(decision.open_issue_count)

    def test_open_issues_block_accidental_reactivation(self) -> None:
        decision = decide_policy("true", 742)
        self.assertFalse(decision.enabled)
        self.assertEqual(decision.reason, "open-issues-remain")

    def test_zero_issues_and_owner_opt_in_enable_paid_path(self) -> None:
        decision = decide_policy("true", 0)
        self.assertTrue(decision.enabled)
        self.assertEqual(decision.reason, "enabled-after-issues-zero")

    def test_lookup_failure_is_fail_closed(self) -> None:
        decision = decide_policy("true", lookup_error="network unavailable")
        self.assertFalse(decision.enabled)
        self.assertEqual(decision.reason, "issue-count-unavailable")


class WorkflowAuditTest(unittest.TestCase):
    def test_guarded_secret_reference_passes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            (directory / "guarded.yml").write_text(
                "id: paid_ai_policy\n"
                "ANTHROPIC_API_KEY: ${{ vars.PAID_AI_CLAUDE_CODEX_ENABLED == 'true' && "
                "steps.paid_ai_policy.outputs.enabled == 'true' && secrets.ANTHROPIC_API_KEY || '' }}\n",
                encoding="utf-8",
            )
            self.assertEqual(audit_workflows(directory), [])

    def test_unguarded_secret_reference_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            (directory / "unsafe.yml").write_text(
                "ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}\n",
                encoding="utf-8",
            )
            errors = audit_workflows(directory)
            self.assertTrue(errors)
            self.assertIn("missing guard", errors[0])

    def test_migration_control_is_exempt_only_without_provider_calls(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            path = directory / "shared-secret-environment-migration.yml"
            path.write_text(
                "ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}\n"
                "run: gh secret set ANTHROPIC_API_KEY\n",
                encoding="utf-8",
            )
            self.assertEqual(audit_workflows(directory), [])
            path.write_text(
                "ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}\n"
                "run: curl https://api.anthropic.com/v1/messages\n",
                encoding="utf-8",
            )
            errors = audit_workflows(directory)
            self.assertTrue(errors)
            self.assertIn("must not call a paid provider", errors[0])


if __name__ == "__main__":
    unittest.main()
