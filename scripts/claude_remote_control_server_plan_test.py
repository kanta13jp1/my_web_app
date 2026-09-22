#!/usr/bin/env python3
from __future__ import annotations

import unittest

from claude_remote_control_server_plan import HostResources, build_server_plan


HEALTHY = HostResources(
    ram_used_pct=50.0,
    ram_free_gb=8.0,
    disk_free_gb=60.0,
)


class ServerPlanTest(unittest.TestCase):
    def test_blocks_until_security_review_is_recorded(self) -> None:
        plan = build_server_plan(
            mode="single",
            requested_capacity=None,
            security_review_recorded=False,
            resources=HEALTHY,
        )

        self.assertEqual(plan.status, "blocked")
        self.assertEqual(plan.command, [])
        self.assertTrue(any("security/legal" in item for item in plan.blockers))

    def test_single_mode_enables_sandbox_without_capacity(self) -> None:
        plan = build_server_plan(
            mode="single",
            requested_capacity=None,
            security_review_recorded=True,
            resources=HEALTHY,
        )

        self.assertEqual(plan.status, "ready")
        self.assertEqual(plan.capacity, None)
        self.assertEqual(
            plan.command,
            [
                "claude",
                "remote-control",
                "--sandbox",
                "--spawn",
                "session",
                "--permission-mode",
                "default",
            ],
        )

    def test_multi_mode_uses_worktrees_and_bounded_capacity(self) -> None:
        plan = build_server_plan(
            mode="multi",
            requested_capacity=2,
            security_review_recorded=True,
            resources=HEALTHY,
        )

        self.assertEqual(plan.status, "ready")
        self.assertEqual(plan.capacity, 2)
        self.assertIn("--sandbox", plan.command)
        self.assertIn("worktree", plan.command)
        self.assertIn("--no-create-session-in-dir", plan.command)

    def test_rejects_default_server_capacity_and_same_dir(self) -> None:
        excessive = build_server_plan(
            mode="multi",
            requested_capacity=32,
            security_review_recorded=True,
            resources=HEALTHY,
        )
        shared = build_server_plan(
            mode="same-dir",
            requested_capacity=None,
            security_review_recorded=True,
            resources=HEALTHY,
        )

        self.assertEqual(excessive.status, "blocked")
        self.assertEqual(shared.status, "blocked")
        self.assertTrue(any("same-dir" in item for item in shared.blockers))

    def test_blocks_resource_pressure_or_unknown_measurements(self) -> None:
        pressure = build_server_plan(
            mode="single",
            requested_capacity=None,
            security_review_recorded=True,
            resources=HostResources(
                ram_used_pct=86.0,
                ram_free_gb=1.5,
                disk_free_gb=20.0,
            ),
        )
        unknown = build_server_plan(
            mode="single",
            requested_capacity=None,
            security_review_recorded=True,
            resources=HostResources(None, None, None),
        )

        self.assertEqual(pressure.status, "blocked")
        self.assertEqual(pressure.command, [])
        self.assertEqual(unknown.status, "blocked")
        self.assertTrue(any("could not be measured" in item for item in unknown.blockers))

    def test_rejects_capacity_with_single_session_mode(self) -> None:
        plan = build_server_plan(
            mode="single",
            requested_capacity=1,
            security_review_recorded=True,
            resources=HEALTHY,
        )

        self.assertEqual(plan.status, "blocked")
        self.assertTrue(any("cannot be combined" in item for item in plan.blockers))


if __name__ == "__main__":
    unittest.main()
