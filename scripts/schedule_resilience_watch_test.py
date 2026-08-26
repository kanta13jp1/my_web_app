#!/usr/bin/env python3
"""Tests for schedule_resilience_watch.py."""

from __future__ import annotations

import unittest
from datetime import datetime, timedelta, timezone

from schedule_resilience_watch import (
    GitHubClient,
    TARGETS,
    WorkflowTarget,
    evaluate_target,
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

    def test_workflow_runs_filters_by_requested_event(self) -> None:
        class RecordingClient(GitHubClient):
            requested_path = ""

            def request(self, method, path, body=None):
                self.requested_path = path
                return {"workflow_runs": [{"id": 7}]}

        client = RecordingClient("owner/repo", "token")
        runs = client.workflow_runs("deploy-prod.yml", event="push", limit=5)

        self.assertEqual(runs, [{"id": 7}])
        self.assertIn("event=push", client.requested_path)
        self.assertIn("per_page=5", client.requested_path)

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
