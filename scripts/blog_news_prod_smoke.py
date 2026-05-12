#!/usr/bin/env python3
"""Production smoke checks for the blog/news automation surface.

The script intentionally keeps write-side checks optional. Public route and RSS
Edge Function checks can run on every production deploy, while service-role
checks only read blog_posts queue state when the secret is available.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any


DEFAULT_SITE_URL = "https://my-web-app-b67f4.web.app"
DEFAULT_SUPABASE_URL = "https://smmkxxavexumewbfaqpy.supabase.co"
DEFAULT_RSS_FEEDS = [
    {
        "title": "Google AI Blog",
        "url": "https://blog.google/technology/ai/rss/",
        "category": "AI",
    },
    {
        "title": "OpenAI News",
        "url": "https://openai.com/news/rss.xml",
        "category": "AI",
    },
]
APP_MARKERS = ("flutter_bootstrap.js", "main.dart.js", "自分株式会社")


@dataclass
class SmokeCheck:
    name: str
    status: str
    details: dict[str, Any]


def normalize_base_url(value: str) -> str:
    return value.rstrip("/")


def check(name: str, status: str, **details: Any) -> SmokeCheck:
    return SmokeCheck(name=name, status=status, details=details)


def request_text(url: str, timeout: int) -> tuple[int, str, str]:
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "my-web-app-blog-news-prod-smoke/1.0"},
    )
    with urllib.request.urlopen(req, timeout=timeout) as response:
        body = response.read().decode("utf-8", errors="replace")
        content_type = response.headers.get("content-type", "")
        return int(response.status), content_type, body


def request_json(
    url: str,
    payload: dict[str, Any] | None,
    headers: dict[str, str],
    timeout: int,
    method: str | None = None,
) -> tuple[int, dict[str, Any] | list[Any]]:
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers=headers,
        method=method or ("POST" if payload is not None else "GET"),
    )
    with urllib.request.urlopen(req, timeout=timeout) as response:
        raw = response.read().decode("utf-8", errors="replace")
        parsed = json.loads(raw) if raw.strip() else {}
        return int(response.status), parsed


def load_anon_key(repo_root: Path) -> str:
    env_key = os.environ.get("SUPABASE_ANON_KEY", "").strip()
    if env_key:
        return env_key
    main_dart = repo_root / "lib" / "main.dart"
    if not main_dart.exists():
        return ""
    text = main_dart.read_text(encoding="utf-8", errors="replace")
    match = re.search(r"anonKey:\s*[\r\n\s]*'([^']+)'", text)
    return match.group(1).strip() if match else ""


def check_public_routes(site_url: str, timeout: int, post_id: str = "") -> list[SmokeCheck]:
    routes = [
        ("blog_index", "/blog"),
        ("blog_compose", "/blog/compose"),
        ("news_rss", "/news-rss"),
    ]
    if post_id:
        routes.append(("blog_post", f"/blog/post?id={urllib.parse.quote(post_id)}"))

    checks: list[SmokeCheck] = []
    for name, route in routes:
        url = f"{normalize_base_url(site_url)}{route}"
        try:
            status, content_type, body = request_text(url, timeout)
        except urllib.error.HTTPError as exc:
            checks.append(check(name, "fail", url=url, http_status=exc.code))
            continue
        except Exception as exc:  # pragma: no cover - exact transport errors vary.
            checks.append(check(name, "fail", url=url, error=str(exc)))
            continue

        has_marker = any(marker in body for marker in APP_MARKERS)
        if status != 200 or "text/html" not in content_type.lower() or not has_marker:
            checks.append(
                check(
                    name,
                    "fail",
                    url=url,
                    http_status=status,
                    content_type=content_type,
                    app_marker=has_marker,
                )
            )
        else:
            checks.append(
                check(
                    name,
                    "pass",
                    url=url,
                    http_status=status,
                    content_type=content_type,
                )
            )
    return checks


def service_headers(key: str) -> dict[str, str]:
    return {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    }


def query_blog_queue_state(
    supabase_url: str,
    service_key: str,
    timeout: int,
) -> tuple[list[SmokeCheck], str]:
    if not service_key:
        return [
            check(
                "blog_posts_queue_read",
                "warn",
                reason="SUPABASE_SERVICE_ROLE_KEY not provided; skipped read-only queue smoke.",
            )
        ], ""

    base = normalize_base_url(supabase_url)
    headers = service_headers(service_key)
    checks: list[SmokeCheck] = []
    latest_post_id = ""

    latest_url = (
        f"{base}/rest/v1/blog_posts?"
        "select=id,title,status,created_at&status=in.(posted,published)"
        "&order=created_at.desc&limit=1"
    )
    ready_url = (
        f"{base}/rest/v1/blog_posts?"
        "select=id,title,status,created_at&status=eq.ready"
        "&order=created_at.asc&limit=5"
    )

    try:
        latest_status, latest_rows = request_json(
            latest_url,
            payload=None,
            headers=headers,
            timeout=timeout,
            method="GET",
        )
        if isinstance(latest_rows, list) and latest_rows:
            first = latest_rows[0]
            if isinstance(first, dict):
                latest_post_id = str(first.get("id") or "")
        checks.append(
            check(
                "blog_posts_latest_post_read",
                "pass",
                http_status=latest_status,
                found=bool(latest_post_id),
            )
        )
    except Exception as exc:
        checks.append(check("blog_posts_latest_post_read", "fail", error=str(exc)))

    try:
        ready_status, ready_rows = request_json(
            ready_url,
            payload=None,
            headers=headers,
            timeout=timeout,
            method="GET",
        )
        ready_count = len(ready_rows) if isinstance(ready_rows, list) else 0
        checks.append(
            check(
                "blog_posts_ready_queue_read",
                "pass",
                http_status=ready_status,
                ready_count=ready_count,
            )
        )
    except Exception as exc:
        checks.append(check("blog_posts_ready_queue_read", "fail", error=str(exc)))

    return checks, latest_post_id


def check_rss_fetch(
    supabase_url: str,
    anon_key: str,
    timeout: int,
    feeds: list[dict[str, str]],
) -> SmokeCheck:
    if not anon_key:
        return check(
            "rss_fetch_latest",
            "warn",
            reason="SUPABASE_ANON_KEY not provided and could not be read from lib/main.dart.",
        )
    endpoint = f"{normalize_base_url(supabase_url)}/functions/v1/tools-hub"
    payload = {
        "action": "rss.fetch_latest",
        "feeds": feeds,
        "per_feed_limit": 3,
        "limit": 8,
        "signal_limit": 4,
    }
    try:
        status, data = request_json(
            endpoint,
            payload=payload,
            headers=service_headers(anon_key),
            timeout=timeout,
        )
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        return check(
            "rss_fetch_latest",
            "fail",
            http_status=exc.code,
            error=body[:500],
        )
    except Exception as exc:  # pragma: no cover - exact transport errors vary.
        return check("rss_fetch_latest", "fail", error=str(exc))

    if not isinstance(data, dict) or data.get("success") is not True:
        return check("rss_fetch_latest", "fail", http_status=status, response=data)

    item_count = len(data.get("items") or [])
    signal_count = len(data.get("signals") or [])
    error_count = len(data.get("errors") or [])
    status_name = "pass" if item_count > 0 else "warn"
    return check(
        "rss_fetch_latest",
        status_name,
        http_status=status,
        source_count=data.get("source_count"),
        item_count=item_count,
        signal_count=signal_count,
        error_count=error_count,
    )


def build_report(args: argparse.Namespace) -> dict[str, Any]:
    repo_root = Path(args.repo_root)
    service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    anon_key = load_anon_key(repo_root)
    checks: list[SmokeCheck] = []

    queue_checks, latest_post_id = query_blog_queue_state(
        args.supabase_url,
        service_key,
        args.timeout,
    )
    checks.extend(queue_checks)
    checks.extend(check_public_routes(args.site_url, args.timeout, latest_post_id))
    if not args.skip_rss:
        checks.append(
            check_rss_fetch(
                args.supabase_url,
                anon_key,
                args.timeout,
                DEFAULT_RSS_FEEDS,
            )
        )

    failures = [item for item in checks if item.status == "fail"]
    return {
        "status": "fail" if failures else "pass",
        "site_url": normalize_base_url(args.site_url),
        "supabase_url": normalize_base_url(args.supabase_url),
        "checks": [asdict(item) for item in checks],
    }


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--site-url", default=os.environ.get("SITE_URL", DEFAULT_SITE_URL))
    parser.add_argument(
        "--supabase-url",
        default=os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL),
    )
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--timeout", type=int, default=20)
    parser.add_argument("--skip-rss", action="store_true")
    parser.add_argument("--report", default="")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    report = build_report(args)
    text = json.dumps(report, ensure_ascii=False, indent=2)
    print(text)
    if args.report:
        report_path = Path(args.report)
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(text + "\n", encoding="utf-8")
    return 0 if report["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
