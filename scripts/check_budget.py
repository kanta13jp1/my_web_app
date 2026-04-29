#!/usr/bin/env python3
"""GitHub Actions pre-flight budget check for PLATFORM #6."""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone


def month_scope_id() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m")


def next_month_reset_at(now: datetime | None = None) -> str:
    current = now or datetime.now(timezone.utc)
    year = current.year + (1 if current.month == 12 else 0)
    month = 1 if current.month == 12 else current.month + 1
    return (
        datetime(year, month, 1, tzinfo=timezone.utc)
        .isoformat()
        .replace("+00:00", "Z")
    )


def parse_reset_at(value: object) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None


def request_json(method: str, url: str, service_role: str, payload: dict | None = None):
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "apikey": service_role,
            "Authorization": f"Bearer {service_role}",
            "Content-Type": "application/json",
            "Prefer": "return=representation,resolution=merge-duplicates",
        },
    )
    with urllib.request.urlopen(req, timeout=20) as res:
        raw = res.read().decode("utf-8")
        return json.loads(raw) if raw else None


def fetch_budget(base_url: str, service_role: str, scope: str, scope_id: str):
    query = urllib.parse.urlencode(
        {
            "scope": f"eq.{scope}",
            "scope_id": f"eq.{scope_id}",
            "select": "scope,scope_id,limit_usd,spent_usd,reset_at",
            "limit": "1",
        }
    )
    rows = request_json(
        "GET",
        f"{base_url.rstrip('/')}/rest/v1/task_budget?{query}",
        service_role,
    )
    return rows[0] if rows else None


def upsert_budget(
    base_url: str,
    service_role: str,
    scope: str,
    scope_id: str,
    limit_usd: float,
):
    payload = {
        "scope": scope,
        "scope_id": scope_id,
        "limit_usd": limit_usd,
        "spent_usd": 0,
        "reset_at": next_month_reset_at(),
    }
    rows = request_json(
        "POST",
        f"{base_url.rstrip('/')}/rest/v1/task_budget?on_conflict=scope,scope_id",
        service_role,
        payload,
    )
    return rows[0] if rows else payload


def reset_budget(
    base_url: str,
    service_role: str,
    scope: str,
    scope_id: str,
    limit_usd: float,
):
    query = urllib.parse.urlencode(
        {"scope": f"eq.{scope}", "scope_id": f"eq.{scope_id}"}
    )
    payload = {
        "spent_usd": 0,
        "limit_usd": limit_usd,
        "reset_at": next_month_reset_at(),
    }
    rows = request_json(
        "PATCH",
        f"{base_url.rstrip('/')}/rest/v1/task_budget?{query}",
        service_role,
        payload,
    )
    return rows[0] if rows else payload


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scope", required=True, choices=["ef", "gha", "instance", "month"])
    parser.add_argument("--scope-id", required=True)
    parser.add_argument("--limit", type=float, default=None)
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    base_url = os.getenv("SUPABASE_URL", "")
    service_role = os.getenv("SERVICE_ROLE_KEY") or os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
    if not base_url or not service_role:
        message = "SUPABASE_URL and SERVICE_ROLE_KEY are not configured; budget check skipped"
        if args.strict:
            print(f"::error::{message}")
            return 1
        print(f"::warning::{message}")
        return 0

    try:
        budget = fetch_budget(base_url, service_role, args.scope, args.scope_id)
        if budget is None:
            limit = args.limit if args.limit is not None else 20.0
            budget = upsert_budget(base_url, service_role, args.scope, args.scope_id, limit)
        else:
            reset_at = parse_reset_at(budget.get("reset_at"))
            if reset_at is not None and reset_at <= datetime.now(timezone.utc):
                limit = float(budget.get("limit_usd") or args.limit or 20.0)
                budget = reset_budget(base_url, service_role, args.scope, args.scope_id, limit)

        spent = float(budget.get("spent_usd") or 0)
        limit = float(budget.get("limit_usd") or args.limit or 0)
        remaining = limit - spent

        month_budget = fetch_budget(base_url, service_role, "month", month_scope_id())
        if month_budget:
            month_remaining = float(month_budget.get("limit_usd") or 0) - float(
                month_budget.get("spent_usd") or 0
            )
            remaining = min(remaining, month_remaining)

        print(
            f"budget scope={args.scope}:{args.scope_id} limit=${limit:.2f} "
            f"spent=${spent:.4f} remaining=${remaining:.4f}"
        )
        if remaining <= 0:
            print("::error::Task budget exceeded")
            return 1
        return 0
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        print(f"::error::Budget check failed: HTTP {exc.code} {detail}")
        return 1 if args.strict else 0
    except Exception as exc:  # noqa: BLE001
        print(f"::error::Budget check failed: {exc}")
        return 1 if args.strict else 0


if __name__ == "__main__":
    sys.exit(main())
