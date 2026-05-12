#!/usr/bin/env python3
"""Unit tests for dormant_instance_grace.py."""

from __future__ import annotations

import unittest
from datetime import datetime, timezone

import dormant_instance_grace as grace


NOW = datetime(2026, 5, 8, tzinfo=timezone.utc)


def issue(
    *,
    number: int = 1962,
    created_at: str = "2026-04-18T00:00:00Z",
    labels: list[str] | None = None,
    comments: list[str] | None = None,
) -> dict:
    return {
        "number": number,
        "title": "Dormant issue",
        "url": f"https://github.com/kanta13jp1/my_web_app/issues/{number}",
        "createdAt": created_at,
        "labels": [{"name": label} for label in (labels or ["vscode-instance"])],
        "comments": [{"body": body} for body in (comments or [])],
    }


class DormantInstanceGraceTest(unittest.TestCase):
    def test_warns_after_threshold(self) -> None:
        decision = grace.decide_issue(issue(), "vscode-instance", NOW, 14, 30)
        self.assertEqual(decision.action, "warn")

    def test_noops_when_grace_comment_exists(self) -> None:
        decision = grace.decide_issue(
            issue(comments=[f"{grace.GRACE_MARKER}\n## Dormant Instance Grace Status"]),
            "vscode-instance",
            NOW,
            14,
            30,
        )
        self.assertEqual(decision.action, "noop")
        self.assertIn("already", decision.reason)

    def test_closes_after_grace_window(self) -> None:
        decision = grace.decide_issue(
            issue(created_at="2026-04-01T00:00:00Z"),
            "vscode-instance",
            NOW,
            14,
            30,
        )
        self.assertEqual(decision.action, "close")

    def test_skips_workflow_failure_label(self) -> None:
        decision = grace.decide_issue(
            issue(labels=["vscode-instance", "workflow-failure"], created_at="2026-04-01T00:00:00Z"),
            "vscode-instance",
            NOW,
            14,
            30,
        )
        self.assertEqual(decision.action, "skip")
        self.assertIn("workflow-failure", decision.reason)

    def test_skips_recurrence_comment(self) -> None:
        decision = grace.decide_issue(
            issue(created_at="2026-04-01T00:00:00Z", comments=["This still happens again today."]),
            "vscode-instance",
            NOW,
            14,
            30,
        )
        self.assertEqual(decision.action, "skip")
        self.assertIn("recurrence", decision.reason)

    def test_status_comment_is_not_recurrence(self) -> None:
        self.assertFalse(
            grace.is_recurrence_comment(
                {
                    "body": (
                        f"{grace.GRACE_MARKER}\n"
                        "If this recurs, relabel to codex-instance."
                    )
                }
            )
        )

    def test_no_recurrence_phrase_is_not_recurrence(self) -> None:
        self.assertFalse(grace.is_recurrence_comment({"body": "再現なし / no recurrence"}))


if __name__ == "__main__":
    unittest.main()
