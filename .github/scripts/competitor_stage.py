#!/usr/bin/env python3
"""
competitor_stage.py - Stage new competitor candidates and persist discovery logs to Supabase (#2696).
Reads /tmp/all_candidates.json, /tmp/existing_competitors.json, and optional DISCOVERY_LOG_PATH.
Called by competitor-discovery.yml Step 3.
"""
from __future__ import annotations

import datetime as dt
import json
import os
import urllib.error
import urllib.request
from typing import Any, Callable


def stage_candidates(
    *,
    supabase_url: str,
    service_key: str,
    candidates: list[dict[str, Any]],
    existing: list[dict[str, Any]],
    week_str: str,
    opener: Callable[..., Any] = urllib.request.urlopen,
) -> tuple[int, int, int, list[str]]:
    existing_ids = {str(c.get("id", "")).lower() for c in existing}
    existing_ids.discard("")
    existing_names = {
        str(c.get("name", c.get("display_name", ""))).lower() for c in existing
    }
    existing_names.discard("")

    new_count = 0
    skip_count = 0
    error_count = 0
    error_logs: list[str] = []

    for c in candidates:
        cid = str(c.get("id", "")).lower().replace(" ", "-")
        cname = str(c.get("display_name", "")).lower()

        if cid in existing_ids or cname in existing_names:
            skip_count += 1
            continue

        payload = {
            "id": cid,
            "display_name": c.get("display_name", cid),
            "category": c.get("category"),
            "website": c.get("website"),
            "description": c.get("description"),
            "source": "gemini-discovery",
            "ai_score": c.get("ai_score"),
            "threat_level": c.get("threat_level"),
            "founded_year": c.get("founded_year"),
            "headquarters": c.get("headquarters"),
            "funding": c.get("funding"),
            "key_features": c.get("key_features", []),
            "our_overlap_score": c.get("our_overlap_score"),
            "reviewed": False,
            "promoted": False,
            "discovery_week": week_str,
            "raw_gemini_output": json.dumps(c, ensure_ascii=False),
        }
        payload = {k: v for k, v in payload.items() if v is not None}

        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        req = urllib.request.Request(
            f"{supabase_url}/rest/v1/competitor_candidates",
            data=data,
            headers={
                "apikey": service_key,
                "Authorization": f"Bearer {service_key}",
                "Content-Type": "application/json",
                "Prefer": "resolution=ignore-duplicates,return=minimal",
            },
            method="POST",
        )
        try:
            with opener(req):
                new_count += 1
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", errors="replace")
            if "23505" in body or "duplicate" in body.lower():
                skip_count += 1
            else:
                msg = f"INSERT error for {cid}: {body[:200]}"
                print(f"WARNING {msg}")
                error_logs.append(msg)
                error_count += 1
        except Exception as e:
            msg = f"INSERT exception for {cid}: {str(e)[:200]}"
            print(f"WARNING {msg}")
            error_logs.append(msg)
            error_count += 1

    return new_count, skip_count, error_count, error_logs


def build_discovery_log_payload(
    *,
    discovery_log: dict[str, Any] | None,
    week_str: str,
    run_id: str | None,
    total_candidates: int,
    staged_count: int,
    skip_count: int,
    stage_error_count: int,
    stage_error_logs: list[str],
) -> dict[str, Any]:
    base = discovery_log or {}
    discover_errors = list(base.get("error_logs") or [])
    merged_errors = discover_errors + stage_error_logs
    total_errors = int(base.get("error_count") or len(discover_errors)) + stage_error_count
    zero_alert = total_candidates == 0 or staged_count == 0
    if total_candidates == 0:
        alert_summary = (
            f"Week {week_str}: 0 candidates returned by discovery (errors={total_errors})"
        )
    elif staged_count == 0:
        alert_summary = (
            f"Week {week_str}: {total_candidates} candidates found but 0 newly staged (skipped={skip_count}, errors={total_errors})"
        )
    else:
        alert_summary = None

    return {
        "discovery_week": str(base.get("discovery_week") or week_str),
        "run_id": run_id or None,
        "categories": list(base.get("categories") or []),
        "queries_json": list(base.get("queries_json") or []),
        "total_candidates": total_candidates,
        "staged_count": staged_count,
        "skip_count": skip_count,
        "error_count": total_errors,
        "error_logs": merged_errors,
        "zero_result_alert_triggered": zero_alert,
        "alert_summary": alert_summary,
    }


def persist_discovery_log(
    *,
    supabase_url: str,
    service_key: str,
    log_payload: dict[str, Any],
    opener: Callable[..., Any] = urllib.request.urlopen,
) -> bool:
    data = json.dumps(log_payload, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(
        f"{supabase_url}/rest/v1/competitor_discovery_logs",
        data=data,
        headers={
            "apikey": service_key,
            "Authorization": f"Bearer {service_key}",
            "Content-Type": "application/json",
            "Prefer": "return=minimal",
        },
        method="POST",
    )
    try:
        with opener(req, timeout=20):
            return True
    except Exception as e:
        print(f"WARNING failed to persist competitor_discovery_logs: {str(e)[:200]}")
        return False


def main() -> int:
    supabase_url = os.environ["SUPABASE_URL"].rstrip("/")
    service_key = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
    candidates_path = os.environ.get("CANDIDATES_PATH", "/tmp/all_candidates.json")
    existing_path = os.environ.get("EXISTING_PATH", "/tmp/existing_competitors.json")
    discovery_log_path = os.environ.get("DISCOVERY_LOG_PATH", "/tmp/discovery_log.json")
    run_id = os.environ.get("GITHUB_RUN_ID", "").strip()

    with open(candidates_path, encoding="utf-8") as f:
        candidates = json.load(f)
    with open(existing_path, encoding="utf-8") as f:
        existing = json.load(f)

    discovery_log: dict[str, Any] | None = None
    if discovery_log_path and os.path.exists(discovery_log_path):
        try:
            with open(discovery_log_path, encoding="utf-8") as f:
                loaded = json.load(f)
                if isinstance(loaded, dict):
                    discovery_log = loaded
        except Exception as e:
            print(f"WARNING unreadable discovery log at {discovery_log_path}: {e}")

    week_str = dt.datetime.now(dt.timezone.utc).date().strftime("%G-%V")
    new_count, skip_count, error_count, stage_errors = stage_candidates(
        supabase_url=supabase_url,
        service_key=service_key,
        candidates=candidates,
        existing=existing,
        week_str=week_str,
    )

    log_payload = build_discovery_log_payload(
        discovery_log=discovery_log,
        week_str=week_str,
        run_id=run_id,
        total_candidates=len(candidates),
        staged_count=new_count,
        skip_count=skip_count,
        stage_error_count=error_count,
        stage_error_logs=stage_errors,
    )
    persist_discovery_log(
        supabase_url=supabase_url,
        service_key=service_key,
        log_payload=log_payload,
    )

    zero_alert = bool(log_payload["zero_result_alert_triggered"])
    if zero_alert and log_payload.get("alert_summary"):
        print(f"::warning::{log_payload['alert_summary']}")

    print(f"Staged: {new_count} new | Skipped: {skip_count} | Errors: {log_payload['error_count']}")

    github_output = os.environ.get("GITHUB_OUTPUT", "/dev/null")
    single_summary = str(log_payload.get("alert_summary") or "").replace("\n", " ")
    with open(github_output, "a", encoding="utf-8") as f:
        f.write(f"staged_count={new_count}\n")
        f.write(f"skip_count={skip_count}\n")
        f.write(f"error_count={log_payload['error_count']}\n")
        f.write(f"zero_result_alert={'true' if zero_alert else 'false'}\n")
        f.write(f"alert_summary={single_summary}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
