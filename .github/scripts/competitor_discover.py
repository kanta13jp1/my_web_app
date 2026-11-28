#!/usr/bin/env python3
"""
competitor_discover.py - Discover trending competitors via Gemini Flash.
Called by competitor-discovery.yml Step 2.
Captures structured query/response/error audit logs (#2696).
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import urllib.error
import urllib.request
from typing import Any, Callable


def redact_api_key(text: str) -> str:
    return re.sub(r"([?&]key=)[^&\s]+", r"\1***", str(text))


def query_gemini_with_log(
    api_key: str,
    category: str,
    max_per_cat: int,
    existing_names_sample: str,
    today: str,
    *,
    opener: Callable[..., Any] = urllib.request.urlopen,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    prompt = (
        f"You are a competitive intelligence analyst for a Japanese AI life-management app. "
        f"Identify {max_per_cat} trending or emerging SaaS/app companies in the '{category}' space "
        f"that have gained traction in the past 30 days (as of {today}). "
        f"EXCLUDE already-known competitors: {existing_names_sample[:500]}\n\n"
        "For each company, return a JSON array (only JSON, no markdown) like:\n"
        '[{"id":"lowercase-hyphen-id","display_name":"Company Name",'
        f'"category":"{category}",'
        '"website":"https://...","description":"Japanese 2-sentence description",'
        '"founded_year":2022,"headquarters":"City, Country","funding":"$XXM Series X",'
        '"key_features":["f1","f2","f3"],"our_overlap_score":5,"threat_level":"medium",'
        '"ai_score":0.7,"reason_trending":"1 sentence"}]\n'
        "Only return the JSON array, nothing else."
    )
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "thinkingConfig": {"thinkingLevel": "LOW"},
            "maxOutputTokens": 65536,
        },
    }
    data = json.dumps(payload).encode("utf-8")
    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"gemini-4-hydrogen:generateContent?key={api_key}"
    )
    req = urllib.request.Request(
        url, data=data, headers={"Content-Type": "application/json"}, method="POST"
    )
    prompt_preview = prompt[:200]
    http_status: int | None = None
    response_excerpt = ""
    error_message: str | None = None
    parsed: list[dict[str, Any]] = []

    try:
        with opener(req, timeout=30) as resp:
            raw_status = getattr(resp, "status", None)
            http_status = int(raw_status) if raw_status is not None else 200
            raw_body = resp.read().decode("utf-8", errors="replace")
        response_excerpt = redact_api_key(raw_body)[:300]
        result = json.loads(raw_body)
        text = (
            result.get("candidates", [{}])[0]
            .get("content", {})
            .get("parts", [{}])[0]
            .get("text", "[]")
        )
        m = re.search(r"\[.*\]", text, re.DOTALL)
        if m:
            loaded = json.loads(m.group())
            if isinstance(loaded, list):
                parsed = [item for item in loaded if isinstance(item, dict)]
    except urllib.error.HTTPError as e:
        http_status = e.code
        try:
            err_body = e.read().decode("utf-8", errors="replace")
        except Exception:
            err_body = str(e)
        error_message = redact_api_key(f"HTTP {e.code}: {err_body}")[:300]
        print(f"WARNING Gemini API HTTP error for {category}: {error_message}")
    except Exception as e:
        error_message = redact_api_key(str(e))[:300]
        print(f"WARNING Gemini API error for {category}: {error_message}")

    query_log = {
        "category": category,
        "prompt_preview": prompt_preview,
        "http_status": http_status,
        "candidate_count": len(parsed),
        "response_excerpt": response_excerpt,
        "error": error_message,
    }
    return parsed, query_log


def query_gemini(
    api_key: str,
    category: str,
    max_per_cat: int,
    existing_names_sample: str,
    today: str,
) -> list[dict[str, Any]]:
    candidates, _ = query_gemini_with_log(
        api_key,
        category,
        max_per_cat,
        existing_names_sample,
        today,
    )
    return candidates


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--categories",
        default="productivity,ai-coding,fintech,ai-platform,e-commerce,health,collaboration,hr-tech,legal-tech,data",
    )
    parser.add_argument("--max-per-cat", type=int, default=5)
    parser.add_argument("--existing", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--output-count", default=None)
    parser.add_argument("--log-output", default=None)
    parser.add_argument("--discovery-week", default="")
    args = parser.parse_args()

    api_key = os.environ["GEMINI_API_KEY"]
    today_date = dt.datetime.now(dt.timezone.utc).date()
    today = today_date.isoformat()
    discovery_week = args.discovery_week.strip() or today_date.strftime("%G-%V")

    with open(args.existing, encoding="utf-8") as f:
        existing = json.load(f)
    existing_names_sample = ", ".join(
        c.get("name", c.get("display_name", "")) for c in existing[:50]
    )

    categories = [c.strip() for c in args.categories.split(",") if c.strip()]
    all_candidates: list[dict[str, Any]] = []
    queries_json: list[dict[str, Any]] = []
    error_logs: list[str] = []

    for category in categories:
        print(f"Querying Gemini for: {category}")
        candidates, query_log = query_gemini_with_log(
            api_key, category, args.max_per_cat, existing_names_sample, today
        )
        print(f"  Got {len(candidates)} candidates")
        all_candidates.extend(candidates)
        queries_json.append(query_log)
        if query_log.get("error"):
            error_logs.append(f"[{category}] {query_log['error']}")

    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(all_candidates, f, ensure_ascii=False)

    total = len(all_candidates)
    print(f"Total candidates: {total}")

    if args.log_output:
        log_payload = {
            "discovery_week": discovery_week,
            "categories": categories,
            "queries_json": queries_json,
            "total_candidates": total,
            "error_count": len(error_logs),
            "error_logs": error_logs,
            "zero_result_alert_triggered": total == 0,
            "alert_summary": (
                f"0 candidates returned across {len(categories)} categories"
                if total == 0
                else ""
            ),
        }
        with open(args.log_output, "w", encoding="utf-8") as f:
            json.dump(log_payload, f, ensure_ascii=False)

    if args.output_count:
        with open(args.output_count, "a", encoding="utf-8") as f:
            f.write(f"total_candidates={total}\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
