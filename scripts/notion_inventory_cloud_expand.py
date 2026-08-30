#!/usr/bin/env python3
"""Plan or apply one bounded Notion inventory expansion in the cloud."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Protocol


SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")


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
    if not 1 <= limit <= 5:
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
    if attempted != plan["selected"] or remaining_after > plan["remaining_before"]:
        raise ExpansionError("cloud inventory apply evidence is inconsistent")
    if applied.get("source_deletion_attempted") is not False:
        raise ExpansionError("cloud inventory apply did not prove deletion safety")

    report["mutations"] = {
        "items_attempted": attempted,
        "inventory_items_discovered": discovered,
    }
    report["remaining_after"] = remaining_after
    report["inventory_complete"] = applied.get("inventory_complete") is True
    report["applied_at"] = datetime.now(timezone.utc).isoformat()
    return report


def render_summary(report: dict[str, Any]) -> str:
    mutations = report["mutations"]
    return "\n".join(
        [
            "## Notion inventory cloud expansion",
            "",
            "This evidence contains counts and gates only. No Notion content, IDs, paths, or credentials are included.",
            "",
            f"- mode: {report['mode']}",
            f"- selected: {report['selected']}",
            f"- remaining before: {report['remaining_before']}",
            f"- remaining after: {report['remaining_after']}",
            f"- items attempted: {mutations['items_attempted']}",
            f"- inventory items discovered: {mutations['inventory_items_discovered']}",
            (
                "- safe apply gate: "
                + ("OPEN" if report["safe_apply_gate_open"] else "CLOSED")
            ),
            "- source deletion attempted: false",
            "",
        ]
    )


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
        report = execute(
            hub,
            mode=os.environ.get("INVENTORY_MODE", "plan"),
            limit=limit,
            expected_plan_sha256=os.environ.get(
                "EXPECTED_PLAN_SHA256",
                "",
            ).strip(),
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
