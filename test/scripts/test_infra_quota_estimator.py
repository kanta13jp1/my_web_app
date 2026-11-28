#!/usr/bin/env python3
"""Offline unit tests for scripts/infra_quota_estimator.py (#2767)."""

from __future__ import annotations

from datetime import date
import json
from pathlib import Path
import sys
import tempfile
import unittest

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import infra_quota_estimator as mod  # noqa: E402

LIMITS = json.loads((REPO_ROOT / "docs" / "infra-quota-limits.json").read_text(encoding="utf-8"))
INITIAL_SNAPSHOT = json.loads((REPO_ROOT / "docs" / "infra-usage-snapshot.json").read_text(encoding="utf-8"))
TODAY = date(2026, 11, 10)


def snapshot(usage: dict[str, float | None], **overrides: object) -> dict[str, object]:
    base: dict[str, object] = {
        "collected_at": "2026-11-10",
        "period_start": "2026-11-01",
        "plans": {"supabase": "free", "firebase_hosting": "spark"},
        "services_in_use": ["supabase", "firebase_hosting"],
        "usage": usage,
    }
    base.update(overrides)
    return base


def rows_by_id(report: dict[str, object]) -> dict[str, dict[str, object]]:
    return {row["id"]: row for row in report["rows"]}  # type: ignore[index]


class FakeGitHub:
    def __init__(self, issues: list[dict[str, object]] | None = None) -> None:
        self.issues = issues or []
        self.calls: list[tuple[str, str, dict[str, object] | None]] = []

    def __call__(self, method: str, url: str, headers: dict[str, str], payload: dict[str, object] | None) -> object:
        self.calls.append((method, url, payload))
        if method == "GET":
            return self.issues
        return {}


class LimitsFileTest(unittest.TestCase):
    def test_every_dimension_has_a_known_source_plan_keys_and_sane_numbers(self) -> None:
        self.assertRegex(LIMITS["verified_on"], r"^\d{4}-\d{2}-\d{2}$")
        for dim in LIMITS["dimensions"]:
            self.assertIn(dim["source"], LIMITS["sources"], dim["id"])
            plans = LIMITS["plans"][dim["service"]]
            for key in list(dim["limits"]) + list(dim["overage_usd_per_unit"]):
                self.assertIn(key, plans, f"{dim['id']}:{key}")
            for value in list(dim["limits"].values()) + list(dim["overage_usd_per_unit"].values()):
                self.assertTrue(value is None or value >= 0, dim["id"])
            self.assertIn(dim["kind"], {"point", "month", "peak"})

    def test_initial_snapshot_covers_every_dimension_and_records_no_fake_numbers(self) -> None:
        ids = {d["id"] for d in LIMITS["dimensions"]}
        self.assertEqual(ids, set(INITIAL_SNAPSHOT["usage"]))
        self.assertTrue(all(v is None for v in INITIAL_SNAPSHOT["usage"].values()))
        self.assertIsNone(INITIAL_SNAPSHOT["collected_at"])


class EvaluateTest(unittest.TestCase):
    def test_initial_snapshot_is_never_reported_as_healthy(self) -> None:
        report = mod.evaluate(LIMITS, INITIAL_SNAPSHOT, today=TODAY)
        self.assertEqual(report["status"], "owner_action_required")
        self.assertTrue(report["owner_action_required"])
        self.assertTrue(report["snapshot"]["stale"])
        states = {row["state"] for row in report["rows"]}
        self.assertNotIn(mod.STATE_NORMAL, states)
        self.assertIn("supabase.egress_gb", report["unmeasured"])

    def test_threshold_states_on_free_plan_and_configurable_alert_threshold(self) -> None:
        usage = {"supabase.egress_gb": 4.0, "supabase.storage_gb": 0.7, "supabase.cached_egress_gb": 5.0}
        no_forecast = snapshot(usage, period_start=None)
        report = mod.evaluate(LIMITS, no_forecast, today=TODAY)
        rows = rows_by_id(report)
        self.assertEqual(rows["supabase.egress_gb"]["state"], mod.STATE_ACTION)
        self.assertTrue(rows["supabase.egress_gb"]["alert"])
        self.assertEqual(rows["supabase.storage_gb"]["state"], mod.STATE_WATCH)
        self.assertFalse(rows["supabase.storage_gb"]["alert"])
        self.assertEqual(rows["supabase.cached_egress_gb"]["state"], mod.STATE_EXCEEDED)

        strict = mod.evaluate(LIMITS, no_forecast, today=TODAY, alert_threshold_pct=90)
        self.assertEqual(rows_by_id(strict)["supabase.egress_gb"]["state"], mod.STATE_WATCH)
        self.assertFalse(rows_by_id(strict)["supabase.egress_gb"]["alert"])

    def test_forecast_alerts_before_the_current_value_reaches_the_threshold(self) -> None:
        report = mod.evaluate(LIMITS, snapshot({"supabase.egress_gb": 2.0}), today=TODAY)
        row = rows_by_id(report)["supabase.egress_gb"]
        self.assertEqual(row["state"], mod.STATE_NORMAL)
        self.assertEqual(row["projected"], 6.0)
        self.assertTrue(row["forecast_exceeds"])
        self.assertTrue(row["alert"])
        self.assertEqual(report["status"], "alert")

    def test_point_and_distinct_count_dimensions_are_not_linearly_projected(self) -> None:
        usage = {"supabase.storage_gb": 0.5, "supabase.mau": 30000}
        rows = rows_by_id(mod.evaluate(LIMITS, snapshot(usage), today=TODAY))
        self.assertIsNone(rows["supabase.storage_gb"]["projected"])
        self.assertIsNone(rows["supabase.mau"]["projected"])
        self.assertEqual(rows["supabase.mau"]["pct"], 60.0)

    def test_stale_snapshot_fails_closed(self) -> None:
        old = snapshot({"supabase.egress_gb": 0.1}, collected_at="2026-09-01", period_start="2026-09-01")
        report = mod.evaluate(LIMITS, old, today=TODAY)
        self.assertTrue(report["snapshot"]["stale"])
        self.assertEqual(rows_by_id(report)["supabase.egress_gb"]["state"], mod.STATE_UNMEASURED)
        self.assertEqual(report["status"], "owner_action_required")

    def test_unknown_plan_uses_conservative_default_and_unverified_limits_are_flagged(self) -> None:
        snap = snapshot({"supabase.egress_gb": 1.0, "supabase.disk_gb": 1.0}, plans={"supabase": "unknown"})
        report = mod.evaluate(LIMITS, snap, today=TODAY)
        self.assertEqual(report["plans"]["supabase"], {"plan": "free", "assumed": True})
        self.assertEqual(rows_by_id(report)["supabase.egress_gb"]["limit"], 5.0)
        self.assertEqual(rows_by_id(report)["supabase.disk_gb"]["state"], mod.STATE_LIMIT_UNVERIFIED)
        self.assertIn("supabase.disk_gb", report["limit_unverified"])

    def test_services_not_in_use_are_not_applicable(self) -> None:
        snap = snapshot({"supabase.egress_gb": 1.0}, services_in_use=["supabase"])
        rows = rows_by_id(mod.evaluate(LIMITS, snap, today=TODAY))
        self.assertEqual(rows["firebase_hosting.transfer_gb"]["state"], mod.STATE_NOT_APPLICABLE)

    def test_invalid_inputs_raise(self) -> None:
        with self.assertRaises(mod.InputError):
            mod.evaluate(LIMITS, snapshot({}, collected_at="not-a-date"), today=TODAY)
        with self.assertRaises(mod.InputError):
            mod.evaluate(LIMITS, snapshot({}), today=TODAY, alert_threshold_pct=0)
        with self.assertRaises(mod.InputError):
            mod.parse_scenarios("0,-5")


class ScenarioTest(unittest.TestCase):
    def test_paid_plan_cost_model_scales_with_growth_and_flags_incomplete_inputs(self) -> None:
        usage = {"supabase.egress_gb": 90.0}  # day 10 of 30 -> projected 270 GB
        report = mod.evaluate(LIMITS, snapshot(usage), today=TODAY, growth_scenarios=(0, 100))
        by_growth = {s["growth_pct"]: s for s in report["scenarios"]}
        self.assertAlmostEqual(by_growth[0]["estimated_monthly_usd"], 26.8, places=2)  # 25 + (270-250)*0.09
        self.assertAlmostEqual(by_growth[100]["estimated_monthly_usd"], 51.1, places=2)  # 25 + (540-250)*0.09
        self.assertFalse(by_growth[0]["complete"])
        self.assertEqual(by_growth[0]["per_service_usd"]["firebase_hosting"], 0.0)


class IssueUpsertTest(unittest.TestCase):
    def call(self, fake: FakeGitHub, **overrides: object) -> str:
        args: dict[str, object] = {
            "repository": "owner/repo",
            "auth_value": "t",
            "title": f"{mod.ALERT_TITLE_PREFIX} x",
            "title_prefix": mod.ALERT_TITLE_PREFIX,
            "body": "body",
            "signature": "abc",
            "http": fake,
        }
        args.update(overrides)
        return mod.upsert_issue(**args)  # type: ignore[arg-type]

    def test_creates_when_missing_and_skips_pull_requests(self) -> None:
        fake = FakeGitHub([{"number": 5, "title": f"{mod.ALERT_TITLE_PREFIX} pr", "pull_request": {}}])
        self.assertEqual(self.call(fake), "created")
        self.assertEqual([c[0] for c in fake.calls], ["GET", "POST"])

    def test_unchanged_when_signature_matches_and_updates_when_it_differs(self) -> None:
        existing = [{"number": 7, "title": f"{mod.ALERT_TITLE_PREFIX} old", "body": f"<!-- {mod.SIGNATURE_MARKER}:abc -->"}]
        same = FakeGitHub(existing)
        self.assertEqual(self.call(same), "unchanged")
        self.assertEqual([c[0] for c in same.calls], ["GET"])
        changed = FakeGitHub(existing)
        self.assertEqual(self.call(changed, signature="def"), "updated")
        self.assertEqual([c[0] for c in changed.calls], ["GET", "PATCH", "POST"])
        self.assertTrue(changed.calls[1][1].endswith("/issues/7"))

    def test_rejects_bad_repository_and_missing_token_and_foreign_urls(self) -> None:
        fake = FakeGitHub()
        with self.assertRaises(mod.InputError):
            self.call(fake, repository="../etc/passwd")
        with self.assertRaises(mod.InputError):
            self.call(fake, auth_value="")
        with self.assertRaises(mod.InputError):
            mod._http_json("GET", "https://example.com/x", {}, None)
        self.assertEqual(fake.calls, [])


class MainTest(unittest.TestCase):
    def run_main(self, snap: dict[str, object], extra: list[str], fake: FakeGitHub) -> tuple[int, Path, Path]:
        tmp = Path(tempfile.mkdtemp())
        snap_path = tmp / "snap.json"
        snap_path.write_text(json.dumps(snap), encoding="utf-8")
        out = tmp / "gh_output.txt"
        json_out = tmp / "report.json"
        argv = [
            "--limits", str(REPO_ROOT / "docs" / "infra-quota-limits.json"),
            "--snapshot", str(snap_path),
            "--today", "2026-11-10",
            "--github-output", str(out),
            "--json-out", str(json_out),
            *extra,
        ]
        return mod.main(argv, http=fake), out, json_out

    def test_alert_and_monthly_review_issues_are_opened_and_outputs_written(self) -> None:
        import os
        fake = FakeGitHub()
        os.environ["GITHUB_TOKEN"] = "token"
        os.environ["GITHUB_REPOSITORY"] = "owner/repo"
        try:
            code, out, json_out = self.run_main(
                snapshot({"supabase.egress_gb": 4.5}), ["--create-issue", "--monthly-review"], fake
            )
        finally:
            os.environ.pop("GITHUB_TOKEN", None)
            os.environ.pop("GITHUB_REPOSITORY", None)
        self.assertEqual(code, 0)
        text = out.read_text(encoding="utf-8")
        self.assertIn("status=alert", text)
        self.assertIn("alert_count=", text)
        self.assertEqual(json.loads(json_out.read_text(encoding="utf-8"))["status"], "alert")
        posts = [c for c in fake.calls if c[0] == "POST"]
        self.assertEqual(len(posts), 2)
        titles = [p[2]["title"] for p in posts if p[2]]
        self.assertTrue(any(t.startswith(mod.ALERT_TITLE_PREFIX) for t in titles))
        self.assertTrue(any(t == f"{mod.REVIEW_TITLE_PREFIX} 2026-11" for t in titles))

    def test_no_network_without_create_issue_and_bad_input_exits_2(self) -> None:
        fake = FakeGitHub()
        code, _, _ = self.run_main(snapshot({"supabase.egress_gb": 0.1}), [], fake)
        self.assertEqual(code, 0)
        self.assertEqual(fake.calls, [])
        bad_code, _, _ = self.run_main(snapshot({}, collected_at="oops"), [], fake)
        self.assertEqual(bad_code, 2)

    def test_markdown_states_that_costs_are_estimates_and_lists_unmeasured(self) -> None:
        report = mod.evaluate(LIMITS, INITIAL_SNAPSHOT, today=TODAY)
        markdown = mod.render_markdown(report)
        self.assertIn("請求額ではありません", markdown)
        self.assertIn("未計測", markdown)
        self.assertIn("要対応", markdown)


if __name__ == "__main__":
    unittest.main()
