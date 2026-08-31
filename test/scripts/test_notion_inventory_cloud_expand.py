#!/usr/bin/env python3
from __future__ import annotations

import json
import unittest

from scripts.notion_inventory_cloud_expand import (
    ExpansionError,
    execute,
    execute_drain,
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


class DrainHub:
    def __init__(self) -> None:
        self.plan_calls: list[int] = []
        self.apply_calls: list[tuple[int, str]] = []
        self._plans = [
            {
                "plan_sha256": "a" * 64,
                "selected": 5,
                "remaining_to_expand": 100,
                "safe_apply_gate_open": True,
                "source_deletion_attempted": False,
                "private_batch_id": "must-not-leak",
            },
            {
                "plan_sha256": "b" * 64,
                "selected": 5,
                "remaining_to_expand": 95,
                "safe_apply_gate_open": True,
                "source_deletion_attempted": False,
            },
            {
                "plan_sha256": "c" * 64,
                "selected": 2,
                "remaining_to_expand": 90,
                "safe_apply_gate_open": True,
                "source_deletion_attempted": False,
            },
        ]
        self._applies = [
            {
                "plan_sha256": "a" * 64,
                "expanded": 5,
                "discovered": 3,
                "remaining_to_expand": 95,
                "inventory_complete": False,
                "source_deletion_attempted": False,
                "private_page_id": "must-not-leak",
            },
            {
                "plan_sha256": "b" * 64,
                "expanded": 5,
                "discovered": 2,
                "remaining_to_expand": 90,
                "inventory_complete": False,
                "source_deletion_attempted": False,
            },
            {
                "plan_sha256": "c" * 64,
                "expanded": 2,
                "discovered": 1,
                "remaining_to_expand": 88,
                "inventory_complete": False,
                "source_deletion_attempted": False,
            },
        ]

    def plan(self, limit: int) -> dict[str, object]:
        self.plan_calls.append(limit)
        return self._plans[len(self.plan_calls) - 1]

    def apply(self, limit: int, expected_plan_sha256: str) -> dict[str, object]:
        self.apply_calls.append((limit, expected_plan_sha256))
        return self._applies[len(self.apply_calls) - 1]


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

    def test_apply_allows_remaining_growth_explained_by_discovery(self) -> None:
        hub = FakeHub()
        hub.plan_payload["remaining_to_expand"] = 100
        hub.apply_payload.update(
            {
                "discovered": 12,
                "remaining_to_expand": 107,
            }
        )

        report = execute(
            hub,
            mode="apply",
            limit=5,
            expected_plan_sha256=DIGEST,
        )

        self.assertEqual(report["remaining_after"], 107)
        self.assertEqual(report["remaining_delta"], 7)

    def test_apply_rejects_remaining_growth_beyond_discovery(self) -> None:
        hub = FakeHub()
        hub.plan_payload["remaining_to_expand"] = 100
        hub.apply_payload.update(
            {
                "discovered": 12,
                "remaining_to_expand": 113,
            }
        )

        with self.assertRaisesRegex(ExpansionError, "evidence is inconsistent"):
            execute(
                hub,
                mode="apply",
                limit=5,
                expected_plan_sha256=DIGEST,
            )

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

    def test_drain_replans_each_five_item_batch_and_caps_total(self) -> None:
        hub = DrainHub()
        pauses: list[float] = []

        report = execute_drain(
            hub,
            limit=5,
            max_items=12,
            expected_plan_sha256="a" * 64,
            pause=pauses.append,
        )

        self.assertEqual(hub.plan_calls, [5, 5, 2])
        self.assertEqual(
            hub.apply_calls,
            [(5, "a" * 64), (5, "b" * 64), (2, "c" * 64)],
        )
        self.assertEqual(pauses, [1.0, 1.0])
        self.assertEqual(report["batches_applied"], 3)
        self.assertEqual(report["mutations"]["items_attempted"], 12)
        self.assertEqual(report["mutations"]["inventory_items_discovered"], 6)
        self.assertEqual(report["remaining_after"], 88)
        self.assertEqual(report["stopped_reason"], "max_items_reached")
        self.assertFalse(report["source_deletion_attempted"])
        evidence = json.dumps(report) + render_summary(report)
        self.assertNotIn("private_page_id", evidence)
        self.assertNotIn("private_batch_id", evidence)

    def test_drain_stale_initial_digest_fails_before_any_write(self) -> None:
        hub = DrainHub()

        with self.assertRaisesRegex(
            ExpansionError,
            "does not match current plan",
        ):
            execute_drain(
                hub,
                limit=5,
                max_items=100,
                expected_plan_sha256="d" * 64,
                pause=lambda _: None,
            )

        self.assertEqual(hub.apply_calls, [])

    def test_drain_allows_growth_explained_by_discovered_children(self) -> None:
        hub = FakeHub()
        hub.plan_payload["remaining_to_expand"] = 100
        hub.apply_payload.update(
            {
                "discovered": 12,
                "remaining_to_expand": 107,
            }
        )

        report = execute_drain(
            hub,
            limit=5,
            max_items=5,
            expected_plan_sha256=DIGEST,
            pause=lambda _: None,
        )

        self.assertEqual(report["mutations"]["items_attempted"], 5)
        self.assertEqual(report["remaining_after"], 107)
        self.assertEqual(report["remaining_delta"], 7)

    def test_drain_rejects_growth_beyond_discovered_children(self) -> None:
        hub = FakeHub()
        hub.plan_payload["remaining_to_expand"] = 100
        hub.apply_payload.update(
            {
                "discovered": 12,
                "remaining_to_expand": 113,
            }
        )

        with self.assertRaisesRegex(ExpansionError, "evidence is inconsistent"):
            execute_drain(
                hub,
                limit=5,
                max_items=5,
                expected_plan_sha256=DIGEST,
                pause=lambda _: None,
            )

    def test_drain_rejects_more_than_one_hundred_before_planning(self) -> None:
        hub = DrainHub()

        with self.assertRaisesRegex(ExpansionError, "between 1 and 100"):
            execute_drain(
                hub,
                limit=5,
                max_items=101,
                expected_plan_sha256="a" * 64,
                pause=lambda _: None,
            )

        self.assertEqual(hub.plan_calls, [])
        self.assertEqual(hub.apply_calls, [])


if __name__ == "__main__":
    unittest.main()
