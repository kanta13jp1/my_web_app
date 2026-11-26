#!/usr/bin/env python3
"""Unit tests for scripts/check_oss_observability_poc.py (#2813)."""

from __future__ import annotations

import datetime as dt
import sys
import tempfile
import unittest
from pathlib import Path

_SCRIPTS_DIR = Path(__file__).resolve().parent
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

from check_oss_observability_poc import (  # noqa: E402
    estimate_monthly_oss_cost,
    validate_oss_poc_doc,
)

REPO_ROOT = _SCRIPTS_DIR.parent


class OssObservabilityPocTests(unittest.TestCase):
    def test_repo_oss_poc_doc_passes(self) -> None:
        doc = REPO_ROOT / "docs" / "OSS_AI_OBSERVABILITY_POC.md"
        res = validate_oss_poc_doc(doc, today=dt.date(2026, 11, 26))
        self.assertTrue(res.ok, msg=f"Errors: {res.errors}")
        self.assertTrue(res.has_primary_refs)
        self.assertTrue(res.has_unverified_disclosure)

    def test_missing_unverified_disclosure_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            doc = Path(tmp) / "POC.md"
            doc.write_text(
                "---\nlast_reviewed: 2026-11-26\n---\n"
                "https://opentelemetry.io/docs/specs/otlp/\n"
                "https://langfuse.com/docs/deployment/self-host\n",
                encoding="utf-8",
            )
            res = validate_oss_poc_doc(doc, today=dt.date(2026, 11, 26))
        self.assertFalse(res.ok)
        self.assertFalse(res.has_unverified_disclosure)

    def test_estimate_monthly_oss_cost_computes_totals(self) -> None:
        est = estimate_monthly_oss_cost(
            compute_usd=15.0,
            storage_gb=50.0,
            storage_usd_per_gb=0.10,
        )
        self.assertEqual(est.compute_usd, 15.0)
        self.assertEqual(est.storage_usd, 5.0)
        self.assertEqual(est.total_monthly_usd, 20.0)


if __name__ == "__main__":
    unittest.main()
