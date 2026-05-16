#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "smartcleanup_task_guard.py"


class SmartCleanupTaskGuardTest(unittest.TestCase):
    def run_guard(self, sample: dict) -> dict:
        with tempfile.TemporaryDirectory() as raw:
            sample_path = Path(raw) / "sample.json"
            sample_path.write_text(json.dumps(sample), encoding="utf-8")
            proc = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "--sample-json",
                    str(sample_path),
                    "--json",
                ],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        return json.loads(proc.stdout)

    def test_detects_1999_never_run_sentinel(self) -> None:
        result = self.run_guard(
            {
                "installed": True,
                "state": "Ready",
                "last_run_time": "1999-11-30T00:00:00+00:00",
                "last_task_result": 267011,
                "next_run_time": "2026-05-31T03:00:00+09:00",
            }
        )

        self.assertEqual(result["status"], "stuck")
        self.assertTrue(result["stuck"])
        self.assertIn("last_run_time sentinel year <= 1999", result["reasons"])
        self.assertIn("last_task_result 267011 indicates task has not run", result["reasons"])

    def test_accepts_recent_successful_task(self) -> None:
        result = self.run_guard(
            {
                "installed": True,
                "state": "Ready",
                "principal_user_id": "kanta",
                "last_run_time": "2026-05-14T00:00:00+00:00",
                "last_task_result": 0,
                "next_run_time": "2026-06-01T03:00:00+09:00",
            }
        )

        self.assertEqual(result["status"], "ok")
        self.assertFalse(result["stuck"])
        self.assertEqual(result["reasons"], [])

    def test_short_principal_is_actionable_for_never_run_task(self) -> None:
        result = self.run_guard(
            {
                "installed": True,
                "state": "Ready",
                "principal_user_id": "kanta",
                "last_run_time": "1999-11-30T00:00:00+00:00",
                "last_task_result": 267011,
                "next_run_time": "2026-06-01T03:00:00+09:00",
            }
        )

        self.assertEqual(result["status"], "stuck")
        self.assertIn("principal_user_id missing DOMAIN prefix", result["reasons"])

    def test_missing_task_is_actionable(self) -> None:
        result = self.run_guard(
            {
                "installed": False,
                "state": "missing",
                "last_run_time": "",
                "last_task_result": None,
                "next_run_time": "",
            }
        )

        self.assertEqual(result["status"], "missing")
        self.assertTrue(result["stuck"])
        self.assertIn("task missing", result["reasons"])


if __name__ == "__main__":
    unittest.main()
