#!/usr/bin/env python3
from __future__ import annotations

import json
import unittest

from scripts.notion_inventory_cloud_expand import (
    ExpansionError,
    execute,
    render_summary,
)


DIGEST = "a" * 64


class FakeHub:
    def __init__(self) -> None:
        self.apply_calls: list[tuple[int, str]] = []
        self.plan_payload = {
            "plan_sha256": DIGEST,
            "selected": 5,
            "remaining_to_expand": 4759,
            "safe_apply_gate_open": True,
            "source_deletion_attempted": False,
            "private_batch_id": "must-not-leak",
        }
        self.apply_payload = {
            "plan_sha256": DIGEST,
            "expanded": 5,
            "discovered": 12,
            "remaining_to_expand": 4754,
            "inventory_complete": False,
            "source_deletion_attempted": False,
            "private_page_id": "must-not-leak",
        }

    def plan(self, limit: int) -> dict[str, object]:
        self.last_plan_limit = limit
        return self.plan_payload

    def apply(self, limit: int, expected_plan_sha256: str) -> dict[str, object]:
        self.apply_calls.append((limit, expected_plan_sha256))
        return self.apply_payload


class NotionInventoryCloudExpandTest(unittest.TestCase):
    def test_plan_is_read_only_and_content_free(self) -> None:
        hub = FakeHub()
        report = execute(
            hub,
            mode="plan",
            limit=5,
            expected_plan_sha256="",
        )

        self.assertEqual(report["selected"], 5)
        self.assertEqual(report["remaining_before"], 4759)
        self.assertEqual(report["mutations"]["items_attempted"], 0)
        self.assertEqual(hub.apply_calls, [])
        evidence = json.dumps(report) + render_summary(report)
        self.assertNotIn("must-not-leak", evidence)

    def test_apply_requires_and_forwards_exact_current_digest(self) -> None:
        hub = FakeHub()
        report = execute(
            hub,
            mode="apply",
            limit=5,
            expected_plan_sha256=DIGEST,
        )

        self.assertEqual(hub.apply_calls, [(5, DIGEST)])
        self.assertEqual(report["mutations"]["items_attempted"], 5)
        self.assertEqual(report["mutations"]["inventory_items_discovered"], 12)
        self.assertEqual(report["remaining_after"], 4754)
        self.assertFalse(report["source_deletion_attempted"])

    def test_stale_digest_fails_before_any_write(self) -> None:
        hub = FakeHub()
        with self.assertRaisesRegex(
            ExpansionError,
            "does not match current plan",
        ):
            execute(
                hub,
                mode="apply",
                limit=5,
                expected_plan_sha256="b" * 64,
            )

        self.assertEqual(hub.apply_calls, [])

    def test_closed_gate_fails_before_any_write(self) -> None:
        hub = FakeHub()
        hub.plan_payload.update(
            {
                "selected": 0,
                "remaining_to_expand": 0,
                "safe_apply_gate_open": False,
            }
        )
        with self.assertRaisesRegex(ExpansionError, "apply gate is closed"):
            execute(
                hub,
                mode="apply",
                limit=5,
                expected_plan_sha256=DIGEST,
            )

        self.assertEqual(hub.apply_calls, [])


if __name__ == "__main__":
    unittest.main()
