#!/usr/bin/env python3
"""Unit tests for scripts/appstream_capacity_planner.py (#2797)."""

from __future__ import annotations

from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))

import appstream_capacity_planner as planner  # noqa: E402


class AppStreamCapacityPlannerTest(unittest.TestCase):
    def test_computes_headroom_bounded_sessions_and_cost_savings(self) -> None:
        # 4 vCPU * 0.8 = 3.2 -> floor(3.2 / 0.5) = 6
        # 16 GiB * 0.8 = 12.8 -> floor(12.8 / 3.0) = 4
        # min(6, 4, 8) = 4
        result = planner.plan_multisession_capacity(
            planner.InstanceProfile(
                instance_type="stream.standard.xlarge",
                vcpu=4.0,
                memory_gib=16.0,
                hourly_cost_usd=0.40,
            ),
            planner.SessionWorkload(
                per_session_vcpu=0.5,
                per_session_memory_gib=3.0,
                configured_max_sessions=8,
            ),
        )
        self.assertEqual(result.cpu_bound_sessions, 6)
        self.assertEqual(result.memory_bound_sessions, 4)
        self.assertEqual(result.recommended_max_sessions, 4)
        self.assertEqual(result.single_session_cost_per_user_usd, 0.40)
        self.assertEqual(result.multi_session_cost_per_user_usd, 0.10)
        self.assertAlmostEqual(result.cost_savings_ratio, 0.75)
        self.assertEqual(result.client_ui_notices, [])

    def test_emits_peripheral_ui_notices_when_required(self) -> None:
        result = planner.plan_multisession_capacity(
            planner.InstanceProfile(
                instance_type="stream.standard.large",
                vcpu=2.0,
                memory_gib=8.0,
                hourly_cost_usd=0.20,
            ),
            planner.SessionWorkload(
                per_session_vcpu=0.4,
                per_session_memory_gib=1.5,
                requires_webcam=True,
                requires_local_usb=True,
            ),
        )
        self.assertEqual(len(result.client_ui_notices), 2)
        self.assertIn("webcam", result.client_ui_notices[0])
        self.assertIn("USB", result.client_ui_notices[1])

    def test_cli_returns_zero_for_valid_capacity(self) -> None:
        rc = planner.main(["--vcpu", "2", "--memory-gib", "8", "--json"])
        self.assertEqual(rc, 0)


if __name__ == "__main__":
    unittest.main()
