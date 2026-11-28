#!/usr/bin/env python3
"""Tests for scripts/content_draft_review_staging.py and staging workflow."""

from __future__ import annotations

import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts import content_draft_review_staging as staging_mod  # noqa: E402


class ContentDraftReviewStagingTests(unittest.TestCase):
    def test_aggregates_daily_kpi_metrics_and_sanitizes_untrusted_text(self) -> None:
        fake_ghp = "ghp_" + "1234567890abcdef"
        fake_sk = "sk-" + "proj-" + "abcdef1234567890"
        payload = {
            "report_date": "2026-11-25",
            "digest": {
                "users": {"total": 64},
                "paid": {"total": 3},
                "revenue": {"mrrYen": 2940},
                "featureRequests": {
                    "newToday": 2,
                    "openCount": 14,
                    "topOpen": [
                        {
                            "title": f"Support export with {fake_ghp} and {fake_sk} user@example.com",
                            "votes": 4,
                        }
                    ],
                },
                "recentAchievements": [
                    {"title": "Shipped deterministic workflow audit (#2685)"},
                ],
            },
        }
        kpi = staging_mod.parse_daily_kpi_metrics(payload)
        self.assertEqual(kpi.report_date, "2026-11-25")
        self.assertEqual(kpi.users_total, 64)
        self.assertEqual(kpi.paid_total, 3)
        self.assertEqual(kpi.mrr_yen, 2940)
        self.assertEqual(kpi.new_requests_today, 2)
        self.assertEqual(kpi.open_requests_count, 14)
        self.assertGreaterEqual(kpi.redaction_count, 3)
        joined = " ".join(kpi.top_open_requests)
        self.assertNotIn(fake_ghp, joined)
        self.assertNotIn(fake_sk, joined)
        self.assertNotIn("user@example.com", joined)

    def test_builds_weekly_sns_and_blog_drafts_with_published_false(self) -> None:
        kpi = staging_mod.parse_daily_kpi_metrics(
            {
                "report_date": "2026-11-25",
                "digest": {
                    "users": {"total": 61},
                    "paid": {"total": 2},
                    "revenue": {"mrrYen": 1960},
                    "featureRequests": {"newToday": 0, "openCount": 151, "topOpen": []},
                    "recentAchievements": [{"title": "Added LLM dynamic router"}],
                },
            }
        )
        bundle = staging_mod.build_draft_bundle(
            kpi,
            ["Added dynamic LLM cost routing", "Added human-review staging gate"],
        )
        self.assertIn("published: false", bundle.blog_draft_ja_md)
        self.assertIn("published: false", bundle.blog_draft_en_md)
        self.assertNotIn("published: true", bundle.blog_draft_ja_md)
        self.assertNotIn("published: true", bundle.blog_draft_en_md)
        self.assertIn("登録ユーザー 61 人", bundle.weekly_sns_md)
        self.assertEqual(len(bundle.draft_sha256), 64)

    def test_human_review_staging_and_fail_closed_publish_gate(self) -> None:
        kpi = staging_mod.parse_daily_kpi_metrics(
            {"report_date": "2026-11-25", "digest": {"users": {"total": 10}}}
        )
        bundle = staging_mod.build_draft_bundle(kpi, ["Shipped staging guardrails"])
        record = staging_mod.stage_for_human_review(bundle)

        self.assertEqual(record.review_status, "pending_human_approval")
        self.assertFalse(record.auto_publish_allowed)
        self.assertIn("pending-human-approval", record.issue_labels)
        self.assertIn(record.draft_sha256, record.issue_body)

        self.assertFalse(staging_mod.evaluate_publish_gate(record, None).allowed)
        self.assertEqual(
            staging_mod.evaluate_publish_gate(
                record,
                {
                    "status": "approved",
                    "reviewer": "github-actions[bot]",
                    "approved_at": "2026-11-25T09:00:00Z",
                    "draft_sha256": record.draft_sha256,
                },
            ).reason,
            "bot_approver_rejected",
        )
        self.assertEqual(
            staging_mod.evaluate_publish_gate(
                record,
                {
                    "status": "approved",
                    "reviewer": "kanta13jp1",
                    "approved_at": "2026-11-25T09:00:00Z",
                    "draft_sha256": "0" * 64,
                },
            ).reason,
            "draft_sha256_mismatch",
        )
        ok = staging_mod.evaluate_publish_gate(
            record,
            {
                "status": "approved",
                "reviewer": "kanta13jp1",
                "approved_at": "2026-11-25T09:00:00Z",
                "draft_sha256": record.draft_sha256,
            },
        )
        self.assertTrue(ok.allowed)

    def test_audits_existing_content_pipeline_contracts(self) -> None:
        self.assertEqual(staging_mod.audit_content_pipeline_contracts(ROOT), [])

    def test_cli_dry_run_outputs_and_self_test(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            json_out = root / "report.json"
            md_out = root / "report.md"
            issue_out = root / "issue.json"
            gh_out = root / "gh_output.txt"
            commits_json = root / "commits.json"
            commits_json.write_text(
                json.dumps(["feat(ci): add content human-review staging"]),
                encoding="utf-8",
            )

            rc = staging_mod.main(
                [
                    "--repo-root",
                    str(ROOT),
                    "--metrics-json",
                    str(ROOT / "docs" / "metrics" / "daily-metrics.json"),
                    "--commits-json",
                    str(commits_json),
                    "--audit-contracts",
                    "--dry-run",
                    "--json-out",
                    str(json_out),
                    "--markdown-out",
                    str(md_out),
                    "--issue-payload-out",
                    str(issue_out),
                    "--github-output",
                    str(gh_out),
                ]
            )
            self.assertEqual(rc, 0)
            parsed = json.loads(json_out.read_text(encoding="utf-8"))
            self.assertEqual(parsed["staging"]["review_status"], "pending_human_approval")
            self.assertFalse(parsed["publish_gate"]["allowed"])
            issue_payload = json.loads(issue_out.read_text(encoding="utf-8"))
            self.assertEqual(issue_payload["review_status"], "pending_human_approval")
            self.assertIn("auto_publish_allowed=false", gh_out.read_text(encoding="utf-8"))

        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(staging_mod.main(["--self-test"]), 0)

    def test_workflow_contract_security_and_no_paid_secrets(self) -> None:
        wf = ROOT / ".github" / "workflows" / "content-draft-review-staging.yml"
        self.assertTrue(wf.is_file())
        content = wf.read_text(encoding="utf-8")
        self.assertIn("permissions: {}", content)
        self.assertIn("contents: read", content)
        self.assertIn("issues: read", content)
        for forbidden in (
            "SUPABASE_SERVICE_ROLE_KEY",
            "ANTHROPIC_API_KEY",
            "OPENAI_API_KEY",
            "CLAUDE_CODE_OAUTH_TOKEN",
        ):
            self.assertNotIn(forbidden, content)


if __name__ == "__main__":
    unittest.main()
