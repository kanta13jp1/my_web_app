#!/usr/bin/env python3
"""Sync feature changes from web/release-notes.json into Supabase feature_releases.

ホーム「最近追加された機能」セクション (Issue #3279) のデータ供給:
- web/release-notes.json の category == "feature" な change を抽出し、
  feature_releases へ upsert する (on_conflict=source_id で冪等)。
- feature_route は個別 PR から自動判定できないため '/release-notes' 固定
  (タップで Release Notes 詳細へ誘導する)。

Usage:
  python scripts/sync_feature_releases.py --input web/release-notes.json [--dry-run]

Env (required unless --dry-run):
  SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

FEATURE_ROUTE_DEFAULT = "/release-notes"
LABEL_MAX_LEN = 80
SUMMARY_PR_PREFIX_RE = re.compile(r"^#\d+\s+")
SUMMARY_DATE_SUFFIX_RE = re.compile(r"\s*\(\d{4}-\d{2}-\d{2}\)\s*$")
# 上流の classify_change は fix/docs/automation/security 以外を "feature" に
# 落とすため、ユーザー向け機能でない conventional prefix をここで除外する。
NON_FEATURE_PREFIX_RE = re.compile(
    r"^(deps|chore|refactor|style|test|build|ci|revert|docs?)\b[(:!]?"
    r"|^\[CI",
    re.IGNORECASE,
)


def clean_label(summary: str) -> str:
    label = SUMMARY_PR_PREFIX_RE.sub("", summary.strip())
    label = SUMMARY_DATE_SUFFIX_RE.sub("", label)
    if len(label) > LABEL_MAX_LEN:
        label = label[: LABEL_MAX_LEN - 1] + "…"
    return label or summary.strip()


def build_rows(document: dict[str, Any]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    seen: set[str] = set()
    for version in document.get("versions", []):
        for change in version.get("changes", []):
            if change.get("category") != "feature":
                continue
            source_id = str(change.get("id") or "").strip()
            summary = str(change.get("summary") or "").strip()
            merged_at = str(change.get("mergedAt") or "").strip()
            if not source_id or not summary or not merged_at:
                continue
            if NON_FEATURE_PREFIX_RE.match(SUMMARY_PR_PREFIX_RE.sub("", summary)):
                continue
            if source_id in seen:
                continue
            seen.add(source_id)
            links = change.get("links") or []
            url = str(links[0].get("url") or "") if links else ""
            description = summary if not url else f"{summary} ({url})"
            rows.append(
                {
                    "source_id": source_id,
                    "feature_route": FEATURE_ROUTE_DEFAULT,
                    "feature_label": clean_label(summary),
                    "description": description,
                    "released_at": merged_at,
                    "category": "feature",
                }
            )
    return rows


def upsert_rows(rows: list[dict[str, Any]], supabase_url: str, key: str) -> None:
    request = urllib.request.Request(
        f"{supabase_url}/rest/v1/feature_releases?on_conflict=source_id",
        data=json.dumps(rows).encode("utf-8"),
        method="POST",
        headers={
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates,return=minimal",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            response.read()
    except urllib.error.HTTPError as error:
        # PostgREST のエラー本文を残すと失敗時の調査が容易になる。
        detail = error.read().decode("utf-8", errors="replace").strip()
        raise RuntimeError(
            f"upsert failed: HTTP {error.code} {error.reason} {detail}".strip()
        ) from error


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", default="web/release-notes.json")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    document = json.loads(Path(args.input).read_text(encoding="utf-8"))
    rows = build_rows(document)
    print(f"feature changes found: {len(rows)}")
    if args.dry_run:
        print(json.dumps(rows, ensure_ascii=False, indent=2))
        return 0
    if not rows:
        return 0

    supabase_url = os.environ.get("SUPABASE_URL", "").rstrip("/")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
    if not supabase_url or not key:
        print("SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are required", file=sys.stderr)
        return 1
    upsert_rows(rows, supabase_url, key)
    print(f"upserted {len(rows)} rows into feature_releases")
    return 0


if __name__ == "__main__":
    sys.exit(main())
