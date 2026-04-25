---
title: "Why I Left Notion and Built My Own App with Flutter + Supabase"
tags: notion,flutter,supabase,saas
published: false
---

# Why I Left Notion and Built My Own App with Flutter + Supabase

## The Moment I Realized Notion Wasn't the Problem

Late 2024, I hit Notion's free tier limit.

Five years of journals, KPI databases, freelance income tracking, reading notes, and project management — all in Notion. The day I got the upgrade prompt, I realized: "Paying $8/month won't actually fix my problem."

**Notion's issue wasn't the price. It was the design philosophy.**

Notion is built for team knowledge management. What I needed was a personal CEO dashboard. Those are fundamentally different products.

---

## "Own Your Own Data" — The Decision

Before leaving Notion, I tried the alternatives.

- **Obsidian**: Excellent local file management. But no live API integration or real-time data fetching.
- **Coda**: More powerful than Notion, but the same "team-first design" problem.
- **Airtable**: Great database UX. But KPI visualization still needs a separate charting tool.
- **Google Sheets**: Fell back to this eventually. Bad on mobile, and I felt like I was giving up.

Conclusion after all of them: **What I actually wanted, nobody had built yet.**

So I built it myself.

---

## Why Flutter + Supabase

The most important criterion: **can I build the full stack alone?**

### Why Flutter — 3 Reasons

**1. Web + iOS + Android from one codebase**
Flutter Web for browser support → PWA for mobile. The Web quality is significantly better than React Native.

**2. Dart's null safety**
Dart forces `null safety`. For a solo dev who might not touch code for weeks at a time, this prevents the "why did this work before?" class of bugs.

**3. Widget tree is intuitive**
`Column(children: [Text(), ElevatedButton()])` maps cleanly to how I think about UI. Coming from backend, this felt natural.

### Why Supabase — 3 Reasons

**1. PostgreSQL, not a NoSQL compromise**
Firebase's NoSQL makes complex relational queries painful. Supabase is PostgreSQL — full relational freedom.

**2. Edge Functions (Deno) make AI integration easy**
LLM API calls, external service connectors — all handled in Edge Functions. Supabase's DB-to-EF integration is tighter than Vercel Functions.

**3. Free tier that handles real production**
Up to 50,000 MAU on the free plan. More than enough for the early stages of a personal product.

---

## What I Built: Jibun Kaisha

The app is called **Jibun Kaisha** (Your Own Company).

The concept: run your personal life like a CEO running a company.

```
HR Dept       → Health, sleep, wellbeing tracking
Finance Dept  → Assets, liabilities, cash flow
Sales Dept    → Side income, freelance projects
Product Dept  → Skills, learning, AI University (206 providers)
Marketing     → Auto-post to X/Qiita/dev.to
Legal Dept    → Contracts, insurance, incorporation planning
```

Six areas I was "kind of" managing in Notion, now with clear role separation and a single dashboard.

---

## 3 Technical Walls I Hit (and How I Solved Them)

### Wall #1: Supabase's 50 Edge Function Limit

Supabase limits you to 50 deployed Edge Functions. Starting with one EF per feature, I hit 30+ fast.

**Solution**: Hub pattern. Created purpose-specific "hub" EFs — `core-hub`, `tools-hub`, `ai-hub` — that route by `action` parameter. Now 16 hub EFs cover 200+ actions.

### Wall #2: Flutter Web Service Worker

PWA support was painful. `flutter build web` auto-manages Service Worker via `flutter_bootstrap.js`, but customizing cache strategy is non-obvious.

**Solution**: Direct customization of `web/flutter_service_worker.js`. Manual management of offline fallback and OGP image caching.

### Wall #3: GitHub Actions Parallel Instance Conflicts

Running 10 parallel instances (VSCode / Win / 6×PS / Web / Mobile) all pushing to the same repo caused constant `rebase conflicts`.

**Solution**: Worktree isolation. Each instance works in its own git worktree and pushes via `git push origin <branch>:main`. For shared files like `GROWTH_STRATEGY_ROADMAP.md`: "skip → re-append" pattern on conflict.

---

## 6 Months Later

- **Users**: 4 (alpha stage, pre-PMF)
- **AI University**: 206 AI providers covered
- **Competitor tracking**: 190 companies monitored
- **Blog posts**: 120+ T-1 series posts on Qiita + dev.to
- **GHA workflows**: 50+ CI/CD and automation scripts
- **Dev velocity**: 10 parallel instances → 500+ commits/month

---

## Should You Self-Build or Stay with Notion?

Was leaving Notion for Flutter + Supabase the right call?

**Where it paid off:**
- Build exactly the features I actually need
- Full data ownership
- Technical learning as a byproduct
- $0/month operating cost (OSS + free tiers)

**The cost:**
- 3 months of initial build time
- All bugs and infra are on me
- UI polish still lags behind Notion's

**Bottom line:** If you're an indie developer who wants the perfect tool for your own workflow, building it is worth it. If you're using it with a team, Notion is still the rational choice.

---

→ [Try it free: https://my-web-app-b67f4.web.app/](https://my-web-app-b67f4.web.app/)

Source code is private (active development), but happy to answer technical questions in the comments.
