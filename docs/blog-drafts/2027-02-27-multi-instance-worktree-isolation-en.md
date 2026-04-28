---
title: "12 AI Instances, Zero File Conflicts: How Git Worktrees Make It Work"
tags: ai,automation,indiedev,programming
published: true
---

# 12 AI Instances, Zero File Conflicts: How Git Worktrees Make It Work

10 Claude Code instances + 2 Codex instances running simultaneously. Here's the isolation system that keeps them from colliding.

## The Problem: Multiple AIs Touching One Repo

```
Instance A: editing lib/pages/landing_page.dart
Instance B: editing the same file differently → merge conflict
Instance C: git pull on main → picks up A's WIP → deploys broken state
```

Branch strategy alone doesn't fix this. Multiple AIs working on the same `main` branch collide constantly.

## The Solution: Physical Isolation with git worktree

```bash
# Create a dedicated worktree per instance
git worktree add .claude/worktrees/instance-ps1 -b claude/ps1-wip
git worktree add .claude/worktrees/instance-ps2 -b claude/ps2-wip
git worktree add .claude/worktrees/instance-vscode -b claude/vscode-wip
# ... 12 instances total
```

Result:
- `instance-ps1/` has its own working files
- `instance-ps2/` has its own working files
- **Same file, different worktrees = no conflict**

## How worktrees Work

```
my_web_app/                    # main repo (integration/review only)
  .claude/
    worktrees/
      instance-ps1/            # PS#1 workspace
        lib/ → real files
        branch: claude/ps1-wip
      instance-ps2/            # PS#2 workspace
        lib/ → real files
        branch: claude/ps2-wip
      instance-vscode/         # VSCode workspace
        lib/ → real files
        branch: claude/vscode-wip
```

Each worktree has an **independent branch**. `git add/commit` is fully contained per worktree.

## Session Start Protocol

```bash
# Every instance runs this at session start
cd C:/Users/kanta/GitHub/my_web_app/.claude/worktrees/instance-ps2

# Pull latest main
git pull --rebase origin main

# Check assigned tasks, then start working
```

`git stash` is **banned**. In multi-worktree environments, stashes are worktree-local. If another instance enters the same worktree, the stash is gone. Use WIP commits instead (`git commit -m "WIP"`).

## Push Flow

```bash
# After completing work
git add <files>
git commit -m "feat: ..."

# Rebase before push
git pull --rebase origin main
git push origin HEAD:main
```

`git push origin HEAD:main` is critical. Plain `git push` sends to `claude/ps2-wip`, not main.

## When Conflicts Still Happen

The only case: two instances edit **the same file on the same day** and both try to push:

```bash
# PS#4 pushes landing_page.dart
# PS#5 also modified it, tries to push
→ rebase conflict

# Fix: always pull --rebase before push
git pull --rebase origin main
# → resolve conflict manually
git add <resolved-file>
git rebase --continue
git push origin HEAD:main
```

In three months across 12 instances, this happened 1–2 times per month. **Pre-assigned file ownership** minimizes it.

## Instance File Ownership

| Instance | Assigned Files |
|---|---|
| VSCode | `lib/pages/` — UI components |
| PS#1 | `.github/workflows/` — workflow health |
| PS#2 | `docs/blog-drafts/` — T-1 content |
| PS#3 | `supabase/migrations/*_seed_ai_university*` |
| PS#4 | `lib/pages/comparison_page.dart`, `web/sitemap.xml` |
| PS#5 | Auth guards across `lib/pages/`, `supabase/functions/` |
| PS#6 | `supabase/functions/schedule-hub/` — horse racing AI |
| Win | `docs/`, `supabase/migrations/` schema changes |

When ownership overlaps: the second pusher always pulls --rebase first.

## Codex Integration

Codex CLI uses the same worktree pattern:

```
.claude/worktrees/instance-codex1/  (branch: codex/codex1-wip)
.claude/worktrees/instance-codex2/  (branch: codex/codex2-wip)
```

Claude Code creates cross-instance PRs → Codex implements in its worktree → PR → merge.

## Three Months of Lessons

**What worked**:
- File-level conflicts near-zero
- Each instance commits independently → git log is readable
- `git log --oneline` shows which instance did what at a glance

**What failed**:
- Ephemeral worktrees (auto-generated names) → pruned by PS#6 cleanup → lost work → **standardized to `instance-*` fixed names**
- Migration timestamp collisions on the same day → solved with 500-unit offset rule

## Summary

The isolation system that makes 12 parallel instances work:
1. **git worktree** — physical workspace separation
2. **Pre-assigned file ownership** — minimize overlap probability
3. **pull --rebase → push** — consistent merge flow
4. **No stash, WIP commits only** — stash-safe rule

The same tools that human teams use for collaboration (`git worktree`, branch strategy, file ownership) work for AI teams. The main difference: AI instances follow rules more consistently than humans do.
