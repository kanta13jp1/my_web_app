#!/usr/bin/env python3
"""Offline contract tests for client error monitoring & E2E CI coverage (#2768)."""

from __future__ import annotations

from pathlib import Path
import unittest

REPO_ROOT = Path(__file__).resolve().parents[2]


class ClientErrorMonitoringCiContractTest(unittest.TestCase):
    def test_pubspec_and_main_wire_sentry_and_error_reporter(self) -> None:
        pubspec = (REPO_ROOT / "pubspec.yaml").read_text(encoding="utf-8")
        main_dart = (REPO_ROOT / "lib" / "main.dart").read_text(encoding="utf-8")
        self.assertIn("sentry_flutter:", pubspec)
        self.assertIn("ErrorReporter.instance.install", main_dart)
        self.assertIn("SentryNavigatorObserver", main_dart)

    def test_ci_and_e2e_workflows_cover_vm_and_playwright_scenarios(self) -> None:
        ci_yml = (REPO_ROOT / ".github" / "workflows" / "ci.yml").read_text(
            encoding="utf-8",
        )
        e2e_smoke = (
            REPO_ROOT / ".github" / "workflows" / "e2e-smoke.yml"
        ).read_text(encoding="utf-8")
        self.assertIn("VM tests", ci_yml)
        self.assertIn("npm run e2e:business-execution", ci_yml)
        self.assertIn("npm run e2e:smoke", e2e_smoke)
        self.assertIn("npm run e2e:visual", e2e_smoke)

    def test_evaluation_doc_documents_primary_sources_and_privacy(self) -> None:
        doc = (
            REPO_ROOT / "docs" / "CLIENT_ERROR_MONITORING_EVALUATION.md"
        ).read_text(encoding="utf-8")
        for marker in (
            "https://pub.dev/api/packages/firebase_crashlytics",
            "https://firebase.google.com/docs/test-lab",
            "https://sentry.io/pricing/",
            "sendDefaultPii = false",
            "auto_error_report",
        ):
            self.assertIn(marker, doc)


if __name__ == "__main__":
    unittest.main()
