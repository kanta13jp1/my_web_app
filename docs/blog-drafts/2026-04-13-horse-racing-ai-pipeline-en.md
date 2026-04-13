---
title: "Building a Fully Automated Horse Racing AI Prediction Pipeline with Flutter + Supabase"
tags: Flutter,Supabase,buildinpublic,MachineLearning,automation
published: false
---

# Building a Fully Automated Horse Racing AI Prediction Pipeline with Flutter + Supabase

## Why Horse Racing?

Horse racing data is rich, structured, and updated daily — a perfect playground for building an automated AI prediction pipeline. I built one into my Flutter Web app, covering both JRA (Japan Racing Association) and NAR (regional tracks, 15 venues).

Here's the full technical breakdown.

---

## Architecture

```
[JRA/NAR Data Fetch]   → fetch_horse_racing.py (Python, EUC-JP decode)
        ↓
[tools-hub Edge Fn]    → horseracing.today / predict_all / predictions / accuracy
        ↓
[Supabase DB]          → horse_races / horse_results tables
        ↓
[GitHub Actions]       → horse-racing-update.yml (every hour)
        ↓
[Flutter UI]           → horse_racing_predictor_page.dart (3-tab layout)
```

---

## Data Fetching: JRA + NAR (15 Regional Tracks)

Python script `fetch_horse_racing.py` handles both JRA and NAR data:

```python
response = requests.get(url, headers=headers, timeout=10)
# Japanese horse racing sites use EUC-JP encoding
# errors='replace' prevents crashes on unknown bytes
content = response.content.decode('euc-jp', errors='replace')
```

**The encoding gotcha**: On Windows, Python defaults to CP932. EUC-JP bytes decoded as CP932 produce garbled text. Using `errors='replace'` stabilizes the decode regardless of system locale — critical since this runs on GitHub Actions (Ubuntu) and local Windows.

---

## Edge Function: Action Dispatch in tools-hub

To stay under the 50 Edge Function hard cap, all horse racing features live as actions inside `tools-hub`:

```typescript
// tools-hub/index.ts
switch (action) {
  case 'horseracing.today':
    return await getHorseRacingToday(supabase);
  case 'horseracing.predict_all':
    return await predictAllRaces(supabase, body);
  case 'horseracing.predictions':
    return await getPredictions(supabase, body);
  case 'horseracing.accuracy':
    return await getAccuracyStats(supabase);
}
```

This is the hub pattern: one deployed function, multiple behaviors via `action` parameter. Currently 16 Edge Functions total (hard cap: 50).

### Auth Zone Design

GitHub Actions calls these endpoints without a user JWT, so `today` and `predictions` are in the no-auth zone:

```typescript
const NO_AUTH_ACTIONS = ['horseracing.today', 'horseracing.predictions'];
```

Originally placed in the auth zone → GitHub Actions got 401. Moving to no-auth fixed it.

### Fixing the 500 Error on horse_results

Fetching all race results in one SELECT timed out on large datasets. Changed to parallel individual queries:

```typescript
// Before: bulk SELECT → timeout
const { data } = await supabase.from('horse_results').select('*');

// After: parallel individual queries → fast
const results = await Promise.all(
  raceIds.map(id =>
    supabase.from('horse_results').select('*').eq('race_id', id)
  )
);
```

---

## GitHub Actions: Hourly Full Pipeline

```yaml
# .github/workflows/horse-racing-update.yml
on:
  schedule:
    - cron: "0 * * * *"  # Every hour

steps:
  - name: Run full pipeline
    run: |
      python fetch_horse_racing.py --mode today    # Fetch today's races
      python fetch_horse_racing.py --mode predict  # Generate AI predictions
      python fetch_horse_racing.py --mode accuracy # Update hit rate stats
```

One job, three phases. Data → Predictions → Stats. Runs every hour automatically.

---

## Flutter UI: 3-Tab Layout

```dart
// horse_racing_predictor_page.dart
TabBar(tabs: [
  Tab(text: 'Today\'s Races'),
  Tab(text: 'Prediction History'),
  Tab(text: 'Accuracy'),
])
```

### Grade Color Badges

```dart
Color _gradeColor(String grade) => switch (grade) {
  'G1' => Colors.red.shade700,
  'G2' => Colors.blue.shade700,
  'G3' => Colors.green.shade700,
  _    => Colors.grey.shade600,
};
```

### Previous Race Info (Latest Addition)

Added horse details to the race card — previous race, weight, age/sex:

```dart
ListTile(
  title: Text('Previous: ${horse.prevRaceName}'),
  subtitle: Text(
    'Previous rank: ${horse.prevRaceRank} | '
    'Weight: ${horse.weight}kg | '
    '${horse.age}yo ${horse.sex}'
  ),
)
```

Schema migration:
```sql
ALTER TABLE horse_races
  ADD COLUMN prev_race_name text,
  ADD COLUMN prev_race_rank int,
  ADD COLUMN horse_weight   int,
  ADD COLUMN horse_age      int,
  ADD COLUMN horse_sex      text;
```

---

## Lessons Learned

| Problem | Root Cause | Fix |
|---------|------------|-----|
| 401 from GitHub Actions | Auth zone restricted the action | Move to `NO_AUTH_ACTIONS` |
| 500 on race results fetch | Bulk SELECT timeout | Parallel individual queries |
| Garbled Japanese text | EUC-JP vs CP932 mismatch | `decode('euc-jp', errors='replace')` |

---

## Current Status

| Feature | Status |
|---------|--------|
| JRA data fetch | ✅ EUC-JP stable |
| NAR regional tracks (15 venues) | ✅ |
| AI prediction generation | ✅ tools-hub EF |
| Hourly auto-update | ✅ GitHub Actions cron |
| Previous race + weight + age | ✅ Added recently |
| Hit rate dashboard | ✅ Flutter 3-tab UI |

The pipeline is fully automated. Data flows from Japanese racing sites → AI predictions → Flutter UI with zero manual intervention.

---

Building in public: https://my-web-app-b67f4.web.app/

#Flutter #Supabase #buildinpublic #automation #MachineLearning
