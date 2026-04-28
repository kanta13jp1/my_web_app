---
title: "The Indie Dev 90-Day Plan: KPI Design to Milestone Management"
tags: ai,indiedev,buildinpublic,automation
published: true
---

# The Indie Dev 90-Day Plan: KPI Design to Milestone Management

Stop building "somewhat." Three months, designed, measured, improved. Here's the framework I actually use.

## Why 90 Days?

```
1 week:   only urgent tasks get done
1 month:  slightly strategic, but too short to see trends
90 days:  trends emerge, tactics can be measured
1 year:   too long to maintain motivation
```

90 days is the sweet spot: strategic enough to move the needle, short enough to stay motivated.

## Phase 0: Goal Setting (Day 1-3)

```
OKR format:
  Objective:
    "Provide [value] to [user type]"
    Example: Give indie developers a daily AI-powered development workflow

  Key Results:
    KR1: MAU 500 (current: 0)
    KR2: NPS +30 (current: unknown)
    KR3: MRR ¥50,000 (current: ¥0)
```

KRs must be measurable. "Better UX" is not a KR. "4.2-min avg session" is.

## Phase 1: Validation (Day 1-30)

```
Month 1 goal:
  - Complete 5 user interviews
  - Release MVP (one core use case only)
  - Set a trial price and observe response

Success criteria:
  - 3 of 5 interviewees say "I'd use this every week"
  - DAU/MAU ratio > 20% (retention signal)
```

Month 1 prioritizes learning over building.

```
Weekly check (every Friday):
  ✅ What did I learn this week?
  ✅ Was the hypothesis right?
  ✅ What's the top priority for next week?
```

## Phase 2: Growth (Day 31-60)

```
Month 2 goal:
  - Publish 4 SEO blog posts
  - Add 20 /vs-{competitor} pages
  - Automate weekly X posts via GHA
  - Land first paying customer

Success criteria:
  - Organic traffic > 300 sessions/month
  - Churn rate < 10%/month
  - MRR > ¥10,000
```

Month 2 balances building with distributing.

## Phase 3: Stabilization (Day 61-90)

```
Month 3 goal:
  - Zero critical bugs
  - GHA Schedule automation reduces ops time 50%
  - Design the next 90-day plan

Success criteria:
  - MAU up 20% month-over-month
  - Support time < 2 hours/week
  - Goals achieved within 20 hours/week of development
```

Month 3 is about making the pace sustainable.

## KPI Dashboard Design

```sql
CREATE TABLE weekly_kpis (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start DATE NOT NULL,
  mau INT,
  new_users INT,
  mrr_jpy INT,
  nps INT,
  churn_rate DECIMAL(4,2),
  recorded_at TIMESTAMPTZ DEFAULT NOW()
);
```

```yaml
# Auto-collect KPIs every Sunday via GHA
on:
  schedule:
    - cron: '0 8 * * SUN'
```

## Monthly Retrospective Template

```markdown
## [Month X] Retrospective

### Done
- [KR1] MAU: target 500 → actual 320 (64%)
- [KR2] NPS: target +30 → actual +22 (73%)

### Not done
- [KR3] MRR: target ¥50,000 → actual ¥18,000 (36%)

### What I learned
- Free-to-paid conversion is higher with a shorter trial

### Adjustments for next month
- Shorten trial from 30 days to 14 days
```

## Summary

```
90-day framework rules:
  1. OKR with measurable targets
  2. Month 1: validate / Month 2: grow / Month 3: stabilize
  3. Weekly check-ins for course correction
  4. Automate KPI collection (GHA + Supabase)
  5. Monthly retro to carry learnings forward
```

Shifting from "building somewhat" to "designing, measuring, adjusting" was the single biggest lever for making indie development sustainable long-term.
