#!/usr/bin/env python3
"""Build one normalized AI University provider catalog from production data."""
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


def normalize_provider_id(value: object) -> str:
    return str(value or "").strip().lower()


def normalized_provider_ids(rows: Iterable[dict]) -> list[str]:
    return sorted(
        {
            provider_id
            for row in rows
            if (provider_id := normalize_provider_id(row.get("provider")))
        }
    )


def fetch_active_provider_rows(
    supabase_url: str,
    anon_key: str,
    *,
    page_size: int = 1000,
) -> list[dict]:
    if not supabase_url.startswith("https://"):
        raise ValueError("SUPABASE_URL must be an HTTPS origin")
    if not anon_key.strip():
        raise ValueError("SUPABASE_PUBLISHABLE_KEY is required")

    rows: list[dict] = []
    offset = 0
    while True:
        query = urllib.parse.urlencode(
            {
                "select": "provider",
                "is_active": "eq.true",
                "order": "provider.asc",
                "limit": page_size,
                "offset": offset,
            }
        )
        request = urllib.request.Request(
            f"{supabase_url.rstrip('/')}/rest/v1/ai_university_content?{query}",
            headers={
                "apikey": anon_key,
                "Authorization": f"Bearer {anon_key}",
                "Accept": "application/json",
                "User-Agent": "my-web-app-ai-university-catalog/1.0",
            },
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            page = json.load(response)
        if not isinstance(page, list):
            raise ValueError("AI University catalog response must be a list")
        rows.extend(page)
        if len(page) < page_size:
            break
        offset += page_size
    return rows


def build_catalog(rows: Iterable[dict], *, generated_at: str | None = None) -> dict:
    provider_ids = normalized_provider_ids(rows)
    if not provider_ids:
        raise ValueError("active AI University provider catalog is empty")
    return {
        "schema_version": 1,
        "source": "public.ai_university_content:is_active=true:provider",
        "normalization": "trim+lowercase+unique",
        "generated_at": generated_at
        or datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "provider_count": len(provider_ids),
        "provider_ids": provider_ids,
    }


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--supabase-url", default=os.getenv("SUPABASE_URL", ""))
    parser.add_argument(
        "--anon-key",
        default=os.getenv("SUPABASE_PUBLISHABLE_KEY", "")
        or os.getenv("SUPABASE_ANON_KEY", ""),
    )
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)

    try:
        catalog = build_catalog(
            fetch_active_provider_rows(args.supabase_url, args.anon_key)
        )
    except Exception as error:
        print(f"AI University catalog snapshot failed: {error}", file=sys.stderr)
        return 1

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(catalog["provider_count"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))