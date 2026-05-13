#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "session_compression_guard.py"


class SessionCompressionGuardTest(unittest.TestCase):
    def run_guard(self, tmp: Path, *extra: str) -> dict:
        state = tmp / "state.json"
        log = tmp / "session-delta.csv"
        command = [
            sys.executable,
            str(SCRIPT),
            "--root",
            str(ROOT),
            "--state-path",
            str(state),
            "--log-path",
            str(log),
            "--json",
            *extra,
        ]
        proc = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        return json.loads(proc.stdout)

    def test_session_start_low_disk_triggers_forced_fire_decision(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            tmp = Path(raw)
            result = self.run_guard(
                tmp,
                "--mode",
                "session-start",
                "--sample-free-gb",
                "23.5",
                "--sample-ram-pct",
                "82.5",
                "--sample-now",
                "2026-05-14T00:00:00+00:00",
            )

        self.assertTrue(result["should_fire"])
        self.assertEqual(result["phase"], "session_start_forced_fire")
        self.assertIn("c_free_gb 23.50 < 26.00", result["reason"])
        self.assertIn("[KPI] C:23.50GB", result["banner"])

    def test_session_start_recent_fire_and_capacity_skips(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            tmp = Path(raw)
            state = tmp / "state.json"
            state.write_text(
                json.dumps({"last_fire_at": "2026-05-14T00:00:00+00:00", "fires": []}),
                encoding="utf-8",
            )
            result = self.run_guard(
                tmp,
                "--mode",
                "session-start",
                "--sample-free-gb",
                "29.0",
                "--sample-now",
                "2026-05-14T00:30:00+00:00",
            )

        self.assertFalse(result["should_fire"])
        self.assertEqual(result["decision"], "skip")

    def test_userprompt_respects_hourly_cooldown(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            tmp = Path(raw)
            state = tmp / "state.json"
            state.write_text(
                json.dumps(
                    {
                        "last_fire_at": "2026-05-14T00:00:00+00:00",
                        "last_userprompt_fire_at": "2026-05-14T00:45:00+00:00",
                        "fires": [],
                    }
                ),
                encoding="utf-8",
            )
            result = self.run_guard(
                tmp,
                "--mode",
                "userprompt",
                "--sample-free-gb",
                "24.0",
                "--sample-now",
                "2026-05-14T01:15:00+00:00",
            )

        self.assertFalse(result["should_fire"])
        self.assertIn("userprompt cooldown", result["reason"])

    def test_fatigue_flag_uses_last_three_reclaim_values(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            tmp = Path(raw)
            state = tmp / "state.json"
            state.write_text(
                json.dumps(
                    {
                        "last_fire_at": "2026-05-14T00:00:00+00:00",
                        "fires": [
                            {"reclaim_mb": 20},
                            {"reclaim_mb": 40},
                            {"reclaim_mb": 60},
                        ],
                    }
                ),
                encoding="utf-8",
            )
            result = self.run_guard(
                tmp,
                "--mode",
                "session-start",
                "--sample-free-gb",
                "28.0",
                "--sample-now",
                "2026-05-14T00:05:00+00:00",
            )

        self.assertEqual(result["fatigue"], "FATIGUE")
        self.assertIn("fatigue:FATIGUE", result["banner"])


if __name__ == "__main__":
    unittest.main()
