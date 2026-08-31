#!/usr/bin/env python3
"""Plan, apply, or drain bounded Notion inventory expansion in the cloud."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Callable
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Protocol


SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
MAX_BATCH_LIMIT = 5
MAX_DRAIN_ITEMS = 100


class ExpansionError(RuntimeError):
    """Safe failure that never includes private payloads or credentials."""


def _bounded_integer(value: object, field: str, *, minimum: int = 0) -> int:
    try:
        parsed = int(value)
    except (TypeError, ValueError) as exc:
        raise ExpansionError(f"invalid aggregate field: {field}") from exc
    if parsed < minimum:
        raise ExpansionError(f"invalid aggregate field: {field}")
    return parsed


class InventoryHub(Protocol):
    def plan(self, limit: int) -> dict[str, Any]: ...

    def apply(self, limit: int, expected_plan_sha256: str) -> dict[str, Any]: ...


class SupabaseInventoryHub:
    def __init__(self, base_url: str, service_role_key: str) -> None:
        if not base_url.startswith("https://"):
            raise ExpansionError("SUPABASE_URL must use HTTPS")
        if not service_role_key:
            raise ExpansionError("SUPABASE_SERVICE_ROLE_KEY is missing")
        self._base_url = base_url.rstrip("/")
        self._service_role_key = service_role_key
        self._batch_id, self._owner_user_id = self._latest_batch()

    def _request(
        self,
        url: str,
        *,
        method: str = "GET",
        payload: dict[str, Any] | None = None,
        owner_header: bool = False,
    ) -> Any:
        headers = {
            "Accept": "application/json",
            "Authorization": f"Bearer {self._service_role_key}",
            "apikey": self._service_role_key,
        }
        data = None
        if payload is not None:
            headers["Content-Type"] = "application/json"
            data = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        if owner_header:
            headers["x-notion-migration-owner"] = self._owner_user_id
        request = urllib.request.Request(
            url,
            data=data,
            headers=headers,
            method=method,
        )
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            raise ExpansionError(
                f"cloud inventory endpoint returned HTTP {exc.code}"
            ) from None
        except urllib.error.URLError as exc:
            raise ExpansionError("cloud inventory endpoint request failed") from exc
        except json.JSONDecodeError as exc:
            raise ExpansionError("cloud inventory endpoint returned invalid JSON") from exc

    def _latest_batch(self) -> tuple[str, str]:
        query = urllib.parse.urlencode(
            [
                ("select", "id,user_id"),
                ("archived_at", "is.null"),
                ("order", "created_at.desc"),
                ("limit", "1"),
            ]
        )
        payload = self._request(
            f"{self._base_url}/rest/v1/notion_migration_batches?{query}"
        )
        if not isinstance(payload, list) or len(payload) != 1:
            raise ExpansionError("expected exactly one active migration batch")
        row = payload[0]
        if not isinstance(row, dict):
            raise ExpansionError("active migration batch response is invalid")
        batch_id = str(row.get("id") or "")
        owner_user_id = str(row.get("user_id") or "")
        if not batch_id or not owner_user_id:
            raise ExpansionError("active migration batch identity is incomplete")
        return batch_id, owner_user_id

    def _invoke(self, payload: dict[str, Any]) -> dict[str, Any]:
        response = self._request(
            f"{self._base_url}/functions/v1/notion-migration-hub",
            method="POST",
            payload={"batch_id": self._batch_id, **payload},
            owner_header=True,
        )
        if not isinstance(response, dict) or response.get("success") is not True:
            raise ExpansionError("cloud inventory endpoint rejected the request")
        return response

    def plan(self, limit: int) -> dict[str, Any]:
        return self._invoke({"action": "inventory.plan_expand", "limit": limit})

    def apply(self, limit: int, expected_plan_sha256: str) -> dict[str, Any]:
        return self._invoke(
            {
                "action": "inventory.expand",
                "limit": limit,
                "expected_plan_sha256": expected_plan_sha256,
            }
        )


def _validated_plan(payload: dict[str, Any], limit: int) -> dict[str, Any]:
    digest = str(payload.get("plan_sha256") or "")
    selected = _bounded_integer(payload.get("selected"), "selected")
    remaining = _bounded_integer(
        payload.get("remaining_to_expand"),
        "remaining_to_expand",
    )
    gate = payload.get("safe_apply_gate_open") is True
    if not SHA256_PATTERN.fullmatch(digest):
        raise ExpansionError("cloud inventory plan digest is invalid")
    if selected > limit or selected > remaining:
        raise ExpansionError("cloud inventory plan bounds are invalid")
    if gate != (selected > 0):
        raise ExpansionError("cloud inventory apply gate is inconsistent")
    if payload.get("source_deletion_attempted") is not False:
        raise ExpansionError("cloud inventory plan did not prove deletion safety")
    return {
        "plan_sha256": digest,
        "selected": selected,
        "remaining_before": remaining,
        "safe_apply_gate_open": gate,
    }


def execute(
    hub: InventoryHub,
    *,
    mode: str,
    limit: int,
    expected_plan_sha256: str,
) -> dict[str, Any]:
    if mode not in {"plan", "apply"}:
        raise ExpansionError("mode must be plan or apply")
    if not 1 <= limit <= MAX_BATCH_LIMIT:
        raise ExpansionError("limit must be between 1 and 5")

    plan = _validated_plan(hub.plan(limit), limit)
    report: dict[str, Any] = {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "mode": mode,
        **plan,
        "mutations": {
            "items_attempted": 0,
            "inventory_items_discovered": 0,
        },
        "remaining_after": plan["remaining_before"],
        "remaining_delta": 0,
        "source_deletion_attempted": False,
    }
    if mode == "plan":
        return report

    if not SHA256_PATTERN.fullmatch(expected_plan_sha256):
        raise ExpansionError("expected plan digest is required for apply")
    if expected_plan_sha256 != plan["plan_sha256"]:
        raise ExpansionError("expected plan digest does not match current plan")
    if not plan["safe_apply_gate_open"]:
        raise ExpansionError("cloud inventory apply gate is closed")

    applied = hub.apply(limit, expected_plan_sha256)
    if str(applied.get("plan_sha256") or "") != expected_plan_sha256:
        raise ExpansionError("applied plan digest does not match")
    attempted = _bounded_integer(applied.get("expanded"), "expanded")
    discovered = _bounded_integer(applied.get("discovered"), "discovered")
    remaining_after = _bounded_integer(
        applied.get("remaining_to_expand"),
        "remaining_to_expand",
    )
    if (
        attempted != plan["selected"]
        or remaining_after > plan["remaining_before"] + discovered
    ):
        raise ExpansionError("cloud inventory apply evidence is inconsistent")
    if applied.get("source_deletion_attempted") is not False:
        raise ExpansionError("cloud inventory apply did not prove deletion safety")

    report["mutations"] = {
        "items_attempted": attempted,
        "inventory_items_discovered": discovered,
    }
    report["remaining_after"] = remaining_after
    report["remaining_delta"] = remaining_after - plan["remaining_before"]
    report["inventory_complete"] = applied.get("inventory_complete") is True
    report["applied_at"] = datetime.now(timezone.utc).isoformat()
    return report


def execute_drain(
    hub: InventoryHub,
    *,
    limit: int,
    max_items: int,
    expected_plan_sha256: str,
    pause: Callable[[float], None] = time.sleep,
) -> dict[str, Any]:
    """Apply repeated five-item-or-smaller plans, capped at 100 attempts."""
    if not 1 <= limit <= MAX_BATCH_LIMIT:
        raise ExpansionError("limit must be between 1 and 5")
    if not 1 <= max_items <= MAX_DRAIN_ITEMS:
        raise ExpansionError("max items must be between 1 and 100")
    if not SHA256_PATTERN.fullmatch(expected_plan_sha256):
        raise ExpansionError("expected plan digest is required for drain")

    current_limit = min(limit, max_items)
    plan = _validated_plan(hub.plan(current_limit), current_limit)
    if expected_plan_sha256 != plan["plan_sha256"]:
        raise ExpansionError("expected plan digest does not match current plan")

    report: dict[str, Any] = {
        "schema_version": 2,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "mode": "drain",
        **plan,
        "batch_limit": limit,
        "max_items": max_items,
        "batches_applied": 0,
        "plan_chain_sha256": "",
        "mutations": {
            "items_attempted": 0,
            "inventory_items_discovered": 0,
        },
        "remaining_after": plan["remaining_before"],
        "remaining_delta": 0,
        "inventory_complete": plan["remaining_before"] == 0,
        "source_deletion_attempted": False,
    }
    if not plan["safe_apply_gate_open"]:
        if plan["remaining_before"] != 0:
            raise ExpansionError("cloud inventory drain gate is closed")
        report["stopped_reason"] = "inventory_complete"
        return report

    chain = hashlib.sha256()
    attempted_total = 0
    discovered_total = 0
    batches_applied = 0
    remaining_after = plan["remaining_before"]
    inventory_complete = False

    while attempted_total < max_items and plan["safe_apply_gate_open"]:
        digest = plan["plan_sha256"]
        applied = hub.apply(current_limit, digest)
        if str(applied.get("plan_sha256") or "") != digest:
            raise ExpansionError("applied plan digest does not match")
        attempted = _bounded_integer(applied.get("expanded"), "expanded")
        discovered = _bounded_integer(applied.get("discovered"), "discovered")
        remaining_after = _bounded_integer(
            applied.get("remaining_to_expand"),
            "remaining_to_expand",
        )
        if (
            attempted != plan["selected"]
            or remaining_after > plan["remaining_before"] + discovered
        ):
            raise ExpansionError("cloud inventory drain evidence is inconsistent")
        if applied.get("source_deletion_attempted") is not False:
            raise ExpansionError("cloud inventory drain did not prove deletion safety")

        attempted_total += attempted
        discovered_total += discovered
        batches_applied += 1
        chain.update(f"{batches_applied}:{digest}\n".encode("ascii"))
        inventory_complete = applied.get("inventory_complete") is True
        if inventory_complete or attempted_total >= max_items:
            break

        next_limit = min(limit, max_items - attempted_total)
        if next_limit <= 0:
            break
        pause(1.0)
        next_plan = _validated_plan(hub.plan(next_limit), next_limit)
        if next_plan["remaining_before"] != remaining_after:
            raise ExpansionError("cloud inventory changed between bounded batches")
        if not next_plan["safe_apply_gate_open"]:
            if next_plan["remaining_before"] != 0:
                raise ExpansionError("cloud inventory drain gate closed before completion")
            inventory_complete = True
            break
        plan = next_plan
        current_limit = next_limit

    report["batches_applied"] = batches_applied
    report["plan_chain_sha256"] = chain.hexdigest()
    report["mutations"] = {
        "items_attempted": attempted_total,
        "inventory_items_discovered": discovered_total,
    }
    report["remaining_after"] = remaining_after
    report["remaining_delta"] = remaining_after - report["remaining_before"]
    report["inventory_complete"] = inventory_complete
    report["applied_at"] = datetime.now(timezone.utc).isoformat()
    report["stopped_reason"] = (
        "inventory_complete" if inventory_complete else "max_items_reached"
    )
    return report


def render_summary(report: dict[str, Any]) -> str:
    mutations = report["mutations"]
    lines = [
        "## Notion inventory cloud expansion",
        "",
        "This evidence contains counts and gates only. No Notion content, IDs, paths, or credentials are included.",
        "",
        f"- mode: {report['mode']}",
        f"- selected: {report['selected']}",
        f"- remaining before: {report['remaining_before']}",
        f"- remaining after: {report['remaining_after']}",
        f"- remaining delta: {report['remaining_delta']}",
        f"- items attempted: {mutations['items_attempted']}",
        f"- inventory items discovered: {mutations['inventory_items_discovered']}",
        (
            "- safe apply gate: "
            + ("OPEN" if report["safe_apply_gate_open"] else "CLOSED")
        ),
        "- source deletion attempted: false",
    ]
    if report["mode"] == "drain":
        lines.extend(
            [
                f"- bounded batches applied: {report['batches_applied']}",
                f"- maximum item attempts: {report['max_items']}",
                f"- stopped reason: {report['stopped_reason']}",
            ]
        )
    lines.append("")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json-output", type=Path, required=True)
    parser.add_argument("--summary-output", type=Path, required=True)
    args = parser.parse_args(argv)

    try:
        limit = int(os.environ.get("INVENTORY_LIMIT", "5"))
        hub = SupabaseInventoryHub(
            os.environ.get("SUPABASE_URL", ""),
            os.environ.get("SUPABASE_SERVICE_ROLE_KEY", ""),
        )
        mode = os.environ.get("INVENTORY_MODE", "plan")
        expected_plan_sha256 = os.environ.get(
            "EXPECTED_PLAN_SHA256",
            "",
        ).strip()
        if mode == "drain":
            report = execute_drain(
                hub,
                limit=limit,
                max_items=int(os.environ.get("INVENTORY_MAX_ITEMS", "100")),
                expected_plan_sha256=expected_plan_sha256,
            )
        else:
            report = execute(
                hub,
                mode=mode,
                limit=limit,
                expected_plan_sha256=expected_plan_sha256,
            )
    except (ExpansionError, ValueError) as exc:
        print(f"::error::Notion inventory cloud expansion failed: {exc}", file=sys.stderr)
        return 1

    args.json_output.write_text(
        json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    with args.summary_output.open("a", encoding="utf-8") as summary:
        summary.write(render_summary(report))
    print("Notion inventory expansion completed without content payloads.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
