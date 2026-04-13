---
title: "Adding Persistent Memory to Claude Code with claude-mem — Plus a DIY Lightweight Alternative"
description: "A hands-on comparison of claude-mem (46K stars in 48 hours) vs custom PostToolUse hooks for Claude Code session persistence"
tags: ["claudecode", "ai", "productivity", "llm"]
published: true
---

## The Problem: Claude Code Forgets Everything

Every time you start a new Claude Code session, the slate is wiped clean. Your coding style preferences, project architecture decisions, yesterday's debugging session — all gone.

You end up repeating yourself: "We use Supabase, not Firebase. The Edge Functions are in `supabase/functions/`. Don't use dummy data."

**claude-mem** fixes this by adding persistent memory across sessions. It hit 46K GitHub stars within 48 hours of launch. I installed it, built a lightweight DIY alternative first, and here's what I found.

## What is claude-mem?

GitHub: https://github.com/thedotmack/claude-mem

A plugin that gives Claude Code a long-term memory. It automatically captures what you do during sessions and injects relevant context into future conversations.

### Architecture

- **5 Lifecycle Hooks**: SessionStart / UserPromptSubmit / PostToolUse / Stop / SessionEnd
- **SQLite + Chroma**: Hybrid search (keyword + vector similarity)
- **Bun HTTP Worker**: Background service on localhost:37777
- **MCP Tools**: 3-layer progressive disclosure (search → timeline → get_observations)
- **Web UI**: Visual memory browser

### Installation

```bash
npx claude-mem install
npx claude-mem start  # Requires Bun
```

## The DIY Alternative I Built First

Before discovering claude-mem, I built a minimal memory system using just two PowerShell scripts and Claude Code's native hooks API.

### PostToolUse Hook (auto-capture.ps1)

Triggered after every `Bash` or `Write` tool use. Captures git commits and new file creations to a daily markdown file:

```
memory/auto-capture/2026-04-13.md
- 09:15 [abc1234] feat: Add user authentication
- 09:32 [Write] auth_middleware.dart
- 10:01 [def5678] fix: Token refresh logic
```

### SessionStart Hook (session-resume.ps1)

Reads the last 3 days of captures and injects them as context when a new session starts. The AI immediately knows what you've been working on.

### Registration in settings.json

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Bash|Write",
      "hooks": [{
        "type": "command",
        "command": "powershell -File auto-capture.ps1"
      }]
    }],
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "powershell -File session-resume.ps1"
      }]
    }]
  }
}
```

## Head-to-Head Comparison

| Feature | claude-mem | DIY Hooks |
|---------|-----------|-----------|
| Setup | `npx install` (1 command) | 2 scripts, manual |
| Auto-capture | All tool usage | git commits + Write only |
| Search | Vector similarity + keyword | grep (text search) |
| Web UI | localhost:37777 | None |
| Dependencies | Bun + SQLite + (Chroma) | None |
| Token cost | LLM compression (Gemini = free) | Zero |
| Git-friendly | DB file (gitignored) | Markdown files (shareable) |
| Multi-instance | Session-scoped isolation | File sharing for coordination |

## Running Both Together

The good news: **they coexist perfectly**. claude-mem registers as a plugin, DIY hooks register directly in settings.json. Both fire on the same events without conflict.

### When claude-mem shines

- **Smart compression**: Uses an LLM (Gemini/Claude) to summarize tool outputs into compact observations
- **Semantic search**: "What did I do with the auth system last week?" actually works
- **Web dashboard**: Visual overview of what's been captured

### When DIY hooks shine

- **Zero dependencies**: No server, no database, no runtime
- **Team sharing**: Markdown files can be committed to git and shared across instances
- **Full control**: You decide exactly what gets captured and how
- **Truly free**: No API calls whatsoever

## Cost Optimization Tip

claude-mem defaults to using Claude API for compression, which consumes your tokens. Switch to Gemini (free) to eliminate this:

```json
// ~/.claude-mem/settings.json
{
  "CLAUDE_MEM_PROVIDER": "gemini",
  "CLAUDE_MEM_GEMINI_API_KEY": "your-free-key-from-aistudio.google.com"
}
```

## Our 3-Layer Memory Architecture

In our project (Flutter Web + Supabase, 3 parallel Claude Code instances), we use a layered approach:

| Layer | Tool | Purpose |
|-------|------|---------|
| L1: Intra-session | claude-mem (SQLite) | Auto-record all tool usage, semantic search |
| L2: Inter-session | DIY hooks (markdown) | Git commit history, cross-instance sharing |
| L3: Cross-project | NotebookLM Master Brain | Deep research, long-term architectural knowledge |

## Verdict

claude-mem delivers on its promise of turning Claude Code from a "disposable tool" into a "growing partner." The vector search and Web UI are genuinely useful features that are hard to replicate with simple scripts.

However, for teams that want zero dependencies, zero token cost, and git-friendly memory sharing, a DIY hook approach is a solid starting point.

**My recommendation**: Start with DIY hooks for minimal memory, then layer on claude-mem when you need semantic search and automatic compression.

---

Built with [Claude Code](https://claude.ai/claude-code) | Project: https://my-web-app-b67f4.web.app/
#ClaudeCode #AI #buildinpublic
