#!/usr/bin/env python3
"""Subdivide stale WBS tasks into smaller child tasks.

This script is designed for GitHub Actions. It intentionally uses only the
Python standard library so the scheduled workflow can run without dependency
installation. Missing credentials produce a clean no-op instead of a failed
workflow.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import sys
import textwrap
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Any


UTC = dt.timezone.utc
DEFAULT_SUPABASE_URL = "https://smmkxxavexumewbfaqpy.supabase.co"
DEFAULT_GEMINI_MODEL = "gemini-2.5-flash"
MAX_GENERATED_SUBTASKS = 7


@dataclass(frozen=True)
class HttpResult:
    status: int
    body: str


def utc_now() -> dt.datetime:
    return dt.datetime.now(UTC).replace(microsecond=0)


def parse_iso_datetime(value: Any) -> dt.datetime | None:
    if not value:
        return None
    raw = str(value).strip()
    if not raw:
        return None
    try:
        parsed = dt.datetime.fromisoformat(raw.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC)


def clamp_int(value: Any, *, minimum: int, maximum: int, default: int) -> int:
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        return default
    return max(minimum, min(maximum, parsed))


def json_from_llm_text(text: str) -> dict[str, Any]:
    cleaned = text.strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\s*```$", "", cleaned)
    match = re.search(r"\{.*\}", cleaned, flags=re.DOTALL)
    if match:
        cleaned = match.group(0)
    data = json.loads(cleaned)
    if not isinstance(data, dict):
        raise ValueError("Gemini response was not a JSON object")
    return data


def build_gemini_prompt(task: dict[str, Any]) -> str:
    return textwrap.dedent(
        f"""
        You are a pragmatic project manager for Jibun Kaisha.
        A WBS task has made no visible progress past its stale threshold.
        Identify the likely stall reason and split the task into 3 to 7
        smaller execution tasks that can each finish in 1 to 3 days.

        Parent task:
        - title: {task.get("title", "")}
        - description: {task.get("description") or "(none)"}
        - category: {task.get("category", "")}
        - instance: {task.get("instance", "")}
        - owner_instance: {task.get("owner_instance", "")}
        - progress: {task.get("progress", 0)}%
        - start_date: {task.get("start_date")}
        - end_date: {task.get("end_date")}
        - remaining_work: {task.get("remaining_work") or "(none)"}

        Return only JSON, no markdown:
        {{
          "stall_reason": "short reason, 200 chars max",
          "sub_tasks": [
            {{
              "title": "clear next action",
              "description": "specific output and acceptance check",
              "estimated_days": 1,
              "priority": "high"
            }}
          ]
        }}
        """
    ).strip()


def http_request(
    url: str,
    *,
    method: str = "GET",
    headers: dict[str, str] | None = None,
    data: Any | None = None,
    timeout: int = 30,
    allow_status: tuple[int, ...] = (200, 201, 204),
) -> HttpResult:
    body: bytes | None = None
    request_headers = dict(headers or {})
    if data is not None:
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        request_headers.setdefault("Content-Type", "application/json")
    request = urllib.request.Request(
        url,
        data=body,
        headers=request_headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            status = int(getattr(response, "status", 200))
            raw = response.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as exc:
        status = int(exc.code)
        raw = exc.read().decode("utf-8", errors="replace")
    if status not in allow_status:
        raise RuntimeError(f"HTTP {status} from {url}: {raw[:500]}")
    return HttpResult(status=status, body=raw)


def supabase_headers(service_key: str, *, prefer: str | None = None) -> dict[str, str]:
    headers = {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
    }
    if prefer:
        headers["Prefer"] = prefer
    return headers


def fetch_open_wbs_tasks(
    supabase_url: str,
    service_key: str,
    *,
    max_fetch: int,
) -> list[dict[str, Any]]:
    params = {
        "status": "eq.in_progress",
        "progress": "lt.100",
        "select": ",".join(
            [
                "id",
                "category",
                "category_icon",
                "category_order",
                "title",
                "description",
                "instance",
                "owner_instance",
                "status",
                "progress",
                "start_date",
                "end_date",
                "planned_end_date",
                "milestone_code",
                "priority",
                "remaining_work",
                "updated_at",
                "auto_subdivided_at",
                "stale_threshold_hours",
                "ai_review_status",
            ]
        ),
        "order": "updated_at.asc",
        "limit": str(max_fetch),
    }
    url = f"{supabase_url.rstrip('/')}/rest/v1/wbs_tasks?{urllib.parse.urlencode(params)}"
    result = http_request(url, headers=supabase_headers(service_key), timeout=20)
    data = json.loads(result.body or "[]")
    if not isinstance(data, list):
        raise RuntimeError("Supabase did not return a task list")
    return [item for item in data if isinstance(item, dict)]


def is_stale_candidate(
    task: dict[str, Any],
    *,
    now: dt.datetime,
    include_ai_review_skip: bool = False,
) -> bool:
    if task.get("status") != "in_progress":
        return False
    if clamp_int(task.get("progress"), minimum=0, maximum=100, default=0) >= 100:
        return False
    if not include_ai_review_skip and task.get("ai_review_status") == "skip":
        return False

    updated_at = parse_iso_datetime(task.get("updated_at"))
    if updated_at is None:
        return False
    threshold_hours = clamp_int(
        task.get("stale_threshold_hours"),
        minimum=6,
        maximum=720,
        default=24,
    )
    if updated_at > now - dt.timedelta(hours=threshold_hours):
        return False

    auto_subdivided_at = parse_iso_datetime(task.get("auto_subdivided_at"))
    if auto_subdivided_at and auto_subdivided_at > now - dt.timedelta(days=7):
        return False

    return True


def normalize_subtasks(ai: dict[str, Any]) -> tuple[str, list[dict[str, Any]]]:
    stall_reason = str(ai.get("stall_reason") or "No stall reason returned").strip()
    raw_items = ai.get("sub_tasks")
    if not isinstance(raw_items, list):
        raise ValueError("Gemini response missing sub_tasks list")
    normalized: list[dict[str, Any]] = []
    for raw in raw_items[:MAX_GENERATED_SUBTASKS]:
        if not isinstance(raw, dict):
            continue
        title = str(raw.get("title") or "").strip()
        if not title:
            continue
        priority = str(raw.get("priority") or "medium").strip().lower()
        if priority not in {"high", "medium", "low"}:
            priority = "medium"
        normalized.append(
            {
                "title": title[:160],
                "description": str(raw.get("description") or "").strip()[:1200],
                "estimated_days": clamp_int(
                    raw.get("estimated_days"),
                    minimum=1,
                    maximum=3,
                    default=1,
                ),
                "priority": priority,
            }
        )
    if len(normalized) < 3:
        raise ValueError("Gemini returned fewer than 3 usable subtasks")
    return stall_reason[:300], normalized


def call_gemini(
    gemini_key: str,
    task: dict[str, Any],
    *,
    model: str,
) -> tuple[str, list[dict[str, Any]]]:
    prompt = build_gemini_prompt(task)
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.2,
            "maxOutputTokens": 1600,
            "responseMimeType": "application/json",
        },
    }
    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"{urllib.parse.quote(model)}:generateContent?key={urllib.parse.quote(gemini_key)}"
    )
    result = http_request(url, method="POST", data=payload, timeout=45)
    data = json.loads(result.body)
    text = (
        data.get("candidates", [{}])[0]
        .get("content", {})
        .get("parts", [{}])[0]
        .get("text", "")
    )
    if not text:
        raise RuntimeError("Gemini returned no text")
    return normalize_subtasks(json_from_llm_text(text))


def child_title(parent_title: str, subtask_title: str, index: int) -> str:
    base = f"{parent_title} / {subtask_title}".strip()
    if len(base) <= 180:
        return base
    suffix = f" / step {index}"
    return f"{base[:180 - len(suffix)]}{suffix}"


def child_due_date(now: dt.datetime, estimated_days: int) -> str:
    return (now.date() + dt.timedelta(days=estimated_days)).isoformat()


def build_child_payload(
    parent: dict[str, Any],
    subtask: dict[str, Any],
    *,
    index: int,
    count: int,
    stall_reason: str,
    now: dt.datetime,
    trace_id: str,
) -> dict[str, Any]:
    due_date = child_due_date(now, int(subtask["estimated_days"]))
    description = textwrap.dedent(
        f"""
        {subtask.get("description") or "Complete this child task."}

        Parent WBS: {parent.get("title", "")}
        Stall reason: {stall_reason}
        Generated by wbs-stale-subdivide run {trace_id}, child {index}/{count}.
        """
    ).strip()
    return {
        "category": parent.get("category") or "wbs",
        "category_icon": parent.get("category_icon") or "[]",
        "category_order": parent.get("category_order") or 99,
        "title": child_title(str(parent.get("title") or ""), str(subtask["title"]), index),
        "description": description,
        "instance": parent.get("instance") or "win",
        "owner_instance": parent.get("owner_instance") or parent.get("instance") or "win",
        "status": "pending",
        "progress": 0,
        "priority": subtask.get("priority") or parent.get("priority") or "medium",
        "start_date": now.date().isoformat(),
        "end_date": due_date,
        "planned_end_date": due_date,
        "remaining_work": "Generated child task; complete and report progress through WBS.",
        "milestone_code": parent.get("milestone_code"),
        "parent_task_id": parent.get("id"),
        "ai_review_status": "pending",
        "stale_threshold_hours": parent.get("stale_threshold_hours") or 24,
    }


def insert_child_task(
    supabase_url: str,
    service_key: str,
    payload: dict[str, Any],
) -> tuple[bool, str]:
    url = f"{supabase_url.rstrip('/')}/rest/v1/wbs_tasks"
    result = http_request(
        url,
        method="POST",
        headers=supabase_headers(service_key, prefer="return=representation"),
        data=payload,
        timeout=20,
        allow_status=(200, 201, 409),
    )
    if result.status == 409:
        return False, "duplicate"
    try:
        data = json.loads(result.body or "[]")
        if isinstance(data, list) and data:
            return True, str(data[0].get("id") or "")
    except json.JSONDecodeError:
        pass
    return True, ""


def patch_parent_after_subdivide(
    supabase_url: str,
    service_key: str,
    parent_id: str,
    *,
    now: dt.datetime,
    child_count: int,
    stall_reason: str,
    trace_id: str,
) -> None:
    params = urllib.parse.urlencode({"id": f"eq.{parent_id}"})
    url = f"{supabase_url.rstrip('/')}/rest/v1/wbs_tasks?{params}"
    patch = {
        "auto_subdivided_at": now.isoformat().replace("+00:00", "Z"),
        "remaining_work": (
            f"Auto-subdivided into {child_count} child task(s) by "
            f"wbs-stale-subdivide run {trace_id}. Stall reason: {stall_reason}"
        )[:1000],
    }
    http_request(
        url,
        method="PATCH",
        headers=supabase_headers(service_key, prefer="return=minimal"),
        data=patch,
        timeout=20,
        allow_status=(200, 204),
    )


def append_step_summary(lines: list[str]) -> None:
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not path:
        return
    try:
        with open(path, "a", encoding="utf-8") as handle:
            handle.write("\n".join(lines) + "\n")
    except OSError:
        pass


def run_subdivide(args: argparse.Namespace) -> int:
    supabase_url = (os.environ.get("SUPABASE_URL") or DEFAULT_SUPABASE_URL).rstrip("/")
    service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
    gemini_key = os.environ.get("GEMINI_API_KEY", "")
    trace_id = os.environ.get("GITHUB_RUN_ID") or f"local-{utc_now().strftime('%Y%m%d%H%M%S')}"
    now = utc_now()

    if not service_key or not gemini_key:
        print("skip: SUPABASE_SERVICE_ROLE_KEY or GEMINI_API_KEY is missing")
        append_step_summary(["## WBS stale subdivide", "", "Skipped: missing secrets."])
        return 0

    fetched = fetch_open_wbs_tasks(supabase_url, service_key, max_fetch=args.max_fetch)
    candidates = [
        task
        for task in fetched
        if is_stale_candidate(
            task,
            now=now,
            include_ai_review_skip=args.include_ai_review_skip,
        )
    ][: args.max_tasks]

    print(f"fetched={len(fetched)} stale_candidates={len(candidates)} max_tasks={args.max_tasks}")
    if not candidates:
        append_step_summary(["## WBS stale subdivide", "", "No stale candidates found."])
        return 0

    parents_done = 0
    children_created = 0
    duplicates = 0
    errors = 0
    summary_lines = ["## WBS stale subdivide", ""]

    for task in candidates:
        parent_id = str(task.get("id") or "")
        parent_title = str(task.get("title") or parent_id)
        print(f"\nparent={parent_id} title={parent_title}")
        try:
            stall_reason, subtasks = call_gemini(
                gemini_key,
                task,
                model=args.gemini_model,
            )
            print(f"stall_reason={stall_reason}")
            created_for_parent = 0
            for index, subtask in enumerate(subtasks, start=1):
                payload = build_child_payload(
                    task,
                    subtask,
                    index=index,
                    count=len(subtasks),
                    stall_reason=stall_reason,
                    now=now,
                    trace_id=trace_id,
                )
                if args.dry_run:
                    print(f"dry-run child {index}: {payload['title']}")
                    created = True
                    status = "dry-run"
                else:
                    created, status = insert_child_task(supabase_url, service_key, payload)
                    print(f"child {index}: {payload['title']} -> {status or 'created'}")
                if created:
                    created_for_parent += 1
                    children_created += 1
                else:
                    duplicates += 1

            if not args.dry_run and created_for_parent:
                patch_parent_after_subdivide(
                    supabase_url,
                    service_key,
                    parent_id,
                    now=now,
                    child_count=created_for_parent,
                    stall_reason=stall_reason,
                    trace_id=trace_id,
                )
            parents_done += 1
            summary_lines.append(
                f"- {parent_title}: {created_for_parent} child task(s), reason: {stall_reason}"
            )
        except Exception as exc:  # noqa: BLE001 - cron should continue per parent
            errors += 1
            print(f"error: parent {parent_id}: {exc}", file=sys.stderr)
            summary_lines.append(f"- ERROR {parent_title}: {exc}")

    summary_lines.extend(
        [
            "",
            f"Parents processed: {parents_done}",
            f"Children created: {children_created}",
            f"Duplicates skipped: {duplicates}",
            f"Errors: {errors}",
            f"Dry run: {args.dry_run}",
        ]
    )
    append_step_summary(summary_lines)
    print("\nsummary:")
    print(f"parents_done={parents_done}")
    print(f"children_created={children_created}")
    print(f"duplicates={duplicates}")
    print(f"errors={errors}")
    return 1 if errors and parents_done == 0 else 0


def run_self_test() -> int:
    now = dt.datetime(2026, 5, 2, 0, 0, tzinfo=UTC)
    task = {
        "id": "00000000-0000-0000-0000-000000000001",
        "title": "Parent task",
        "category": "business-product",
        "instance": "win",
        "owner_instance": "win",
        "status": "in_progress",
        "progress": 20,
        "updated_at": "2026-04-30T00:00:00Z",
        "auto_subdivided_at": None,
        "stale_threshold_hours": 24,
        "ai_review_status": "pending",
    }
    assert is_stale_candidate(task, now=now)
    recent = dict(task, updated_at="2026-05-01T12:30:00Z")
    assert not is_stale_candidate(recent, now=now)
    already = dict(task, auto_subdivided_at="2026-05-01T00:00:00Z")
    assert not is_stale_candidate(already, now=now)
    parsed = json_from_llm_text(
        """```json
        {"stall_reason":"too broad","sub_tasks":[
          {"title":"A","description":"one","estimated_days":1,"priority":"high"},
          {"title":"B","description":"two","estimated_days":2,"priority":"medium"},
          {"title":"C","description":"three","estimated_days":3,"priority":"low"}
        ]}
        ```"""
    )
    reason, subtasks = normalize_subtasks(parsed)
    assert reason == "too broad"
    assert len(subtasks) == 3
    payload = build_child_payload(
        task,
        subtasks[0],
        index=1,
        count=3,
        stall_reason=reason,
        now=now,
        trace_id="self-test",
    )
    assert payload["parent_task_id"] == task["id"]
    assert payload["end_date"] == "2026-05-03"
    assert "Parent WBS" in payload["description"]
    print("self-test ok")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--max-tasks", type=int, default=int(os.environ.get("MAX_TASKS", "5")))
    parser.add_argument("--max-fetch", type=int, default=int(os.environ.get("MAX_FETCH", "100")))
    parser.add_argument("--gemini-model", default=os.environ.get("GEMINI_MODEL", DEFAULT_GEMINI_MODEL))
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--include-ai-review-skip", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)
    args.max_tasks = max(1, min(20, args.max_tasks))
    args.max_fetch = max(args.max_tasks, min(500, args.max_fetch))
    return args


def main(argv: list[str]) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    args = parse_args(argv)
    if args.self_test:
        return run_self_test()
    return run_subdivide(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
