---
title: "Flutter Horse Racing AI Dashboard: EF Hub Actions + NO_AUTH Zone + Promise.all Timeout Fix"
tags: Flutter,Supabase,buildinpublic,Dart,AI
published: true
---

# Flutter Horse Racing AI Dashboard: EF Hub Actions + NO_AUTH Zone + Promise.all Timeout Fix

## What Shipped

[自分株式会社](https://my-web-app-b67f4.web.app/) added a fully automated horse racing prediction pipeline — from race data ingestion to AI prediction to a 3-tab Flutter UI with hit-rate dashboard.

Two architectural highlights worth sharing: the **NO_AUTH action zone** for service-to-service calls, and the **Promise.all timeout fix** for bulk race queries.

---

## Pipeline Architecture

```
[JRA Data Fetch] → [tools-hub EF: horseracing.today]
       ↓
[AI Prediction]  → [tools-hub EF: horseracing.predict_all]
       ↓
[Store Results]  → [Supabase: horse_results table]
       ↓
[Flutter UI]     → [horse_racing_predictor_page.dart]
```

All four actions live in a single `tools-hub` Edge Function — no new EF deployments needed, staying within the 50-EF hard cap.

---

## Edge Function: Action Routing

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

Action routing inside one EF = zero extra cold starts, one CORS config, one deploy step.

---

## NO_AUTH Zone for GitHub Actions

`horseracing.predict_all` is called from a GitHub Actions scheduled workflow — no user JWT available. The initial implementation put it in the `auth` zone, causing 401 errors on every scheduled run.

Fix: add the action to the `NO_AUTH_ACTIONS` list:

```typescript
const NO_AUTH_ACTIONS = ['horseracing.today', 'horseracing.predictions'];
```

Actions in this list bypass JWT validation. They're still protected by Supabase's service-role key requirement at the API gateway level — no user can call them directly without the service key. This is the right pattern for:

- GitHub Actions → Supabase EF (no user in context)
- Cron jobs
- Server-to-server calls

---

## Promise.all Timeout Fix

Initial implementation fetched all race results in a single SELECT:

```typescript
// Before: single bulk query → timeout on large datasets
const { data } = await supabase.from('horse_results').select('*');
```

On days with many races, this hit Deno's 30-second timeout. Fix: parallel queries per race:

```typescript
// After: parallel per-race queries
const results = await Promise.all(
  raceIds.map(id =>
    supabase.from('horse_results').select('*').eq('race_id', id)
  )
);
```

`Promise.all` runs all queries concurrently. Each query is small (one race's data), so all complete within the timeout. The total wall-clock time is bounded by the slowest single query, not the sum.

---

## Flutter: 3-Tab Layout

| Tab | Content |
|-----|---------|
| Today's Races | `ExpansionTile` per race, grade color badge |
| Prediction History | Past AI predictions with date filter |
| Accuracy | Hit rate %, total count, top payout |

### Grade Color Badges

```dart
Color _gradeColor(String grade) {
  return switch (grade) {
    'G1' => Colors.red.shade700,
    'G2' => Colors.blue.shade700,
    'G3' => Colors.green.shade700,
    _    => Colors.grey.shade600,
  };
}
```

Dart 3 `switch` expression — no `break` statements, exhaustive.

### Payout Formatting

```dart
final fmt = NumberFormat('#,###');
Text('¥${fmt.format(payout)}')
```

`NumberFormat('#,###')` from `package:intl` adds comma separators. `¥1,234,500` is readable; `¥1234500` is not.

---

## SQLSTATE 42P10: Missing UNIQUE Constraint

During deploy, `ai_university_content` UPSERT failed with:

```
SQLSTATE 42P10: there is no unique or exclusion constraint matching the ON CONFLICT specification
```

The `ON CONFLICT (provider, category) DO UPDATE` clause requires a `UNIQUE` constraint on those columns. The original migration didn't add it.

Fix:

```sql
ALTER TABLE ai_university_content
  ADD CONSTRAINT ai_university_content_provider_category_key
  UNIQUE (provider, category);
```

Rule: every `ON CONFLICT (col1, col2)` needs `UNIQUE (col1, col2)` or a partial unique index.

---

## Summary

| Pattern | When to Use |
|---------|------------|
| `NO_AUTH_ACTIONS` list | GitHub Actions / cron → EF (no user JWT) |
| `Promise.all` per-ID | Bulk queries that time out as a single SELECT |
| Action routing in hub EF | New features without new EF deployments |
| `ON CONFLICT` + `UNIQUE` | Always add the constraint before the migration runs |

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #Dart #AI
