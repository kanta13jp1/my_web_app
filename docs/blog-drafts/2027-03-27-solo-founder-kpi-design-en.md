---
title: "Solo Founder KPI Design: The Only Metric That Matters Is Yesterday's You"
tags: ai,indiedev,buildinpublic,automation
published: true
---

# Solo Founder KPI Design: The Only Metric That Matters Is Yesterday's You

"Our MAU is lower than the competitor's." "MRR hasn't hit the target." Evaluating yourself by these metrics will grind you down. Here's how this project measures progress instead — with implementation examples.

## The Problem With Competitor Comparison KPIs

```
Notion: 30 million MAU
This project: 50 MAU

→ Conclusion: "completely failing"
→ But does this comparison mean anything?
```

Notion has 1,000 engineers and $1 billion in funding. A solo founder comparing themselves to that is a child comparing race times to an Olympic sprinter.

## The "Yesterday's You" Frame

```
Right comparison:
  Last week: 40 MAU
  This week: 50 MAU
  → 25% growth ✅

Wrong comparison:
  Competitor: 30M MAU
  You: 50 MAU
  → 0.0002% ❌
```

This project's PHILOSOPHY.md principle: **KPI = yesterday's you**. Measure growth rate, improvement rate, learning velocity.

## Implementation: development_achievements Table

```sql
CREATE TABLE development_achievements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  category TEXT NOT NULL,  -- 'feature' | 'content' | 'infra' | 'learning'
  completed_at DATE NOT NULL,
  session_id TEXT,
  instance_name TEXT
);
```

After every session, record what was accomplished:

```sql
INSERT INTO development_achievements (title, description, category, completed_at, instance_name)
VALUES (
  'T-1 Phase 8 complete: 62 dev.to posts',
  'Flutter PWA / AI University design / worktree / GHA — 4 topics published',
  'content',
  '2026-04-28',
  'ps2'
) ON CONFLICT DO NOTHING;
```

## KPI Dashboard Design

```dart
class SoloFounderKpi {
  final int devAchievementsThisWeek;
  final int devAchievementsLastWeek;
  final int blogPostsTotal;
  final int blogPostsThisMonth;
  final double aiCostMoM;          // month-over-month AI cost change
  final int activeUsersToday;
  final int activeUsersLastWeekSameDay;
}

String get weeklyAchievementTrend {
  final delta = devAchievementsThisWeek - devAchievementsLastWeek;
  if (delta > 0) return '+$delta (↑ growing)';
  if (delta == 0) return 'flat (→ holding)';
  return '$delta (↓ investigate)';
}
```

## What to Measure and When

**Growth metrics (weekly)**:
- Dev achievement count (this week vs last week)
- Blog post count (cumulative)
- AI University provider count (cumulative)
- Competitor page count (cumulative)

**Health metrics (monthly)**:
- Claude Code cost (vs prior month)
- GHA minutes used (vs free tier ceiling)
- Deploy success rate

**User metrics (daily)**:
- DAU (vs yesterday)
- Open support tickets
- Error rate

## Rate of Change, Not Absolute Value

```
Bad framing: "Only 50 MAU"
Good framing: "25% week-over-week growth"

Bad framing: "Only 62 blog posts"
Good framing: "Was 28 a month ago. More than doubled."

Bad framing: "$230/month on AI costs"
Good framing: "$230 buys 12-engineer output. ROI > 20x."
```

## Early Stagnation Detection

Alert only when the weekly growth rate is zero or negative for 3 consecutive weeks:

```typescript
function detectStagnation(weeklyAchievements: number[]): boolean {
  if (weeklyAchievements.length < 3) return false;
  const last3 = weeklyAchievements.slice(-3);
  return last3.every((v, i) => i === 0 || v <= last3[i-1]);
}
```

Detect stagnation early → analyze cause. Time spent feeling bad about competitor comparisons: zero.

## Summary

Five principles for solo founder KPI design:
1. **Compare only against your past self.** Use competitors for strategy, not self-evaluation.
2. **Measure rate of change.** Absolute values are meaningless without context.
3. **Record achievements.** Objectify the subjective feeling of "worked hard."
4. **Build stagnation detection.** Let data trigger analysis, not emotion.
5. **Measure ROI.** "$230 for 12-engineer output" is the correct self-assessment.

You don't need to beat competitors. Beat yesterday's version of yourself consistently, and in three months you'll be a different person.
