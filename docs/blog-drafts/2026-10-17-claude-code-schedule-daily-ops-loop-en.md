---
title: "Putting Daily Indie Dev on Autopilot with Claude Code Schedule"
tags: claude-code,automation,indiedev,scheduled-tasks
published: false
---

# Putting Daily Indie Dev on Autopilot with Claude Code Schedule

## Why hand "morning routine dev" to an AI

The hardest thing about indie dev is the **small daily compounding work**:

- Re-read the roadmap
- Log today's progress as a seed migration
- Draft one blog post
- Append to the ROADMAP_LOG
- Commit and push

Each takes five minutes, but skipping a week because "I'm not feeling it" turns into a month-long gap.

At Jibun K.K. ("Me, Inc.") we hand this morning routine to Claude Code Schedule. One SKILL called `daily-development`, fired by cron once a day. Done.

---

## The SKILL.md layout

```text
~/.claude/scheduled-tasks/daily-development/SKILL.md
```

Inside is a 7-step checklist:

1. **Read the Master Brain** — open `memory/MEMORY.md` first
2. **Check the roadmap** — pick the next task from the tail of `docs/GROWTH_STRATEGY_ROADMAP.md`
3. **Fix dummy data** — close implementation gaps before anything else
4. **Implement roadmap items** — short-term unfinished tasks
5. **Write a tech blog draft** — drop JA + EN versions into `docs/blog-drafts/`
6. **Record dev achievements** — append a seed in `supabase/migrations/`
7. **Commit and push** — ship to main

The trick is to write every step assuming **the user is not present**. No clarifying questions allowed.

---

## Avoiding migration timestamp collisions

Scheduled tasks fail most often on **migration timestamp collisions**.

If the PowerShell instance or Windows app instance ships a seed in parallel, you get `SQLSTATE 23505 (schema_migrations_pkey)` and the deploy dies instantly.

The mitigation is simple:

```bash
# Always check today's latest timestamp before picking a new one
ls supabase/migrations/ | grep "^$(date +%Y%m%d)" | sort | tail -3
```

Pick **+10 minute increments** rather than +30. If a collision happens, renaming is one digit instead of one hour.

---

## The "no parallel Bash" rule

In a scheduled task environment we **forbid parallel Bash invocations**.

The permission stream is flaky: if one parallel Bash gets denied, all the others are cancelled and the run dies mid-task.

```yaml
# NG: multiple Bash calls in the same message
# OK: one Bash completes, then the next is issued
```

Read / Glob / Grep don't need permission so they remain free to parallelise. Only Bash is special-cased.

---

## Falling back when Anthropic is down

When the Anthropic API is down, Claude Code Schedule is down too.

So write a **fallback runbook** in advance that maps each task to a non-Claude tool:

| Task | Primary | Fallback |
|---|---|---|
| Migration seed (boilerplate) | Codex CLI | GitHub Copilot |
| Flutter widget tweak | Gemini Code Assist | Copilot |
| Competitor research | NotebookLM Deep Research | WebSearch |
| Architecture decision | Claude Code | **48h pause is OK** |

Inside `daily-development`, only the judgement steps (1 + 4) require Claude. The boilerplate steps (5 + 6) can keep running on other AIs even during a 48h Claude outage.

Split your Schedule tasks into **"Claude-only"** and **"AI-fungible"** buckets when you design them.

---

## Real-world KPIs

| Metric | Before (manual) | After (Schedule) |
|---|---|---|
| Commits per day | 0–2 | 1–3 |
| Blog drafts written per month | 3 | 25+ |
| Days roadmap goes unupdated | 5–10 | 0 |
| Morning motivation required | 100% | 0% |

The blog drafts pile up under `docs/blog-drafts/`, and the T-1 blog dispatch routine (PowerShell instance #2) ships them to dev.to / Qiita on schedule.

---

## Wrap-up — outsource "yesterday's me"

- Put Schedule tasks in `~/.claude/scheduled-tasks/<name>/SKILL.md`
- Write every step **assuming no user is present** (decisions allowed, questions not)
- Pick migration timestamps in **+10-minute increments**
- **Forbid parallel Bash** (permission stream defence)
- Pair every Schedule with an **Anthropic-outage fallback runbook**

Don't waste morning energy deciding what to do. Hand the routine to Claude Code Schedule and only look at **the delta vs. yesterday's me**.
