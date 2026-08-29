#!/usr/bin/env python3
"""Tests for schedule_resilience_watch.py."""

from __future__ import annotations

import io
import os
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import patch

from schedule_resilience_watch import (
    GitHubClient,
    TARGETS,
    WorkflowTarget,
    evaluate_target,
    is_schedule_watch_issue,
    issue_body,
    main,
    merge_revalidated_runs,
    repository_revalidation_start,
    render_summary,
)


NOW = datetime(2026, 5, 8, 3, 0, tzinfo=timezone.utc)
TARGET = WorkflowTarget("cs-check", "cs-check.yml", 3)


def run(**overrides):
    data = {
        "id": 123,
        "html_url": "https://github.example/runs/123",
        "status": "completed",
        "conclusion": "success",
        "run_attempt": 1,
        "created_at": (NOW - timedelta(hours=1)).isoformat().replace("+00:00", "Z"),
    }
    data.update(overrides)
    return data


class ScheduleResilienceWatchTest(unittest.TestCase):
    def test_success_recent_is_healthy(self) -> None:
        result = evaluate_target(TARGET, [run()], NOW, max_attempts=2)
        self.assertEqual(result["action"], "healthy")
        self.assertEqual(result["reason"], "latest-success")

    def test_failed_first_attempt_requests_retry(self) -> None:
        result = evaluate_target(
            TARGET,
            [run(conclusion="failure", run_attempt=1)],
            NOW,
            max_attempts=2,
        )
        self.assertEqual(result["action"], "retry")
        self.assertEqual(result["reason"], "failed-attempt-1")

    def test_failed_max_attempt_alerts(self) -> None:
        result = evaluate_target(
            TARGET,
            [run(conclusion="failure", run_attempt=2)],
            NOW,
            max_attempts=2,
        )
        self.assertEqual(result["action"], "alert")
        self.assertEqual(result["reason"], "retry-exhausted")
        self.assertIn("[Schedule監視] cs-check failure", result["title"])

    def test_stale_success_alerts(self) -> None:
        result = evaluate_target(
            TARGET,
            [run(created_at=(NOW - timedelta(hours=5)).isoformat().replace("+00:00", "Z"))],
            NOW,
            max_attempts=2,
        )
        self.assertEqual(result["action"], "alert")
        self.assertEqual(result["reason"], "stale-success")

    def test_evaluation_sorts_runs_newest_instead_of_trusting_api_order(self) -> None:
        older = run(
            id=1,
            created_at=(NOW - timedelta(hours=5)).isoformat().replace("+00:00", "Z"),
        )
        newer = run(
            id=2,
            created_at=(NOW - timedelta(hours=1)).isoformat().replace("+00:00", "Z"),
        )

        result = evaluate_target(TARGET, [older, newer], NOW, max_attempts=2)

        self.assertEqual(result["action"], "healthy")
        self.assertEqual(result["run_id"], 2)

    def test_deploy_success_does_not_alert_only_because_it_is_old(self) -> None:
        deploy = WorkflowTarget("deploy-prod", "deploy-prod.yml", 0, "push")
        result = evaluate_target(
            deploy,
            [run(created_at=(NOW - timedelta(days=30)).isoformat().replace("+00:00", "Z"))],
            NOW,
            max_attempts=2,
        )
        self.assertEqual(result["action"], "healthy")
        self.assertEqual(result["reason"], "latest-success")

    def test_notion_and_deploy_workflows_are_monitored(self) -> None:
        targets = {target.key: target for target in TARGETS}
        self.assertEqual(targets["notion-sync"].event, "schedule")
        self.assertEqual(targets["deploy-prod"].event, "push")

    def test_health_monitor_requires_two_missed_delivery_opportunities(self) -> None:
        targets = {target.key: target for target in TARGETS}
        health_monitor = targets["health-monitor"]

        self.assertEqual(health_monitor.max_age_hours, 6)
        delayed = evaluate_target(
            health_monitor,
            [
                run(
                    created_at=(NOW - timedelta(hours=3, minutes=36))
                    .isoformat()
                    .replace("+00:00", "Z")
                )
            ],
            NOW,
            max_attempts=2,
        )
        stalled = evaluate_target(
            health_monitor,
            [
                run(
                    created_at=(NOW - timedelta(hours=6, minutes=1))
                    .isoformat()
                    .replace("+00:00", "Z")
                )
            ],
            NOW,
            max_attempts=2,
        )

        self.assertEqual(delayed["action"], "healthy")
        self.assertEqual(stalled["action"], "alert")
        self.assertEqual(stalled["reason"], "stale-success")

    def test_health_monitor_avoids_top_of_hour_congestion(self) -> None:
        workflow = (
            Path(__file__).resolve().parents[1] / ".github/workflows/health-monitor.yml"
        ).read_text(encoding="utf-8")

        self.assertIn('cron: "3 */2 * * *"', workflow)
        self.assertNotIn('cron: "0 */2 * * *"', workflow)

    def test_workflow_runs_filters_by_requested_event(self) -> None:
        class RecordingClient(GitHubClient):
            requested_path = ""

            def request(self, method, path, body=None):
                self.requested_path = path
                return {"workflow_runs": [run(id=7)]}

        client = RecordingClient("owner/repo", "token")
        runs = client.workflow_runs("deploy-prod.yml", event="push", limit=5)

        self.assertEqual([item["id"] for item in runs], [7])
        self.assertIn("event=push", client.requested_path)
        self.assertIn("per_page=5", client.requested_path)
        self.assertNotIn("cache_bust", client.requested_path)

    @patch("schedule_resilience_watch.urlopen")
    def test_get_requests_force_revalidation_but_post_requests_do_not(self, mocked_urlopen) -> None:
        class FakeResponse:
            def __enter__(self):
                return self

            def __exit__(self, *_args):
                return False

            def read(self):
                return b"{}"

        mocked_urlopen.return_value = FakeResponse()
        client = GitHubClient("owner/repo", "token")

        client.request("GET", "/repos/owner/repo/actions/runs")
        get_request = mocked_urlopen.call_args.args[0]
        self.assertEqual(get_request.get_header("Cache-control"), "no-cache")
        self.assertEqual(get_request.get_header("Pragma"), "no-cache")
        self.assertEqual(
            get_request.get_header("User-agent"),
            "my-web-app-schedule-resilience-watch",
        )

        client.request("POST", "/repos/owner/repo/issues", {"title": "test"})
        post_request = mocked_urlopen.call_args.args[0]
        self.assertIsNone(post_request.get_header("Cache-control"))

    def test_repository_fallback_filters_exact_workflow_path(self) -> None:
        class RepositoryClient(GitHubClient):
            def request(self, method, path, body=None):
                self.requested_path = path
                return {
                    "workflow_runs": [
                        {**run(id=9), "path": ".github/workflows/cs-check.yml@main"},
                        {**run(id=10), "path": ".github/workflows/cs-check.yml.bak"},
                    ]
                }

        client = RepositoryClient("owner/repo", "token")
        runs = client.repository_workflow_runs(
            "cs-check.yml",
            event="schedule",
            created_after=NOW - timedelta(hours=3),
        )

        self.assertEqual([item["id"] for item in runs], [9])
        self.assertIn("created=%3E%3D", client.requested_path)
        self.assertIn("event=schedule", client.requested_path)

    def test_repository_fallback_can_replace_a_stale_primary_run(self) -> None:
        stale = run(
            id=1,
            created_at=(NOW - timedelta(hours=5)).isoformat().replace("+00:00", "Z"),
        )
        fresh = run(
            id=2,
            created_at=(NOW - timedelta(hours=1)).isoformat().replace("+00:00", "Z"),
        )

        created_after = repository_revalidation_start(TARGET, [stale], NOW)
        runs = merge_revalidated_runs([stale], [fresh, stale], created_after=created_after)
        result = evaluate_target(TARGET, runs, NOW, max_attempts=2)

        self.assertEqual(result["action"], "healthy")
        self.assertEqual(result["run_id"], 2)

    def test_stale_failure_is_not_retried_when_fresh_window_is_empty(self) -> None:
        stale_failure = run(
            id=1,
            conclusion="failure",
            created_at=(NOW - timedelta(hours=5)).isoformat().replace("+00:00", "Z"),
        )
        created_after = repository_revalidation_start(TARGET, [stale_failure], NOW)
        runs = merge_revalidated_runs(
            [stale_failure],
            [stale_failure],
            created_after=created_after,
        )

        result = evaluate_target(TARGET, runs, NOW, max_attempts=2)

        self.assertEqual(result["action"], "alert")
        self.assertEqual(result["reason"], "stale-failure")

    def test_stale_success_is_not_misreported_as_missing(self) -> None:
        stale_success = run(
            id=2,
            created_at=(NOW - timedelta(hours=5)).isoformat().replace("+00:00", "Z"),
        )
        created_after = repository_revalidation_start(TARGET, [stale_success], NOW)
        runs = merge_revalidated_runs(
            [stale_success],
            [stale_success],
            created_after=created_after,
        )

        result = evaluate_target(TARGET, runs, NOW, max_attempts=2)

        self.assertEqual(result["action"], "alert")
        self.assertEqual(result["reason"], "stale-success")

    def test_repository_fallback_without_primary_uses_a_full_day(self) -> None:
        created_after = repository_revalidation_start(TARGET, [], NOW)

        self.assertEqual(created_after, NOW - timedelta(hours=24))

    def test_fresh_primary_must_be_confirmed_by_repository_listing(self) -> None:
        fresh = run(id=7)
        created_after = repository_revalidation_start(TARGET, [fresh], NOW)

        with self.assertRaisesRegex(RuntimeError, "did not confirm"):
            merge_revalidated_runs([fresh], [], created_after=created_after)

    def test_event_driven_primary_must_also_be_confirmed(self) -> None:
        deploy = WorkflowTarget("deploy-prod", "deploy-prod.yml", 0, "push")
        fresh = run(id=8)
        created_after = repository_revalidation_start(deploy, [fresh], NOW)

        with self.assertRaisesRegex(RuntimeError, "did not confirm"):
            merge_revalidated_runs([fresh], [], created_after=created_after)

    def test_bootstrap_success_graces_only_the_first_scheduled_run(self) -> None:
        introduced_at = NOW - timedelta(hours=2)
        backup = WorkflowTarget(
            "backup",
            "backup.yml",
            192,
            introduced_at=introduced_at,
            require_bootstrap_success=True,
        )
        result = evaluate_target(
            backup,
            [],
            NOW,
            max_attempts=2,
            fallback_runs=[
                run(
                    event="workflow_dispatch",
                    created_at=(NOW - timedelta(hours=1)).isoformat().replace("+00:00", "Z"),
                )
            ],
        )

        self.assertEqual(result["action"], "observe")
        self.assertEqual(result["reason"], "awaiting-first-scheduled-run")
        self.assertEqual(result["workflow_file"], "backup.yml")

    def test_bootstrap_success_cannot_extend_the_fixed_grace_deadline(self) -> None:
        backup = WorkflowTarget(
            "backup",
            "backup.yml",
            192,
            introduced_at=NOW - timedelta(hours=193),
            require_bootstrap_success=True,
        )
        result = evaluate_target(
            backup,
            [],
            NOW,
            max_attempts=2,
            fallback_runs=[
                run(
                    event="workflow_dispatch",
                    created_at=(NOW - timedelta(minutes=5)).isoformat().replace("+00:00", "Z"),
                )
            ],
        )

        self.assertEqual(result["action"], "alert")
        self.assertEqual(result["reason"], "missing-run")

    def test_bootstrap_grace_rejects_failure_and_disabled_workflow(self) -> None:
        backup = WorkflowTarget(
            "backup",
            "backup.yml",
            192,
            introduced_at=NOW - timedelta(hours=2),
            require_bootstrap_success=True,
        )
        failed = evaluate_target(
            backup,
            [],
            NOW,
            max_attempts=2,
            fallback_runs=[run(event="workflow_dispatch", conclusion="failure")],
        )
        disabled = evaluate_target(
            backup,
            [],
            NOW,
            max_attempts=2,
            fallback_runs=[run(event="workflow_dispatch")],
            workflow_state="disabled_manually",
        )

        self.assertEqual(failed["reason"], "missing-run")
        self.assertEqual(disabled["reason"], "workflow-disabled")

    def test_backup_requires_success_instead_of_skipped_or_neutral(self) -> None:
        backup = WorkflowTarget(
            "backup",
            "backup.yml",
            192,
            require_bootstrap_success=True,
        )

        for conclusion in ("skipped", "neutral"):
            with self.subTest(conclusion=conclusion):
                result = evaluate_target(
                    backup,
                    [run(conclusion=conclusion)],
                    NOW,
                    max_attempts=2,
                )
                self.assertEqual(result["action"], "alert")
                self.assertEqual(
                    result["reason"],
                    f"unexpected-conclusion-{conclusion}",
                )

    def test_old_in_progress_run_alerts_as_stuck(self) -> None:
        result = evaluate_target(
            TARGET,
            [
                run(
                    status="in_progress",
                    conclusion=None,
                    created_at=(NOW - timedelta(hours=4)).isoformat().replace("+00:00", "Z"),
                )
            ],
            NOW,
            max_attempts=2,
        )

        self.assertEqual(result["action"], "alert")
        self.assertEqual(result["reason"], "stuck-run-in_progress")

    def test_recovery_closes_only_matching_monitor_issues(self) -> None:
        class RecordingClient(GitHubClient):
            writes: list[tuple[str, str, dict | None]] = []

            def request(self, method, path, body=None):
                if method == "GET":
                    if "/comments?" in path:
                        return []
                    return [
                        {
                            "number": 10,
                            "title": "[Schedule監視] cs-check stale schedule",
                            "html_url": "https://github.example/issues/10",
                            "user": {"login": "github-actions[bot]"},
                            "labels": [
                                {"name": "workflow-failure"},
                                {"name": "automation"},
                            ],
                            "body": (
                                "Schedule resilience watch detected a problem.\n\n"
                                "- Target: `cs-check`\n"
                                "- Workflow file: `cs-check.yml`\n"
                            ),
                        },
                        {
                            "number": 11,
                            "title": "[Schedule監視] daily-report stale schedule",
                            "html_url": "https://github.example/issues/11",
                            "user": {"login": "github-actions[bot]"},
                            "labels": [
                                {"name": "workflow-failure"},
                                {"name": "automation"},
                            ],
                            "body": (
                                "Schedule resilience watch detected a problem.\n\n"
                                "- Target: `daily-report`\n"
                                "- Workflow file: `daily-report.yml`\n"
                            ),
                        },
                        {
                            "number": 12,
                            "title": "[Schedule監視] cs-check stale schedule",
                            "pull_request": {},
                        },
                        {
                            "number": 13,
                            "title": "[Schedule監視] cs-check stale schedule",
                            "user": {"login": "github-actions[bot]"},
                            "labels": [{"name": "bug"}, {"name": "security"}],
                            "body": (
                                "Schedule resilience watch detected a problem.\n\n"
                                "- Target: `cs-check`\n"
                                "- Workflow file: `cs-check.yml`\n"
                            ),
                        },
                    ]
                self.writes.append((method, path, body))
                return {}

        client = RecordingClient("owner/repo", "token")
        closed = client.close_recovered_issues(
            TARGET,
            {"reason": "latest-success", "url": "https://github.example/runs/1"},
            NOW,
        )

        self.assertEqual(closed, ["https://github.example/issues/10"])
        self.assertEqual([method for method, _, _ in client.writes], ["POST", "PATCH"])
        self.assertEqual(client.writes[1][1], "/repos/owner/repo/issues/10")
        self.assertEqual(
            client.writes[1][2],
            {"state": "closed", "state_reason": "completed"},
        )

    def test_recovery_comment_is_idempotent_after_partial_failure(self) -> None:
        class RecordingClient(GitHubClient):
            writes: list[tuple[str, str, dict | None]] = []

            def request(self, method, path, body=None):
                if method == "GET" and "/comments?" in path:
                    return [{"body": "<!-- schedule_resilience_recovery: cs-check -->"}]
                if method == "GET":
                    return [
                        {
                            "number": 10,
                            "title": "[Schedule監視] cs-check stale schedule",
                            "html_url": "https://github.example/issues/10",
                            "user": {"login": "github-actions[bot]"},
                            "labels": [
                                {"name": "workflow-failure"},
                                {"name": "automation"},
                            ],
                            "body": (
                                "Schedule resilience watch detected a problem.\n\n"
                                "- Target: `cs-check`\n"
                                "- Workflow file: `cs-check.yml`\n"
                            ),
                        }
                    ]
                self.writes.append((method, path, body))
                return {}

        client = RecordingClient("owner/repo", "token")
        client.close_recovered_issues(
            TARGET,
            {"reason": "latest-success", "url": "https://github.example/runs/1"},
            NOW,
        )

        self.assertEqual([method for method, _, _ in client.writes], ["PATCH"])

    def test_legacy_issue_with_blank_workflow_is_not_auto_closed(self) -> None:
        issue = {
            "number": 4886,
            "title": "[Schedule監視] supabase-backup-restore missing run",
            "user": {"login": "github-actions[bot]"},
            "labels": [
                {"name": "workflow-failure"},
                {"name": "automation"},
            ],
            "body": (
                "Schedule resilience watch detected a problem.\n\n"
                "- Target: `supabase-backup-restore`\n"
                "- Workflow file: ``\n"
            ),
        }
        backup = next(target for target in TARGETS if target.key == "supabase-backup-restore")

        self.assertFalse(is_schedule_watch_issue(issue, backup))

    def test_issue_body_adds_strict_target_markers(self) -> None:
        body = issue_body(
            {
                "target": "cs-check",
                "workflow_file": "cs-check.yml",
                "reason": "stale-success",
            },
            NOW,
        )

        self.assertIn("<!-- schedule_resilience_issue: v1 -->", body)
        self.assertIn("<!-- schedule_resilience_target: cs-check -->", body)
        self.assertIn("<!-- schedule_resilience_workflow: cs-check.yml -->", body)

    def test_main_fails_closed_without_repository_confirmation(self) -> None:
        class InconsistentClient:
            writes: list[str] = []

            def workflow_runs(self, *_args, **_kwargs):
                return [
                    run(
                        id=77,
                        created_at=(datetime.now(timezone.utc) - timedelta(hours=1))
                        .isoformat()
                        .replace("+00:00", "Z"),
                    )
                ]

            def repository_workflow_runs(self, *_args, **_kwargs):
                return []

            def rerun_failed_jobs(self, *_args, **_kwargs):
                self.writes.append("rerun")

            def open_or_update_issue(self, *_args, **_kwargs):
                self.writes.append("issue")

            def close_recovered_issues(self, *_args, **_kwargs):
                self.writes.append("close")

        client = InconsistentClient()
        with (
            patch.dict(os.environ, {"GITHUB_TOKEN": "test-token"}, clear=False),
            patch("schedule_resilience_watch.GitHubClient", return_value=client),
            patch("schedule_resilience_watch.TARGETS", (TARGET,)),
            patch("sys.stdout", new_callable=io.StringIO),
        ):
            exit_code = main(["--repo", "owner/repo"])

        self.assertEqual(exit_code, 1)
        self.assertEqual(client.writes, [])

    def test_main_uses_repository_fallback_when_primary_api_fails(self) -> None:
        class FallbackClient:
            writes: list[str] = []

            def workflow_runs(self, *_args, **_kwargs):
                raise RuntimeError("primary unavailable")

            def repository_workflow_runs(self, *_args, **_kwargs):
                return [
                    run(
                        id=88,
                        created_at=(datetime.now(timezone.utc) - timedelta(hours=1))
                        .isoformat()
                        .replace("+00:00", "Z"),
                    )
                ]

            def close_recovered_issues(self, *_args, **_kwargs):
                self.writes.append("close")
                return []

        client = FallbackClient()
        with (
            patch.dict(os.environ, {"GITHUB_TOKEN": "test-token"}, clear=False),
            patch("schedule_resilience_watch.GitHubClient", return_value=client),
            patch("schedule_resilience_watch.TARGETS", (TARGET,)),
            patch("sys.stdout", new_callable=io.StringIO),
        ):
            exit_code = main(["--repo", "owner/repo"])

        self.assertEqual(exit_code, 0)
        self.assertEqual(client.writes, ["close"])

    def test_summary_mentions_actions(self) -> None:
        summary = render_summary(
            [
                {"target": "cs-check", "action": "retry", "reason": "failed-attempt-1", "url": ""},
                {"target": "daily-report", "action": "healthy", "reason": "latest-success", "url": "u"},
            ]
        )
        self.assertIn("Schedule Resilience Watch", summary)
        self.assertIn("failed-attempt-1", summary)
        self.assertIn("[run](u)", summary)


if __name__ == "__main__":
    unittest.main()
