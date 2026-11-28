#!/usr/bin/env python3
"""Unit and contract tests for Cursor SDK security review and CI autofix triage (#2693)."""

from __future__ import annotations

import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

import cursor_security_review as csr  # noqa: E402


class CursorSecurityReviewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.policy = csr.load_policy(ROOT / "config/cursor_security_review_policy.json")

    def test_detects_supabase_rls_client_key_edge_cors_and_flutter_risks(self) -> None:
        sample_diff = "\n".join(
            [
                "diff --git a/supabase/migrations/20261125001000_rls.sql b/supabase/migrations/20261125001000_rls.sql",
                "+++ b/supabase/migrations/20261125001000_rls.sql",
                "@@ -1,0 +1,2 @@",
                "+CREATE POLICY bad_rls ON public.notes FOR ALL USING (true) WITH CHECK (true);",
                "diff --git a/lib/services/supabase_client.dart b/lib/services/supabase_client.dart",
                "+++ b/lib/services/supabase_client.dart",
                "@@ -4,0 +5,2 @@",
                "+const keyName = 'SUPABASE_SERVICE_ROLE_KEY';",
                "+final baseUrl = 'http://api.unencrypted.example.com/v1';",
                "diff --git a/supabase/functions/admin-sync/index.ts b/supabase/functions/admin-sync/index.ts",
                "+++ b/supabase/functions/admin-sync/index.ts",
                "@@ -8,0 +9,1 @@",
                "+const cors = { 'Access-Control-Allow-Headers': 'authorization, apikey, content-type' };",
            ]
        )
        findings = csr.scan_diff_security_findings(sample_diff, self.policy)
        rule_ids = {f.rule_id for f in findings}
        self.assertIn("supabase-rls-permissive", rule_ids)
        self.assertIn("supabase-client-privileged-key", rule_ids)
        self.assertIn("flutter-cleartext-http-endpoint", rule_ids)
        self.assertIn("supabase-edge-missing-tracing-header", rule_ids)

    def test_inline_pr_review_payload_never_auto_approves_or_auto_merges(self) -> None:
        findings = [
            csr.SecurityFinding(
                rule_id="supabase-rls-permissive",
                domain="supabase-rls",
                severity="critical",
                blocking=True,
                path="supabase/migrations/20261125001000_rls.sql",
                line=12,
                cwe="CWE-862",
                title="Permissive RLS",
                recommendation="Bind USING clause to auth.uid().",
                source="deterministic_policy",
                snippet="USING (true)",
            )
        ]
        payload = csr.build_pr_inline_review_payload(
            pr_number=6400,
            commit_sha="abcdef123456",
            findings=findings,
            sdk_mode="offline_deterministic_fallback",
        )
        self.assertEqual(payload["event"], "REQUEST_CHANGES")
        self.assertTrue(payload["human_approval_required"])
        self.assertFalse(payload["auto_merge_allowed"])
        self.assertEqual(len(payload["comments"]), 1)
        self.assertEqual(payload["comments"][0]["side"], "RIGHT")
        self.assertEqual(payload["comments"][0]["line"], 12)

        empty_payload = csr.build_pr_inline_review_payload(
            pr_number=6400,
            commit_sha="abcdef123456",
            findings=[],
            sdk_mode="offline_deterministic_fallback",
        )
        self.assertEqual(empty_payload["event"], "COMMENT")
        self.assertFalse(empty_payload["auto_merge_allowed"])

    def test_missing_cursor_key_falls_back_gracefully_without_failing(self) -> None:
        report = csr.run_security_review_pipeline(
            diff_text="diff --git a/lib/main.dart b/lib/main.dart\n+++ b/lib/main.dart\n@@ -1,0 +1,1 @@\n+final ok = true;\n",
            changed_paths=["lib/main.dart"],
            policy=self.policy,
            environ={},
            dry_run=False,
            enable_cursor_sdk=True,
        )
        self.assertEqual(report["audit_log"]["sdk_status"], "offline_fallback_missing_cursor_key")
        self.assertEqual(report["audit_log"]["finding_count"], 0)
        self.assertTrue(report["audit_log"]["human_approval_required"])
        self.assertFalse(report["audit_log"]["auto_merge_allowed"])

    def test_mocked_cursor_sdk_redacts_diff_and_merges_findings(self) -> None:
        captured: list[str] = []
        dummy_cred = "Bearer " + "cursor_secret_material_987654"

        def mock_sdk(endpoint: str, cred: str, prompt_diff: str, **_kwargs: object) -> dict[str, object]:
            captured.append(prompt_diff)
            self.assertEqual(endpoint, "https://api.cursor.com/v0/agents/review")
            self.assertTrue(cred)
            return {
                "findings": [
                    {
                        "rule_id": "cursor-auth-guard",
                        "domain": "supabase-auth",
                        "severity": "high",
                        "path": "lib/pages/admin.dart",
                        "line": 27,
                        "title": "Admin route lacks role verification",
                        "recommendation": "Check authenticated admin claim server-side.",
                    }
                ]
            }

        dirty_diff = "\n".join(
            [
                "diff --git a/lib/pages/admin.dart b/lib/pages/admin.dart",
                "+++ b/lib/pages/admin.dart",
                "@@ -25,0 +26,2 @@",
                f"+final authHeader = '{dummy_cred}';",
                "+void openAdmin() {}",
            ]
        )
        report = csr.run_security_review_pipeline(
            diff_text=dirty_diff,
            changed_paths=["lib/pages/admin.dart"],
            policy=self.policy,
            environ={csr.CURSOR_CRED_ENV: "cur_" + "dummy_key_1234567890"},
            pr_number=6401,
            commit_sha="112233445566",
            dry_run=False,
            enable_cursor_sdk=True,
            sdk_invoker=mock_sdk,
        )
        self.assertEqual(report["audit_log"]["sdk_status"], "cursor_sdk_executed")
        self.assertGreaterEqual(report["audit_log"]["diff_redactions"], 1)
        self.assertEqual(len(captured), 1)
        self.assertNotIn("cursor_secret_material_987654", captured[0])
        self.assertEqual(report["audit_log"]["finding_count"], 1)
        self.assertEqual(report["findings"][0]["rule_id"], "cursor-auth-guard")

    def test_ci_failure_triage_builds_human_gated_draft_autofix_proposal(self) -> None:
        ci_log = "\n".join(
            [
                "error - The getter 'brokenValue' isn't defined - lib/pages/settings.dart:88:12 - undefined_getter",
                "FAILED_JOB: Static checks and web",
                "Authorization: " + "Bearer " + "ci_log_leak_should_redact_1234",
            ]
        )
        report = csr.run_security_review_pipeline(
            diff_text="",
            changed_paths=[],
            policy=self.policy,
            environ={},
            workflow_run_id="987654321",
            ci_log_text=ci_log,
            dry_run=True,
        )
        proposal = report["autofix_proposal"]
        self.assertIsNotNone(proposal)
        self.assertTrue(proposal["branch_name"].startswith("autofix/cursor-ci-987654321-"))
        self.assertTrue(proposal["draft"])
        self.assertFalse(proposal["auto_merge_allowed"])
        self.assertTrue(proposal["human_approval_required"])
        self.assertIn("lib/pages/settings.dart", proposal["affected_paths"])
        self.assertIn("dart_analyzer_or_cfe_error", proposal["root_cause_categories"])
        self.assertNotIn("ci_log_leak_should_redact_1234", json.dumps(report))

    def test_ssrf_guard_blocks_unlisted_cursor_hosts_and_http(self) -> None:
        with self.assertRaises(ValueError):
            csr.call_cursor_sdk_pinned_https(
                "http://api.cursor.com/v0/agents/review",
                "dummy",
                "diff",
                allowed_hosts=("api.cursor.com",),
            )
        with self.assertRaises(ValueError):
            csr.call_cursor_sdk_pinned_https(
                "https://evil.example.com/v0/agents/review",
                "dummy",
                "diff",
                allowed_hosts=("api.cursor.com",),
            )

    def test_workflow_security_and_isolation_contract(self) -> None:
        wf_text = (ROOT / ".github/workflows/cursor-security-review.yml").read_text(encoding="utf-8")
        self.assertIn("permissions: {}", wf_text)
        self.assertIn("if: github.event_name != 'pull_request'", wf_text)
        self.assertIn("workflow_run:", wf_text)
        self.assertNotIn("secrets.ANTHROPIC_API_KEY", wf_text)
        self.assertNotIn("secrets.SUPABASE_SERVICE_ROLE_KEY", wf_text)
        self.assertNotIn("deploy-prod.yml", wf_text)


if __name__ == "__main__":
    unittest.main()
