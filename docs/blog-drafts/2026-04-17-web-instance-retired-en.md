---
title: "Why I Killed My 4th Claude Code Instance — Lessons from Multi-Agent Indie Dev"
tags: claude,buildinpublic,webdev,productivity
published: true
---

# Why I Killed My 4th Claude Code Instance

## The Setup

I'm building a Flutter Web + Supabase app called "Jibun Inc." — an AI life-management hub that absorbs the features of 21 competitors (Notion, Evernote, MoneyForward, Slack, etc.) into one. The AI University module just passed **66 providers** today.

My dev loop runs **four Claude Code instances in parallel**:

- **VSCode instance** → `lib/` (Flutter UI) and `supabase/functions/`
- **Windows Desktop instance** → `docs/` and `supabase/migrations/`
- **PowerShell instance** → `.github/workflows/` and CI/CD
- **Web instance** (claude.ai/code) → blog translation and PR review via GitHub MCP

Today I shut down the Web instance. Here's why, and what I learned about keeping a multi-agent workflow stable.

## What Broke

Inside a single Web-instance session I hit three different failures:

1. **GitHub MCP dropped the connection three times.**
   The v2.1.110 fix for `MCP tool calls hanging when server connection drops` is apparently not deployed to the claude.ai/code runtime. Each reconnect cost a few minutes.

2. **`Stream idle timeout — partial response received`** when I ran `WebFetch` in parallel with file edits. The response was cut off mid-flight and the session couldn't recover.

3. **A false "file not found" read** on `docs/INSTANCE_CONFIG.md`, which triggered a *new-file creation* attempt — a violation of file-ownership boundaries, because that file belongs to the PowerShell instance. The underlying cause was a dropped MCP call, but the agent didn't know.

Any one of these would be survivable. Hitting all three in one session makes the workflow unshippable.

## The Fix: Back to Three

I did a 5-file cleanup to remove every reference to the Web instance:

```
docs/MULTI_INSTANCE_COORDINATION.md  — title 4→3, drop Web row
docs/INSTANCE_CONFIG.md              — delete Web constraints/prompt/role
docs/README.md                       — 4→3 instances
CLAUDE.md                            — strip Web mentions from Rules 14/21/22
.github/COMPRESSED_PROMPT_V3.md      — header 4→3, scope table
```

`git show 95c385a4 --stat` reported **149 deletions / 29 additions**. The Web instance had crept into more places than I expected.

## Redistributing the Work

| Old Web-instance duty | New owner |
|----------------------|-----------|
| `docs/research/` and `docs/blog-drafts/` | Windows Desktop (already owns `docs/`) |
| GitHub MCP PRs and issue triage | PowerShell (`gh` CLI works there) |
| Opus 4.7 architecture reviews | Windows Desktop / PowerShell |
| Blog English translation | PowerShell (yes, even this post's EN version) |

**Just clarifying who can write what collapsed most of my merge conflicts.**

## Gotchas

### Cross-instance write permission

`docs/INSTANCE_CONFIG.md` is owned by PowerShell, but the decision to retire the Web instance came from the Windows Desktop session. I built a small escape hatch for exactly this case: drop a note in `docs/cross-instance-prs/YYYYMMDD_<topic>.md` and let the owning instance approve it next session.

When it's urgent, I edit the file directly and tag the commit message with `[cross-instance: PowerShell approval required]`.

### Keeping forbidden regions forbidden

Windows Desktop's write scope is `docs/` (minus DESIGN.md) plus `supabase/migrations/`. Today's change also touched `CLAUDE.md` and `.github/COMPRESSED_PROMPT_V3.md`, which are explicitly marked as shared territory. The permission table let me make that call instantly instead of stalling.

### Don't accidentally commit an unrelated change

My working tree had uncommitted edits to `lib/pages/admin/quota_dashboard_page.dart` from a parallel instance. I avoided `git add -A` and listed each file explicitly:

```bash
git add \
  docs/MULTI_INSTANCE_COORDINATION.md \
  docs/INSTANCE_CONFIG.md \
  docs/README.md \
  CLAUDE.md \
  .github/COMPRESSED_PROMPT_V3.md
```

## Takeaways

- **The Web instance of Claude Code is not production-grade for an automated dev pipeline today.** I'll reconsider once MCP stability matches the local runtime.
- **Document the permission boundaries of every agent up front.** Undoing a deployment is fast when you know exactly what to grep.
- **Commit only what you meant to change.** Name your files; don't trust `git add -A` inside a multi-agent repo.

Next post: how I rebuilt the blog-draft pipeline in GitHub Actions so posts stop going silent.

---

Building in public: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #Claude
