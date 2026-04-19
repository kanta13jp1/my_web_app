---
title: "How a Japanese Encoding Bug Caused a 36-Minute Infinite Loop in Our Horse Racing Scraper"
tags: Python,Supabase,GitHub Actions,buildinpublic,webdev
published: true
---

# How a Japanese Encoding Bug Caused a 36-Minute Infinite Loop in Our Horse Racing Scraper

## TL;DR

- Japanese regional horse racing (NAR) websites use **EUC-JP** encoding
- Decoding as UTF-8 injects U+FFFD (replacement characters) into race names
- Our "garbled data cleanup" logic deleted those records every hour → EUC-JP re-registration → 535 horses' `prev_history_fetched` flag reset → 17 min history fetch loop
- Found and fixed 3 layered root causes → **36 minutes → 3 minutes (92% reduction)**

---

## Background: Our Horse Racing Data Pipeline

[自分株式会社](https://my-web-app-b67f4.web.app/) uses a GitHub Actions workflow running hourly to fetch JRA (Japan Racing Association) and NAR (National Association of Racing) entry data, then generate AI predictions.

```
horse-racing-update.yml (hourly cron)
  ↓
scripts/fetch_horse_racing.py
  ├── fetch_entries()        # scrape race entries → DB
  ├── fetch_horse_histories() # fetch horse past records
  └── generate_predictions() # AI prediction per race
```

At some point, this workflow started taking **over 36 minutes every hour**. Here's the 3-layer root cause chain we found.

---

## Root Cause Chain: 3 Independent Bugs

### Bug #1: Missing prev_history_fetched Flag (Fixed in Sessions 1-2)

`fetch_horse_histories()` makes one HTTP request per horse to netkeiba.com. Without a flag to track 404 errors (retired/deregistered horses), every hourly run would retry all 1,000+ failed horses.

```python
# Before: no flag set on 404
response = requests.get(f"https://db.netkeiba.com/horse/{horse_id}/")
if response.status_code == 404:
    continue  # ← retried next hour

# After: batch PATCH all 404 horses at once
batch_404_ids.append(horse_id)
# ... at end of function:
supabase.table("horse_entries") \
    .update({"prev_history_fetched": True}) \
    .in_("horse_id", batch_404_ids).execute()
```

### Bug #2: Unconditional time.sleep(1) on Every Horse (Fixed in Session 4)

Rate-limiting sleep was applied even to 404 horses:

```python
# Before
response = requests.get(url)
time.sleep(1)  # ← fires for ALL 1060 404-horses = 17.7 minutes wasted
if response.status_code == 404:
    continue

# After
response = requests.get(url)
if response.status_code == 404:
    batch_404_ids.append(horse_id)
    continue  # no sleep for 404s
time.sleep(1)  # only on successful fetches
```

1,060 retired horses × 1 second = **17.7 minutes of unnecessary waiting**.

### Bug #3: NAR EUC-JP Encoding Loop (Root-fixed in Session 5)

**This was the hardest one to find.**

NAR (regional horse racing) websites use EUC-JP encoding. Python's `requests` library, when you access `response.text`, auto-detects the encoding — and often guesses wrong for Japanese pages, applying UTF-8 or ISO-8859-1 instead.

```python
# Broken code
response = requests.get(nar_url)
html = response.text  # ← decoded as UTF-8 → U+FFFD injected into race names
```

This caused race names like:
```
Stored in DB:  "地\ufffd\ufffd\ufffd競馬\ufffd\ufffd\ufffd"  
Correct value: "地方競馬レース情報"
```

#### The Infinite Loop

Our pipeline had a defensive `_clean_garbled_races()` function:

```python
def _clean_garbled_races():
    """Detect and delete records with U+FFFD (garbled data)"""
    garbled = supabase.table("horse_races") \
        .select("*").like("race_name", "%\ufffd%").execute()
    
    for race in garbled.data:
        supabase.table("horse_entries") \
            .delete().eq("race_id", race["id"]).execute()
        supabase.table("horse_races") \
            .delete().eq("id", race["id"]).execute()
```

The cascade:
1. EUC-JP page decoded as UTF-8 → garbled race names stored
2. `_clean_garbled_races()` deletes the 56 NAR races + their 535 horse entries
3. `fetch_entries()` re-registers the same races (still garbled — still UTF-8)
4. All 535 horses get `prev_history_fetched = false` on re-insert
5. `fetch_horse_histories()` retries all 535 horses → 17+ minutes
6. Go to step 2 next hour

**Every hour, this loop consumed 17+ minutes.**

#### The Fix: Explicitly Decode NAR as EUC-JP

```python
def http_get(url: str) -> str:
    response = requests.get(url, timeout=30)
    raw = response.content  # get raw bytes first
    
    # NAR uses EUC-JP — never let requests guess
    if "nar.netkeiba.com" in url:
        return raw.decode("euc-jp", errors="replace")
    
    # JRA / others use UTF-8
    return raw.decode("utf-8", errors="replace")
```

Key: use `response.content` (bytes) instead of `response.text` (auto-decoded string), then decode manually with the correct codec.

---

## Performance Results

We deployed fixes incrementally and measured each GitHub Actions run duration:

| Stage | Commit | Runtime |
|-------|--------|---------|
| Baseline | — | **36 min** |
| sleep fix (Bug #2) | `52f8b40b` | **12 min** |
| EUC-JP fix (Bug #3) — transition run | `1c8a6113` | 12 min (re-registering 535 horses) |
| EUC-JP fix — stabilized | `1c8a6113` | **3 min** |

**36 minutes → 3 minutes = 92% reduction.**

The transition run (`24628893253`) was expected: it cleaned out the garbled records and re-registered them correctly in EUC-JP. After that single cleanup, subsequent runs had zero records to clean.

For new racing days (first run when new races are registered), we see ~13 minutes — expected, since 59 new NAR races and ~400 new horses need to be fetched for the first time. Second run and beyond: back to 3 minutes.

---

## Key Takeaways

### 1. Old Japanese websites still use EUC-JP

Legacy systems like NAR horse racing are still on EUC-JP in 2026. When scraping Japanese sites, always use `response.content` (bytes) and decode manually:

```python
# Safe pattern
raw = requests.get(url).content
text = raw.decode("euc-jp", errors="replace")  # or utf-8 — be explicit
```

Never rely on `response.text` or `response.apparent_encoding` for Japanese sites.

### 2. "Defensive cleanup" can become an infinite loop

If your input source is consistently broken, a "detect bad data → delete → re-fetch" loop will run forever. The fix is not better detection but fixing the root source of the bad data.

### 3. Multiple bugs compound each other

Three independent bugs meant fixing one didn't make the problem obviously better. Only after all three were fixed did we see the full improvement. Measure each fix separately with timestamps.

### 4. Expect a transition run

The first run after fixing an encoding bug will take longer — it needs to clean and re-register all previously-garbled records. This is expected behavior, not a sign the fix failed.

---

## The App

This pipeline powers the horse racing AI prediction feature in [自分株式会社](https://my-web-app-b67f4.web.app/), a life management app I'm building in public — combining 21 competing SaaS products (Notion, Evernote, MoneyForward, etc.) into one Flutter Web app.

#Python #GithubActions #Supabase #buildinpublic #WebScraping
