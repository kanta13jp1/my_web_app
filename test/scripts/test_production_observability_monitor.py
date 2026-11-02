import unittest
import sys
import json
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from scripts import production_observability_monitor as monitor


class ProductionObservabilityMonitorTest(unittest.TestCase):
    def report(
        self,
        *,
        p95=1200,
        errors=0,
        sentry=1,
        load=0.5,
        sentry_status="configured",
        forced_alert_label=None,
    ):
        return monitor.build_report(
            [{"provider": "openai", "total_requests": 10, "error_count": errors, "p95_latency_ms": p95}],
            {"node_load5": load, "pg_stat_database_numbackends": 4},
            sentry,
            p95_alert_ms=5000,
            error_rate_alert=0.2,
            sentry_error_alert=20,
            resource_alerts={"node_load5": 4},
            sentry_status=sentry_status,
            forced_alert_label=forced_alert_label,
        )

    def test_normal_signals_do_not_alert(self):
        report = self.report()
        self.assertFalse(report["breach"])
        self.assertEqual(report["dedupe_key"], "none")

    def test_slow_provider_alert_is_deterministic(self):
        first = self.report(p95=7000)
        second = self.report(p95=9000)
        self.assertTrue(first["breach"])
        self.assertEqual(first["dedupe_key"], second["dedupe_key"])
        self.assertEqual(first["alerts"][0]["reason"], "p95_latency")

    def test_failure_and_resource_thresholds_alert_without_payloads(self):
        report = self.report(errors=3, sentry=25, load=5)
        self.assertTrue(report["breach"])
        self.assertEqual({a["reason"] for a in report["alerts"]}, {"error_rate", "error_volume", "resource"})
        serialized = monitor.render_markdown(report).lower()
        self.assertNotIn("prompt", serialized.replace(report["privacy"], ""))
        self.assertNotIn("secret", serialized.replace(report["privacy"], ""))

    def test_reads_sentry_error_category_stats_v2_totals(self):
        payload = {
            "groups": [
                {"by": {"category": "error"}, "totals": {"sum(quantity)": 7}}
            ]
        }
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "sentry.json"
            path.write_text(json.dumps(payload), encoding="utf-8")
            self.assertEqual(monitor.load_sentry_count(path), 7)

    def test_reads_existing_ai_hub_provider_health_response_shape(self):
        payload = {"success": True, "providers": [{"provider": "openai"}]}
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "ai-hub.json"
            path.write_text(json.dumps(payload), encoding="utf-8")
            self.assertEqual(monitor.load_ai_hub(path), payload["providers"])

    def test_unconfigured_sentry_is_reported_without_false_alert(self):
        report = self.report(sentry=999, sentry_status="unconfigured")
        self.assertFalse(report["breach"])
        self.assertEqual(report["source_status"]["sentry"], "unconfigured")
        self.assertNotIn("error_volume", {alert["reason"] for alert in report["alerts"]})

    def test_forced_manual_validation_alert_is_deterministic(self):
        first = self.report(forced_alert_label="issue-2849-live-proof")
        second = self.report(forced_alert_label="issue-2849-live-proof")
        self.assertTrue(first["breach"])
        self.assertTrue(first["forced_alert"])
        self.assertEqual(first["dedupe_key"], second["dedupe_key"])
        self.assertEqual(first["alerts"][-1]["source"], "manual_validation")



class AlertRoutingTest(unittest.TestCase):
    def issue(self, number, **overrides):
        value = {"number": number, "state": "open",
                 "title": "[Alert][Observability] Production telemetry threshold breach",
                 "body": "[observability-dedupe:a2126f97a0de97c3]"}
        value.update(overrides)
        return value

    def test_dashboard_is_never_alert_destination(self):
        dashboard = self.issue(5101, title="[Dashboard][Observability] Production telemetry",
                               body="[observability-dashboard:v1]\n[observability-dedupe:0525f6bf8608751b]")
        self.assertEqual(monitor.select_alert_issue([dashboard, self.issue(5102)]), 5102)

    def test_oldest_canonical_survives_changed_fingerprint_and_order(self):
        newer = self.issue(5402, body="[observability-dedupe:0525f6bf8608751b]")
        self.assertEqual(monitor.select_alert_issue([newer, self.issue(5102)]), 5102)

    def test_closed_pr_missing_marker_and_fuzzy_title_excluded(self):
        invalid = [self.issue(1, state="closed"), self.issue(2, pull_request={}),
                   self.issue(3, body=None), self.issue(4, title="unrelated"),
                   self.issue(5, body="text [observability-dedupe:a2126f97a0de97c3]"),
                   self.issue(6, body="[observability-dashboard:v1]\n[observability-dedupe:a2126f97a0de97c3]")]
        self.assertIsNone(monitor.select_alert_issue(invalid))

    def test_validation_and_production_are_separate(self):
        validation = self.issue(5000, title="[Validation][Observability] Dedupe alert live proof")
        issues = [validation, self.issue(5102)]
        self.assertEqual(monitor.select_alert_issue(issues, forced=True), 5000)
        self.assertEqual(monitor.select_alert_issue(issues), 5102)
        self.assertIsNone(monitor.select_alert_issue([self.issue(5102)], forced=True))

if __name__ == "__main__":
    unittest.main()
