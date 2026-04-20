---
title: "Notion Custom Agents Goes $10/1000 Credit on 5/4 — A Free Way to Run All 6 Departments"
tags: Notion,AI,buildinpublic,webdev,SaaS
published: false
---

# Notion Custom Agents Goes $10/1000 Credit on 5/4 — A Free Way to Run All 6 Departments

## What's Changing

On **2026-05-04**, Notion Custom Agents (Business/Enterprise add-on) switches to **$10 per 1,000 credits** (usage-based).
Until 2026-05-03 the feature was open to all Business/Enterprise customers as a free trial.

Sources:
- <https://www.notion.com/help/custom-agent-pricing>
- <https://www.notion.com/releases/2026-04-14>

Each AI run consumes a handful to a few dozen credits, so **1,000 credits is roughly 30–100 executions**.
The heavier your personal use was, the sooner you'll enter "credit-balance watch mode" once billing kicks in.

## Credit-Balance Watching = Time Capital Leak

At Jibun Inc. (自分株式会社), one founding principle is "**capital = time**."

Every time you pause to check "How many credits do I have left?" you're spending time capital.
When the balance drops near a billing threshold, you start hesitating: "Should I run it again, or save?"
**5 seconds × 20 times a day = 100 sec/day ≈ 10 hours/year** spent on pure balance-checking.

This isn't a rebuttal of Notion. Custom Agents has unmatched strengths for enterprise-data RAG integration.
But for a personal user logging daily life, **predictable free** preserves time capital better than predictable price-per-token.

## The 6-Department Integration Model

Jibun Inc. is a personal tool that maps a "1-person company" onto Flutter Web + Supabase.
It integrates these **6 departments** — all free:

| Department | Scope |
|---|---|
| **R&D** | Learning log / AI University (133 providers) |
| **Finance** | Household KPIs / expense categories |
| **Marketing** | Personal publishing / SNS history / reactions |
| **HR** | Health log / sleep / exercise / mood |
| **HQ** | Mission / 9 principles / decision log |
| **Health** | Physical condition / prevention / medical notes |

Notion Custom Agents broadly covers "notes / wiki / tasks / calendar" — roughly **HQ + R&D + Marketing**.
But **HR + Health** (personal wellbeing) and **Finance** (household budget) aren't Notion's home turf.
That's the natural split: "Notion = work-centered" vs "Jibun Inc. = whole-life."

## The Tech Stack Behind "Predictable Free"

- **Flutter Web (Dart)**: One codebase on iPhone Safari / Android Chrome / desktop browsers
- **Supabase**: PostgreSQL + Edge Functions (Deno) + Auth + Storage — generous free tier
- **16 Edge Function hubs**: core / growth / ai / admin / app / schedule / tools / media / enterprise / social-commerce / lifestyle + 5 standalone
- **AI routing**: ai-hub aggregates 130+ providers to stitch together free tiers
- **Firebase Hosting**: Static hosting on the free tier

"Free" here doesn't mean a shady hobby server — Supabase / Firebase / Flutter / dev.to / Qiita are all **open and SLA-backed**. What matters is the **predictability** of not watching a credit meter.

## 4 Axes of Comparison

| Axis | Notion Custom Agents | Jibun Inc. |
|---|---|---|
| Price | $10 / 1,000 credits (usage-based) | Free |
| Scope | Notes / wiki / tasks / calendar | **6 departments** (R&D / Finance / Marketing / HR / HQ / Health) |
| Japanese UX | English-first + translation | **Japanese-native** |
| Data persistence | Notion cloud (paid-tier dependent) | **Supabase (your own PostgreSQL)** |

## A Coexistence Pattern

The argument isn't "replace Notion." **Splitting the job plays to each side's strength**:

- **Notion = work notes / wiki / enterprise data integration**
- **Jibun Inc. = health / household / daily KPI (= yesterday-you comparison)**

Save your work credits; run the 6 personal departments for free. That's how time capital survives the paywall.

## Try It

- Live: <https://my-web-app-b67f4.web.app/>
- Landing: <https://my-web-app-b67f4.web.app/>
- 21-competitor comparison: <https://my-web-app-b67f4.web.app/comparison>

Notion Custom Agents flips to metered pricing on **May 4**. Knowing there's a "distribute personal 6 departments to a free tool" option beforehand helps you sidestep "credit-balance-watch syndrome" when the switch flips.
