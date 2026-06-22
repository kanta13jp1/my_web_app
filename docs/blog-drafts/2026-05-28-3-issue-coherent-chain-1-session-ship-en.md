---
title: "Split one fuzzy user request into 3 coherent issues — the past/now/future triage pattern"
emoji: "🧩"
type: "tech"
topics: ["githubissues", "productmanagement", "triage", "workflow", "indiedev"]
published: true
---

## TL;DR

When a user shows up with a fuzzy ask like *"please ingest my payslips and tell me how much I can spend this month,"* shoving it into one giant issue tends to dead-lock triage and never ship.

Splitting it across **three angles — past / now / future** turns it into **three independent issues that can each ship a Hello-World unit of value**, and the whole triage can complete in a single session.

In Win-side part 236 (2026-05-25) of `自分株式会社` (jibun-corp), I split one payslip-shaped ask into:

- [#3003](https://github.com/kanta13jp1/my_web_app/issues/3003) — **past angle**: payslip ingestion pipeline (data-source layer)
- [#3006](https://github.com/kanta13jp1/my_web_app/issues/3006) — **future angle**: "where should I spend it" AI action (recommendation layer)
- [#3007](https://github.com/kanta13jp1/my_web_app/issues/3007) — **now angle**: disposable-balance AI action (aggregation layer)

…and shipped the migration commits + push for all three in one session. Here is the reusable recipe.

---

## What goes wrong with the obvious approach

A naive single-issue version of "ingest payslips and show me what I can spend" usually decays into one of:

- **Mega-issue paralysis** — scope inflates, no one picks it up.
- **Importer ships, balance never does** — user sees zero value from the data sitting in a table.
- **Fancy AI recommendation on empty data** — the model hallucinates because the source layer was never wired.

The root cause: cutting the work along **"the user goal"** does not split the work into independently-valuable units.

---

## The pattern: cut along the data flow, not the user goal

Slice the ask along **the direction information moves**, not along the screens or layers a programmer is thinking about.

| Angle | Role | Payslip example |
|-------|------|-----------------|
| **Past** | Data-source layer — capture what already happened and store it | Payslip PDF/CSV ingestion pipeline (#3003) |
| **Now** | Aggregation layer — compute the current snapshot | Disposable balance = income − fixed − spent (#3007) |
| **Future** | Action layer — propose what to do next | "Where should I spend it" AI recommender (#3006) |

The key property of this cut: **each slice can be handed to a different specialist in parallel**, because the schemas are decided up front.

- Past slice → backend-leaning (Edge Function + external API)
- Now slice → DB-leaning (SQL, materialized view)
- Future slice → AI-leaning (prompt design + UI)

In a multi-agent setup like our **Win Claude (architect) + Win Codex (implementer)** pair, the architect side fixes the schema + AI prompt up front, and the three implementations fan out to the implementer side without further coordination.

---

## What ran in a single 1-hour session (part 236 walkthrough)

1. **Re-cut the ask along the 3 angles** (5 min)
   - Take "ingest payslips and show me what I can spend" and fill the table above.
   - Draft 3 GitHub issues.

2. **Pre-check the labels** (3 min) ← *this step is what makes 1-session completion possible*
   - Run `gh label list | grep priority`.
   - Confirm `priority:high|medium|low` exist; confirm `P2` does **not** exist.
   - Pivot the original `P2` plan to `priority:medium` *before* calling `gh issue create`.

3. **File 3 issues** (10 min)
   - Each body explicitly states which angle (past/now/future) it owns.
   - Cross-link with `Depends on #...`.

4. **Write 3 WBS migrations** (30 min)
   - `supabase/migrations/20260525150000_wbs_payslip_ingestion_issue3003.sql`
   - `supabase/migrations/20260525160000_wbs_salary_spending_ai_issue3006.sql`
   - `supabase/migrations/20260525170000_wbs_disposable_balance_ai_issue3007.sql`
   - Each `INSERT ... ON CONFLICT DO NOTHING` so reruns are safe (idempotent).
   - Assign all three to the Codex (implementer) side.

5. **3 commits + push** (5 min)
   - `4b76bd19e`, `0621b18bd`, `a13a4f123`.
   - One PR or three — both fine. I shipped three.

6. **Slot them into the Codex backlog chain** (5 min)
   - Place into the 8/13–9/17 Codex sprint chain in dependency order: `#3003 → #3007 → #3006`.

By session end, the implementer side could find **three ready tasks** at the next stand-up.

---

## Why label pre-check matters so much

This sounds boring, but it is the single biggest reason the session closed in one pass.

If you fire `gh issue create --label P2` three times against a repo that has no `P2` label, you get three failures, three corrective commits, three re-pushes, and probably 15 wasted minutes.

Run `gh label list | grep priority` **once** at the top of the session, and:

- you call `gh issue create` zero times with a wrong label
- all three issues create green on the first try
- the entire session stays in "drive forward" mode (no retry loop)

Generalised rule: when a session is going to dispatch multiple issues / branches / WBS rows, **first list the closed enum of available values** (labels, branches, columns, milestones) so the dispatch step never fails on lookup mistakes.

---

## Cuts that look similar but actually fail

For completeness, here are the 3-way cuts that *don't* let you ship in one session:

- **Cut by implementation layer** — *"backend issue / frontend issue / API issue"*
  - User value lands at zero until all three merge.
- **Cut by screen** — *"list screen / detail screen / edit screen"*
  - Data model never settles; all three ship empty.
- **Cut by schedule** — *"this week / next week / next month"*
  - Triage degenerates into a planning meeting; no one starts today.

The reason past/now/future works is that **each slice already produces user-visible value on its own**:

- Past alone: the user can see their raw ingested data.
- Now alone (on top of past): the user can see a single number — current balance.
- Future alone (on top of now): the user can see a recommendation.

It is the shape of *"smallest independent Hello-World per slice"*, just dressed up as a triage rule.

---

## Next experiments

- Measure how fast the Codex (implementer) side actually drains the part-236 chain.
- Bake the list of valid `priority:*` labels into a `gh issue create` wrapper so the CLI fails fast on bad input.
- Try the past/now/future cut on a non-financial domain (assets / health / learning) and see if it keeps working.

---

## Links

- [#3003](https://github.com/kanta13jp1/my_web_app/issues/3003) — payslip ingestion pipeline
- [#3006](https://github.com/kanta13jp1/my_web_app/issues/3006) — "where should I spend it" AI action
- [#3007](https://github.com/kanta13jp1/my_web_app/issues/3007) — disposable balance AI action
- 自分株式会社 (jibun-corp): <https://my-web-app-b67f4.web.app/>
