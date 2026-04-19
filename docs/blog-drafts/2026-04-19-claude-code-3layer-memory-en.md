---
title: "Building Persistent Memory for Claude Code Across Sessions — 3-Layer Architecture"
tags: ClaudeCode,AI,buildinpublic,architecture,webdev
published: true
---

# Building Persistent Memory for Claude Code Across Sessions

## The Problem

Claude Code resets at the end of every session. Every new session starts cold — no memory of last session's work, no knowledge of banned approaches, no awareness of architectural decisions made three weeks ago.

This is the problem the 3-layer memory system solves.

## Layer 1: Within-Session — claude-mem (SQLite + Gemini compression)

```bash
# Start the worker before your session
npx claude-mem start

# All tool usage is automatically logged
# Vector search retrieves past operations
```

Every tool call during the session is stored in SQLite, compressed by Gemini, and vectorized. When you need to find "where did I save that file" or "what command fixed the lint error", it's searchable.

## Layer 2: Across Sessions — memory/ markdown files

```
~/.claude/projects/<project>/memory/
  MEMORY.md                # Index — loaded every session
  feedback_success_*.md    # What worked
  feedback_correction_*.md # What failed / what's banned
  project_*.md             # Session completion records
```

`MEMORY.md` is included in `CLAUDE.md`, so it's **automatically read at the start of every session**. The index loads instantly; detail files are read on demand.

```markdown
<!-- MEMORY.md index format -->
| File | Description |
|------|-------------|
| feedback_correction_20260418_qiita_loop.md | 🚨 blog_engagement.py self-reply infinite loop |
| project_20260419_ps155.md | PS#149-155: 13 blog posts record + dart:ui_web fix |
```

### Auto-capture hook

```json
// ~/.claude/settings.json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": ".*",
      "hooks": [{ "type": "command", "command": "python3 hooks/auto-capture.py" }]
    }]
  }
}
```

The hook runs after every tool call. Important patterns — file writes, command outputs, errors — are automatically captured without manual intervention.

## Layer 3: Cross-Project — NotebookLM Master Brain

```bash
notebooklm use jibun-master-brain
notebooklm source add memory/project_20260419.md
notebooklm ask "What were the past failures with authentication?"
```

Every session summary gets added to a dedicated NotebookLM notebook. When you need to understand "why was this architectural decision made" or "what approaches have been tried and rejected", the Master Brain has it — even across months.

## Session Start Protocol

```bash
# 1. memory/ loads automatically via CLAUDE.md
# 2. Check pending cross-instance work
ls docs/cross-instance-prs/ | grep -v "done/"
# 3. Check for parallel instance commits
git log origin/main --oneline -10
# 4. Query Master Brain for non-obvious decisions
notebooklm ask "What's the priority for today?"
```

## Session End Protocol (/wrap-up)

```bash
# Record success patterns
Write memory/feedback_success_YYYYMMDD.md

# Record failures and bans
Write memory/feedback_correction_YYYYMMDD.md

# Record session completion
Write memory/project_YYYYMMDD_xxx.md

# Update MEMORY.md index (prepend entry)
Edit memory/MEMORY.md

# Feed Master Brain
notebooklm source add memory/project_YYYYMMDD_xxx.md
```

## What This Actually Prevents

```markdown
<!-- feedback_correction: auto-reply loop -->
blog_engagement.py sent replies to its own comments on Qiita.
Root cause: missing `author == self` check.
Fix: always skip self + MAX_REPLIES_PER_RUN cap.
Status: fixed in scripts/blog_engagement.py (2026-04-18)
```

This entry loads every session. The bug can't be reintroduced accidentally.

## Architecture Summary

| Layer | Tool | Purpose |
|-------|------|---------|
| L1 — session | claude-mem (SQLite) | Operation log, vector search |
| L2 — cross-session | memory/ markdown | Success/failure patterns, settings |
| L3 — cross-project | NotebookLM Master Brain | Deep knowledge, decision history |

The system addresses Claude's fundamental limitation — no cross-session memory — without requiring any changes to the Claude Code product itself. Pure convention + hooks.

---
Building in public: https://my-web-app-b67f4.web.app/
#ClaudeCode #AI #buildinpublic #architecture
