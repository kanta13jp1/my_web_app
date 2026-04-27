---
title: "Building a Horse Racing AI Pipeline: PostgreSQL + Claude for Automated Race Predictions"
tags: ai,postgresql,automation,indiedev
published: false
---

# Building a Horse Racing AI Pipeline: PostgreSQL + Claude for Automated Race Predictions

For the past six months, I've been building an AI horse racing prediction system. Not a simple "past results → prediction" model — a multi-stage pipeline: data quality management → feature engineering → Claude inference → ranked recommendations.

Here's what I've learned.

## Architecture

```
netkeiba scrape → PostgreSQL (horse_races / horse_entries)
               → fetch_horse_racing.py (daily batch)
               → Supabase Edge Function (ai-hub: horse.predict)
               → Claude haiku (inference)
               → horse_race_predictions_ensemble (results)
               → evaluate_accuracy.ts (weekly evaluation)
```

## Data Quality Score (DQS)

Prediction accuracy is mostly determined by data quality. I score 15 fields to produce a DQS (0-100):

```sql
(
  CASE WHEN weight IS NOT NULL THEN 10 ELSE 0 END +
  CASE WHEN weight_diff IS NOT NULL THEN 10 ELSE 0 END +
  CASE WHEN last_3f IS NOT NULL THEN 15 ELSE 0 END +
  CASE WHEN prev_last_3f IS NOT NULL THEN 10 ELSE 0 END +
  CASE WHEN jockey_id IS NOT NULL THEN 10 ELSE 0 END +
  CASE WHEN trainer_id IS NOT NULL THEN 10 ELSE 0 END +
  CASE WHEN odds IS NOT NULL THEN 15 ELSE 0 END
  -- + 8 more fields...
) AS data_quality_score
```

Entries with DQS < 60 are skipped. This single filter improved accuracy more than any model change.

## Feature Engineering: Ranking Score

Eight factors, weighted by empirical contribution:

| Factor | Weight | Rationale |
|---|---|---|
| Historical place rate | 25% | Most stable signal |
| Final 3F time (last_3f) | 20% | Late speed is predictive |
| Inverse of odds | 15% | Market wisdom |
| Jockey win rate | 15% | Jockey effect is real |
| Weight change | 10% | Condition signal |
| Last 3F vs previous race | 10% | Momentum trend |
| Best time record | 5% | Ceiling indicator |

## Claude Inference Prompt

I use Claude to generate explanations, not just scores:

```typescript
const prompt = `
You are a horse racing prediction specialist.

[RACE INFORMATION]
<<<USER_DATA>>>
${raceInfo}
<<<END>>>

[HORSE DATA]
<<<USER_DATA>>>
${horseData}
<<<END>>>

Recommend top 3 horses considering:
1. Prioritize horses with DQS >= 70
2. Emphasize best time record and final 3F
3. Flag weight changes of ±10kg as risk factors
4. Explain each recommendation in under 100 characters

Output format: JSON
`;
```

The `<<<USER_DATA>>>` blocks protect against prompt injection from scraped race data.

## Solving the N+1 Query Problem

Initial implementation: 2 queries per race × 50 races = 100 queries per evaluation run.

```typescript
// Before: N+1
for (const race of races) {
  const entries = await db.from('horse_entries').eq('race_id', race.id);
  const predictions = await db.from('predictions').eq('race_id', race.id);
}

// After: Batch queries
const raceIds = races.map(r => r.id);
const [allEntries, allPredictions] = await Promise.all([
  db.from('horse_entries').in('race_id', raceIds),
  db.from('predictions').in('race_id', raceIds),
]);

// O(1) lookup via Map
const entriesByRace = new Map(
  raceIds.map(id => [id, allEntries.filter(e => e.race_id === id)])
);
```

100 queries → **3 queries**. Evaluation batch went from 8 minutes to under 1 minute.

## Weekly Accuracy Evaluation

```typescript
type AccuracyResult = {
  total_races: number;
  top3_accuracy: number;   // % races where a placed horse was in top-3 recommendations
  rank1_accuracy: number;  // % races where rank-1 recommendation placed
  avg_dqs: number;         // Average DQS of evaluated races
};
```

The evaluation runs via GitHub Actions every Sunday JST, with results stored in Supabase and surfaced in the admin dashboard.

## Current Numbers

- **top3_accuracy: 52%** (a placed horse appears in the top-3 predictions)
- **rank1_accuracy: 31%** (vs. 20% random baseline)
- **Evaluation scope**: DQS ≥ 70 races only (~60% of all races)

These numbers are for a single track type and surface. Generalization is ongoing work.

## The Core Lesson

The biggest learning from six months of this project: **fix your data pipeline before touching the model**.

The DQS filter alone improved accuracy by 10+ percentage points. Before that, I spent weeks tuning prompt parameters and weights that had almost no effect — because the training/evaluation set was full of incomplete data.

Clean data → simple model → measure → iterate.

The AI reasoning layer (Claude) is genuinely useful for generating explanations that can be audited. But it's the last 20% of the system, not the first.
