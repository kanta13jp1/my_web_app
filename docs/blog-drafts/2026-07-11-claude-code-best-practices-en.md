---
title: "Claude Code Best Practices in 2026 — 10 Rules from 6 Months of Solo Dev at Scale"
tags: claude,ai,programming,productivity
published: false
---

# Claude Code Best Practices in 2026 — 10 Rules from 6 Months of Solo Dev at Scale

## "I'm not getting the most out of Claude Code"

This is where most people start.

"The code it writes doesn't match what I meant." "My instructions got so complicated I lost track." "Context blew up mid-session and it had to reset."

After six months of running 10 parallel instances and hitting 500+ commits/month, here are the practices that actually made a difference.

---

## Rule 1: Put Only Facts in CLAUDE.md

CLAUDE.md is the file Claude Code reads at the start of every session. But **behavioral rules** written in CLAUDE.md don't stick well.

```
❌ Hard to enforce in CLAUDE.md
- "Always run dart format before pushing"
- "Never use dummy data"

✅ What works: fact information
- Tech stack (Flutter Web + Supabase)
- Edge Function list and purpose
- Naming convention examples
```

Behavioral rules are far more reliably enforced by injecting them every turn via a `~/.claude/hooks/UserPromptSubmit` hook. (Distyl AI research: 500 instructions → 68% compliance on the best models. A one-time CLAUDE.md read loses to trained habits.)

---

## Rule 2: Use memory/ to Accumulate Knowledge Across Sessions

The `.claude/memory/MEMORY.md` + individual files three-layer memory system is non-negotiable.

```markdown
# MEMORY.md operating rules
- 1 file = 1-line summary (archive-split when over 200 lines)
- Failure patterns (feedback_correction_*.md) are absolute keeps
- Timestamps required: project_YYYYMMDD_ps2_s42.md
```

Because "why did we do it this way last time" survives between sessions, you stop repeating the same mistakes.

---

## Rule 3: Break Tasks into Atomic Units

Cramming too much into a single Claude Code session degrades accuracy as context pressure builds.

```
❌ Too large
"Redesign the entire Flutter dashboard"

✅ Atomic unit
"Change KPI card color in home_page.dart to primaryOrange from DESIGN.md"
```

One task = one file or one feature unit. When parallel work is needed, distribute it across separate instances.

---

## Rule 4: Use Worktrees to Isolate Parallel Instances

Multiple Claude Code sessions editing the same repository will stomp on each other's uncommitted changes.

```bash
# Create a dedicated worktree per instance
git worktree add .claude/worktrees/instance-ps2 -b claude/ps2-wip

# Integrate back to main through the branch
git push origin claude/ps2-wip:main
```

`git stash` is banned — it affects all processes sharing the same workdir. Use WIP commits to park changes instead.

---

## Rule 5: Delegate Large Refactors to Gemini

For 500+ line mechanical refactors, Gemini Code Assist outperforms Claude Code.

- Claude Code → design, architecture decisions, cross-file consistency checks
- Gemini Code Assist → 500+ line mechanical refactoring
- GitHub Copilot → inline completion, small fixes under 5 minutes

Keep Claude Code's tokens focused on design and decision-making.

---

## Rule 6: Aggregate Edge Functions with the Hub Pattern

Supabase's 50-function limit means one-feature-per-EF hits the ceiling fast.

```typescript
// ❌ EF per feature → hits 50 fast
functions/get-user-kpi
functions/update-user-kpi
functions/delete-user-kpi

// ✅ Hub pattern: route via action parameter
functions/core-hub
// POST {"action": "user.get_kpi", "user_id": "..."}
// POST {"action": "user.update_kpi", "data": {...}}
```

Currently 16 hub EFs cover 200+ actions.

---

## Rule 7: Commit Often, Message Mechanically

Not one commit per session — commit per logical unit.

```bash
# ✅ Good commit messages
git commit -m "fix(auth): add null guard for anonymous user in ai_hub call"
git commit -m "feat(finance): add yesterday comparison to KPI card"

# ❌ Avoid
git commit -m "various fixes"
git commit -m "WIP"  # (emergency escape only)
```

The more parallel instances you run, the more commit granularity and clarity pays off when resolving rebases later.

---

## Rule 8: Always Run `/wrap-up`

At session end, always:
1. Save `memory/project_YYYYMMDD_ps2_sNN.md`
2. Append to `docs/GROWTH_STRATEGY_ROADMAP.md`
3. Update WBS progress via `wbs.update_progress`

Skip this and the next session starts from scratch — same research, same mistakes.

---

## Rule 9: Delegate Research to NotebookLM

Reading 3+ files simultaneously burns tokens fast.

```bash
# ❌ Claude Code reads all files → ~150K tokens
"Read these 3 files and analyze them"

# ✅ Delegate to NotebookLM → ~5K tokens
notebooklm source add ./lib/pages/dashboard.dart
notebooklm source add ./docs/DESIGN.md
notebooklm ask "Is the design consistent?"
```

---

## Rule 10: Use DYNAMIC-CLAIM When Primary Task Is No-Op

When the T-1 dispatch primary task is date-gated and skips, pull an alternative from the WBS.

```
Condition: primary task no-op → DYNAMIC-CLAIM triggers
Steps:
  1. Check candidates via wbs.priority_for_instance
  2. Pick 1 task from marketing / docs / seo (business-legal: prohibited)
  3. Do the work → commit → wbs.update_progress(100%)
Cap: 2 per session
```

In PS#2, this pattern produced 2 SEO articles per session across a planned 50-article series.

---

## Summary

Claude Code is not an "AI that does everything." It's a tool that **only reaches full power when you design the tasks correctly**.

You don't need all 10 rules at once. Start with just "use memory/" and "break tasks into atomic units" — those two alone will meaningfully improve session accuracy.

Jibun Kaisha's AI University covers hands-on Claude Code usage in depth.

→ [Learn Claude Code in AI University](https://my-web-app-b67f4.web.app/)
