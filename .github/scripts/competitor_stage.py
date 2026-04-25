#!/usr/bin/env python3
"""
competitor_stage.py - Stage new competitor candidates to Supabase.
Reads /tmp/all_candidates.json and /tmp/existing_competitors.json.
Called by competitor-discovery.yml Step 3.
"""
import json
import os
import subprocess
import urllib.request
import urllib.error

supabase_url = os.environ["SUPABASE_URL"]
service_key = os.environ["SUPABASE_SERVICE_ROLE_KEY"]

with open("/tmp/all_candidates.json") as f:
    candidates = json.load(f)

with open("/tmp/existing_competitors.json") as f:
    existing = json.load(f)

existing_ids = {c.get("id", "").lower() for c in existing}
existing_ids.discard("")
existing_names = {c.get("name", c.get("display_name", "")).lower() for c in existing}
existing_names.discard("")

week_str = subprocess.check_output(["date", "+%Y-%V"]).decode().strip()

new_count = 0
skip_count = 0
error_count = 0

for c in candidates:
    cid = c.get("id", "").lower().replace(" ", "-")
    cname = c.get("display_name", "").lower()

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
        "raw_gemini_output": json.dumps(c),
    }
    payload = {k: v for k, v in payload.items() if v is not None}

    data = json.dumps(payload).encode("utf-8")
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
        with urllib.request.urlopen(req) as resp:
            new_count += 1
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        if "23505" in body or "duplicate" in body.lower():
            skip_count += 1
        else:
            print(f"WARNING INSERT error for {cid}: {body[:200]}")
            error_count += 1

print(f"Staged: {new_count} new | Skipped: {skip_count} | Errors: {error_count}")

github_output = os.environ.get("GITHUB_OUTPUT", "/dev/null")
with open(github_output, "a") as f:
    f.write(f"staged_count={new_count}\n")
    f.write(f"skip_count={skip_count}\n")
