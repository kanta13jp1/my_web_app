#!/usr/bin/env python3
"""
competitor_discover.py - Discover trending competitors via Gemini Flash.
Called by competitor-discovery.yml Step 2.
"""
import argparse
import json
import os
import re
import subprocess
import urllib.request


def query_gemini(api_key, category, max_per_cat, existing_names_sample, today):
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
        "generationConfig": {"temperature": 0.3, "maxOutputTokens": 2000},
    }
    data = json.dumps(payload).encode("utf-8")
    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"gemini-1.5-flash:generateContent?key={api_key}"
    )
    req = urllib.request.Request(
        url, data=data, headers={"Content-Type": "application/json"}, method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            result = json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        print(f"WARNING Gemini API error for {category}: {e}")
        return []
    text = (
        result.get("candidates", [{}])[0]
        .get("content", {})
        .get("parts", [{}])[0]
        .get("text", "[]")
    )
    m = re.search(r"\[.*\]", text, re.DOTALL)
    if m:
        try:
            return json.loads(m.group())
        except Exception:
            pass
    return []


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--categories",
        default="productivity,ai-coding,fintech,ai-platform,e-commerce,health,collaboration,hr-tech,legal-tech,data",
    )
    parser.add_argument("--max-per-cat", type=int, default=5)
    parser.add_argument("--existing", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--output-count", default=None)
    args = parser.parse_args()

    api_key = os.environ["GEMINI_API_KEY"]
    today = subprocess.check_output(["date", "+%Y-%m-%d"]).decode().strip()

    with open(args.existing) as f:
        existing = json.load(f)
    existing_names_sample = ", ".join(
        c.get("name", c.get("display_name", "")) for c in existing[:50]
    )

    categories = [c.strip() for c in args.categories.split(",")]
    all_candidates = []

    for category in categories:
        print(f"Querying Gemini for: {category}")
        candidates = query_gemini(
            api_key, category, args.max_per_cat, existing_names_sample, today
        )
        print(f"  Got {len(candidates)} candidates")
        all_candidates.extend(candidates)

    with open(args.output, "w") as f:
        json.dump(all_candidates, f)

    total = len(all_candidates)
    print(f"Total candidates: {total}")

    if args.output_count:
        with open(args.output_count, "a") as f:
            f.write(f"total_candidates={total}\n")


if __name__ == "__main__":
    main()
