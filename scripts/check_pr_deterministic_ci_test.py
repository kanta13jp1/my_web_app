#!/usr/bin/env python3
from __future__ import annotations

import urllib.error
import urllib.request
import unittest
from unittest import mock

from check_pr_deterministic_ci import (
    ci_required_for_changes,
    evaluate_check_runs,
    fetch_github_json,
    latest_check_runs_by_name,
    render_markdown,
)


def run(
    name: str,
    status: str,
    conclusion: str | None,
    *,
    run_id: int = 1,
    started_at: str = "2026-06-08T00:00:00Z",
) -> dict[str, object]:
    return {
        "id": run_id,
        "name": name,
        "status": status,
        "conclusion": conclusion,
        "started_at": started_at,
        "details_url": f"https://example.test/{run_id}",
    }


class FakeResponse:
    def __init__(self, payload: bytes, link: str = "") -> None:
        self._payload = payload
        self.headers = {"Link": link}

    def __enter__(self) -> "FakeResponse":
        return self

    def __exit__(self, *args: object) -> None:
        return None

    def read(self) -> bytes:
        return self._payload


class DeterministicCiGateTest(unittest.TestCase):
    def test_docs_only_changes_do_not_require_ci(self) -> None:
        self.assertFalse(
            ci_required_for_changes(
                ["docs/adr/example.md", ".github/ISSUE_TEMPLATE/feature.yml"]
            )
        )

    def test_mixed_changes_require_ci(self) -> None:
        self.assertTrue(ci_required_for_changes(["docs/adr/example.md", "lib/main.dart"]))

    def test_evaluate_success_when_all_required_checks_pass(self) -> None:
        evaluation = evaluate_check_runs(
            [
                run("Lint, Format, and Test", "completed", "success"),
                run("Security Check", "completed", "success"),
            ],
            ["Lint, Format, and Test", "Security Check"],
        )

        self.assertEqual(evaluation.state, "success")
        self.assertEqual(len(evaluation.passed), 2)

    def test_evaluate_pending_when_check_is_missing_or_running(self) -> None:
        evaluation = evaluate_check_runs(
            [run("Lint, Format, and Test", "in_progress", None)],
            ["Lint, Format, and Test", "Security Check"],
        )

        self.assertEqual(evaluation.state, "pending")
        self.assertEqual([item.name for item in evaluation.pending], ["Lint, Format, and Test"])
        self.assertEqual(evaluation.missing, ("Security Check",))

    def test_evaluate_failure_when_required_check_fails(self) -> None:
        evaluation = evaluate_check_runs(
            [
                run("Lint, Format, and Test", "completed", "failure"),
                run("Security Check", "completed", "success"),
            ],
            ["Lint, Format, and Test", "Security Check"],
        )

        self.assertEqual(evaluation.state, "failure")
        self.assertEqual([item.name for item in evaluation.failed], ["Lint, Format, and Test"])

    def test_latest_check_run_wins_by_started_at_and_id(self) -> None:
        latest = latest_check_runs_by_name(
            [
                run("Lint, Format, and Test", "completed", "failure", run_id=1),
                run(
                    "Lint, Format, and Test",
                    "completed",
                    "success",
                    run_id=2,
                    started_at="2026-06-08T00:01:00Z",
                ),
            ]
        )

        self.assertEqual(latest["Lint, Format, and Test"]["conclusion"], "success")

    def test_summary_includes_required_checks_and_contract(self) -> None:
        evaluation = evaluate_check_runs(
            [run("Security Check", "completed", "success")],
            ["Security Check"],
        )

        rendered = render_markdown(
            state="success",
            repo="owner/repo",
            sha="abc123",
            evaluation=evaluation,
            required_checks=["Security Check"],
        )

        self.assertIn("Deterministic Validation Summary", rendered)
        self.assertIn("`Security Check`", rendered)
        self.assertIn("flutter analyze", rendered)

    def test_fetch_github_json_retries_transient_server_error(self) -> None:
        request = urllib.request.Request("https://example.test")
        server_error = urllib.error.HTTPError(
            request.full_url,
            503,
            "Service Unavailable",
            {},
            None,
        )

        with (
            mock.patch(
                "check_pr_deterministic_ci.urllib.request.urlopen",
                side_effect=[
                    server_error,
                    FakeResponse(
                        b'{"check_runs": []}',
                        '<https://example.test/2>; rel="next"',
                    ),
                ],
            ) as urlopen,
            mock.patch("check_pr_deterministic_ci.time.sleep") as sleep,
        ):
            payload, link_header = fetch_github_json(request)

        self.assertEqual(payload, {"check_runs": []})
        self.assertEqual(link_header, '<https://example.test/2>; rel="next"')
        self.assertEqual(urlopen.call_count, 2)
        sleep.assert_called_once()


if __name__ == "__main__":
    unittest.main()
