#!/usr/bin/env python3
"""Local availability probe for active competitors using anon key (public-read RLS).

Standalone version of competitor-monitoring.yml Step 3, runnable when
SUPABASE_SERVICE_ROLE_KEY is unavailable in local PS#4 sessions.
"""
import json
import os
import re
import sys
import time
import urllib.request
import urllib.error

SUPABASE_URL = "https://smmkxxavexumewbfaqpy.supabase.co"
TIMEOUT_SEC = 10
USER_AGENT = "Mozilla/5.0 (compatible)"


def extract_anon_key() -> str:
    """Extract anon key from lib/main.dart (matches `eyJ...` JWT pattern)."""
    main_dart = os.path.join(
        os.path.dirname(__file__), "..", "lib", "main.dart"
    )
    main_dart = os.path.normpath(main_dart)
    with open(main_dart, encoding="utf-8") as f:
        content = f.read()
    m = re.search(r"eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+", content)
    if not m:
        sys.exit("ERROR: anon key not found in lib/main.dart")
    return m.group(0)


def fetch_competitors(anon_key: str) -> list:
    url = (
        f"{SUPABASE_URL}/rest/v1/competitors"
        "?select=display_name,website,website_url,threat_level"
        "&is_active=eq.true&limit=500"
    )
    req = urllib.request.Request(
        url,
        headers={
            "apikey": anon_key,
            "Authorization": f"Bearer {anon_key}",
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=TIMEOUT_SEC) as resp:
        return json.load(resp)


def probe(url: str) -> int:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_SEC) as resp:
            return resp.status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception:
        return 0


TIER_MAP = {"high": "🔴", "medium": "🟠", "low": "🟡"}


def main():
    anon = extract_anon_key()
    comps = fetch_competitors(anon)
    print(f"# Probed at: {time.strftime('%Y-%m-%d %H:%M:%S %Z')}", file=sys.stderr)
    print(f"# Total competitors: {len(comps)}", file=sys.stderr)

    rows = []
    down = 0
    skipped = 0
    for c in comps:
        name = (c.get("display_name") or "?").strip()
        url = (c.get("website_url") or c.get("website") or "").strip()
        if not url:
            skipped += 1
            continue
        tier_code = (c.get("threat_level") or "low").lower()
        tier = TIER_MAP.get(tier_code, "🟡")
        http = probe(url)
        ok = http in (200, 301, 302)
        status = "✅" if ok else "⚠️"
        if not ok:
            down += 1
        rows.append((name, url, http, status, tier))

    # markdown table
    print("| 競合 | URL | HTTP | 状態 | 脅威度 |")
    print("|-----|-----|-----|-----|-----|")
    for name, url, http, status, tier in rows:
        print(f"| {name} | {url} | HTTP {http} | {status} | {tier} |")
    print()
    print(f"_Probed: {len(rows)} sites / Down: {down} / Skipped (no URL): {skipped}_")


if __name__ == "__main__":
    main()
