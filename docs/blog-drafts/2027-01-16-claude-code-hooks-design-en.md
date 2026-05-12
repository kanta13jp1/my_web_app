---
title: "Claude Code Hooks: Injecting Rules Every Turn Instead of Hoping AI Remembers"
tags: ai,automation,indiedev,programming
published: true
---

# Claude Code Hooks: Injecting Rules Every Turn Instead of Hoping AI Remembers

Claude Code's biggest weakness: it reads CLAUDE.md once at session start, then gradually forgets it. Research shows even the best models comply with written instructions only 68% of the time. The solution is **hooks** — rules injected into every single turn.

## The CLAUDE.md Problem

```
CLAUDE.md → Read once at session start
           → Compressed/forgotten as conversation grows
           → Rule compliance degrades across long sessions
```

With 12 parallel instances, each reads the same CLAUDE.md but compliance visibly degrades over long sessions. The more instances, the more drift.

## Solution: UserPromptSubmit Hook

```json
// ~/.claude/settings.json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "cat ~/.claude/hooks/inject-rules.txt"
          }
        ]
      }
    ]
  }
}
```

Every time a user sends a prompt, `inject-rules.txt` is injected as a system-reminder. **Forced on every turn** — no opportunity for gradual forgetting.

## inject-rules.txt Structure

```text
RULES (injected every turn):

[INSTANCE] Confirm instance type at session start

[WBS-SYNC] Call wbs.priority_for_instance at session start

[DART-FORMAT] After Dart edits: dart format → flutter analyze 0 → push

[REBASE] Before push: git pull --rebase origin main

[EF-CAP-50] EF count ≤ 50 / add hub actions first

[AI-CHARACTER-24] Check AI Character 8 principles

[ROADMAP-LOG] Append to GROWTH_STRATEGY_ROADMAP.md each session
```

Each rule uses `[TAG]` format for grep-ability and audit automation.

## Three Design Principles

### Principle 1: CLAUDE.md for facts, inject-rules.txt for behavior

```
Keep in CLAUDE.md:
✅ Tech stack (Flutter / Supabase / GHA)
✅ EF list
✅ Command examples

Move to inject-rules.txt:
✅ Behavioral rules ([DART-FORMAT] / [REBASE])
✅ Instance roles ([INSTANCE-ROLES])
✅ Constraint checks ([EF-CAP-50] / [NO-SCOPE-CREEP])
```

Facts don't change. Rules evolve. Separating them makes both manageable.

### Principle 2: [TAG] every rule

Using `[EF-CAP-50]` bracket tags enables:
- Grep-based compliance audits (`grep "\[EF-CAP-50\]" git log`)
- GHA cron scanner can detect violations automatically
- cross-instance-pr comments can reference specific rules unambiguously

### Principle 3: Include the Why

```text
[STASH-SAFETY] No git stash — use WIP commits instead
  ← Why: In multi-worktree setups, stash is worktree-local.
         Another instance entering the same worktree can lose it.
```

Knowing why lets the model make judgment calls in edge cases rather than blindly following the rule.

## Measured Impact

Rule violation count per week (detected by wbs-staleness-audit):

| Period | CLAUDE.md only | After inject-rules.txt |
|---|---|---|
| Feb 2026 | 8 violations/week | — |
| Mar 2026 | 6 violations/week | — |
| Apr 2026 (after) | — | 1–2 violations/week |

Most violations were procedural misses: "forgot to rebase before push," "didn't update published:true manually." Every-turn injection eliminated almost all of them.

## The Mental Model

Claude Code hooks are the difference between:
- "I wrote the rule in CLAUDE.md, the AI should follow it" (hoping)
- "The rule is injected into every turn, the AI can't miss it" (engineering)

Don't rely on AI memory. Engineer the constraint into the loop. This is the same principle as type systems, linters, and CI — make correct behavior the path of least resistance.
