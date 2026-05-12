---
title: "12 AI Instances in Parallel: A 3-Month Retrospective with Real Numbers"
tags: ai,automation,indiedev,buildinpublic
published: true
---

# 12 AI Instances in Parallel: A 3-Month Retrospective with Real Numbers

I've been running 10 Claude Code instances + 2 Codex CLI instances in parallel for three months. Here's what actually worked, what failed, and the real cost breakdown.

## Fleet Configuration

| Instance | Role | Key outputs |
|---|---|---|
| VSCode | Flutter UI / EF design | 172-competitor pages, horse racing UI |
| Win | Docs / migration schema | AI Character, IMBUE, COLLAB principles |
| PS#1 | Rule17 WF health | All GHA workflows stabilized |
| PS#2 | T-1 blog dispatch | 50 dev.to posts (Phase 1–6) |
| PS#3 | AI university providers | 200 → 270 providers |
| PS#4 | Competitor pages | Sitemap: 174 routes complete |
| PS#5 | Stale EF audit / anon guard | 20 pages auth-protected |
| PS#6 | Horse racing AI | DQS + prev_margin 9-factor model |
| Codex#1 | Cross-instance review / fix PRs | Migration timestamp collision detector |
| Codex#2 | CI / sync support | EF audit workflow |

## 3-Month Quantitative Results

| Metric | Start | 3 months later |
|---|---|---|
| AI University providers | 200 | **270** |
| Competitor pages | 22 routes | **174 routes** |
| dev.to posts | 0 | **50** |
| GHA workflows | 18 | **31** |
| Edge Functions | 28 | **18 (reduced by hub pattern)** |

## What Worked: Role Separation

The biggest win was parallelism through role specialization.

Before: 1 Claude Code instance, serial processing → ~10 tasks/day  
After: 12 instances, parallel → 60–80 tasks/day

The most effective specializations:
- **PS#3**: AI university additions are fully templatized → stable 2 providers/session
- **PS#6**: Horse racing AI dedicated instance → improvement cycle weekly → daily
- **PS#2**: Blog dispatch dedicated → other instances stay focused on building

## What Failed: Migration Timestamp Collisions

The biggest failure was the migration timestamp collision problem.

```
2026-04-28: PS#3, PS#4, PS#5, Win all simultaneously created
20260428000000_*.sql → deploy-prod SQLSTATE 23505
```

Fix: `check_migration_timestamps.py` added to CI to detect duplicate timestamps before deploy.

Lesson: any namespace shared across 12 instances (timestamps, EF names, sitemap URLs) needs collision detection. You can't rely on individual instances to self-coordinate.

## Real Cost Breakdown

| Cost | Monthly |
|---|---|
| Claude Code Max plan | $200/month (cap) |
| GitHub Actions | $0 (free tier) |
| Supabase Pro | $25/month |
| Firebase Hosting | $0 (free tier) |
| ElevenLabs | $5/month |
| **Total** | **~$230/month** |

$230/month for the equivalent of 12 engineers' output is compelling for solo dev. The hidden cost: **management overhead** (cross-instance coordination, collision resolution, memory consolidation) runs 3–4 hours per week.

## Remaining Challenges

1. **cross-instance-pr automation**: humans still mediate instance handoffs. Direct instance-to-instance handoff needs a structured protocol
2. **WBS update accuracy**: 2–3 completion reports missed per week
3. **memory decay**: no automated archiving of stale memory files yet
4. **Codex integration depth**: Codex instances are underutilized relative to Claude. Deeper collaboration patterns needed

## The Honest Summary

Running 12 parallel AI instances dramatically raises the ceiling for solo development. But it introduces a new category of work: **managing the agents that manage your code**. Role separation, collision detection, and memory consistency are the three fundamentals. Get those right and the productivity gains are real. Get them wrong and you're debugging agent conflicts instead of building features.
