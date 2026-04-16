---
title: "Running 3 Parallel Claude Code Instances to Triple My Solo Dev Velocity"
tags: ClaudeCode,buildinpublic,Flutter,Supabase,productivity
published: true
---

# Running 3 Parallel Claude Code Instances to Triple My Solo Dev Velocity

## The Problem with Single-Session Development

When you're solo-building a Flutter Web + Supabase app, there's always too much to do:

- Frontend (Dart) changes pile up while you're fixing backend (Edge Functions)
- CI/CD needs attention but code commits keep coming
- Docs fall behind. Always.

My solution: **three dedicated Claude Code instances running in parallel**, each owning a strict slice of the codebase.

---

## The 3-Instance Architecture

| Instance | Owned Files | Role |
|----------|-------------|------|
| **VSCode** | `lib/` + `supabase/functions/` | Flutter UI + Edge Function dev |
| **Windows App** | `docs/` + `supabase/migrations/` | Docs + DB schema migrations |
| **PowerShell** | `.github/workflows/` | CI/CD + blog automation |

**Hard rule**: each instance never touches files outside its zone. No exceptions.

---

## Why Separation Works

### Problem 1: Context Pollution

One session handling everything mixes Dart syntax, YAML, SQL, and TypeScript simultaneously. Claude's judgment degrades when contexts compete.

Three separate sessions mean each instance stays sharp on its domain.

### Problem 2: Git Conflicts

Multiple concurrent changes to overlapping files cause constant merge conflicts. With strict file ownership, conflicts dropped to near zero.

### Problem 3: Context Window Limits

Long single sessions accumulate compression artifacts — early decisions get lost. Short, focused parallel sessions mean each instance always has clean context.

---

## Cross-Instance Coordination

When one instance needs another to do something, it drops a file in `docs/cross-instance-prs/`:

```
docs/cross-instance-prs/
├── 20260413_allenai_naver_provider_ui.md   # Windows → VSCode request
└── done/
    └── 20260412_groq_provider_ui.md         # completed
```

Example request file:

```markdown
# AI University: Allen AI UI Addition (Windows#67 → VSCode)

## What to add
In `lib/pages/gemini_university_v2_page.dart`, add to `_providerMeta`:

| Key | Value |
|-----|-------|
| provider | `allen_ai` |
| name | `Allen AI (AI2)` |
| emoji | `🔬` |
| color | `Color(0xFF1565C0)` |

Migration already added: `20260413049000_seed_allenai_ai_university.sql`
```

The receiving instance reads the request, implements it, and moves the file to `done/`. No Slack, no GitHub Issues, no async back-and-forth.

---

## Shared State: COMPRESSED_PROMPT_V3.md

All three instances read `.github/COMPRESSED_PROMPT_V3.md` at session start. It holds:

- **Current numbers** (EF count, page count, AI university providers, LP features)
- **Instance scope table** — who owns what
- **Pending implementation list** — what's next

```markdown
## Current Snapshot (as of Windows版#67)
- Edge Functions deployed: 15 (hard cap: ≤50)
- AI University: 54 providers in DB, 54 in UI
- LP features: 126
- Total pages: 219
```

This prevents "already implemented by another instance" duplicate work — which absolutely happens without shared state.

---

## Memory System: Cross-Session Recall

Claude Code doesn't remember previous sessions. So each instance writes to a shared memory directory:

```
~/.claude/projects/my_web_app/memory/
├── MEMORY.md                     # Index, max 200 lines
├── user_instance_powershell.md   # This instance = PS版
├── project_20260413_ps55.md      # PS#55 completion state
├── feedback_success_*.md         # What worked
└── feedback_correction_*.md      # What to never do again
```

Session start ritual:
1. Read `MEMORY.md` — what were the recent successes and corrections?
2. Read `COMPRESSED_PROMPT_V3.md` — what's the current state?
3. Check `docs/cross-instance-prs/` — any pending requests?

---

## Daily Workflow in Practice

```
09:00 JST  Each instance starts → reads MEMORY.md + COMPRESSED_PROMPT
           ↓ Parallel work begins
VSCode     : AI university UI additions (lib/pages/)
Windows    : Migration files (supabase/migrations/)
PowerShell : Workflow fixes + blog dispatch

11:00 JST  Check cross-instance-prs
           Windows: "Allen AI migration added → requesting UI from VSCode"
           VSCode: Picks up request → implements → moves to done/

End of session:
           Each instance appends to GROWTH_STRATEGY_ROADMAP.md
           Saves success/failure patterns to memory/
```

---

## CI/CD: Owned by PowerShell Instance

Three instances pushing to the same repo requires careful CI management. The PowerShell instance owns all `.github/workflows/` and enforces:

- **20 workflows**, all health-checked every session (Rule 17)
- **Concurrency groups** prevent deploy-prod from being cancelled mid-migration
- **EF hard cap**: `ci.yml` blocks any push that would exceed 50 deployed Edge Functions
- **SQL artifact detection**: blocks `'"'"'` bash quoting artifacts before they reach production (learned from a SQLSTATE 42601 incident)

---

## What We Actually Built in One Day

**Results from 2026-04-12 to 04-13:**

| Instance | One Day Output |
|----------|----------------|
| VSCode | 17 AI University UI tabs + OGP share card + 4 new pages |
| Windows | 39 AI University DB migrations (39 SQL files) |
| PowerShell | 35 blog posts dispatched + 20 workflows optimized |

Solo dev. One day. With three focused instances.

---

## The Coordination Cost

This setup isn't free. You need:

1. **Strict file ownership rules** — enforced by convention, not tooling
2. **Cross-instance PR process** — a lightweight alternative to actual PRs
3. **Shared state file** — `COMPRESSED_PROMPT_V3.md` needs maintenance
4. **Memory discipline** — wrap-up at session end, or context is lost

The overhead is maybe 10-15 minutes per instance per session. Worth it when each instance delivers 3-4× the output of a unfocused single session.

---

## Summary

Three Claude Code instances with strict file ownership, a shared state file, and a cross-instance PR convention delivers what feels like a small engineering team — from a single developer.

The key insight: **Claude is better at narrow, well-defined tasks than broad ones**. Role separation is just making that explicit.

---

Building in public: https://my-web-app-b67f4.web.app/

#ClaudeCode #buildinpublic #productivity #FlutterWeb #Supabase
