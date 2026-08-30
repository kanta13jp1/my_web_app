#!/usr/bin/env python3
from __future__ import annotations

import unittest

from cloud_first_route import ResourceSnapshot, decide_route


class CloudFirstRouteTest(unittest.TestCase):
    def test_low_disk_requires_cloud(self) -> None:
        decision = decide_route(ResourceSnapshot(12.0, 8.0, 50.0))

        self.assertEqual(decision.route, "cloud_required")
        self.assertIn("free disk", decision.reasons[0])

    def test_low_memory_requires_cloud(self) -> None:
        decision = decide_route(ResourceSnapshot(80.0, 1.5, 91.0))

        self.assertEqual(decision.route, "cloud_required")
        self.assertEqual(len(decision.reasons), 2)

    def test_healthy_machine_still_prefers_cloud(self) -> None:
        decision = decide_route(ResourceSnapshot(80.0, 8.0, 50.0))

        self.assertEqual(decision.route, "cloud_preferred")
        self.assertEqual(decision.reasons, ())


if __name__ == "__main__":
    unittest.main()
