---
title: "5 Claude Code Instances in Parallel with git worktree — Eliminating stash Conflicts"
tags: git,buildinpublic,AI,Claude,DevOps
published: true
---

# 5 Claude Code Instances in Parallel with git worktree

## The Problem: git stash Kills Another Instance's Work

When 5 Claude Code instances share the same working directory, this happens:

```
PS instance:  no uncommitted changes
Win instance: editing lib/pages/horse_racing.dart (uncommitted)
PS instance:  git stash → git pull --rebase → git stash pop
              ↑ This stash captures Win instance's changes too → Win's work is gone
```

`git stash` operates on the entire working directory — it doesn't know which changes "belong" to which process.

## Solution: Dedicated worktree per Instance

```bash
# Create instance-specific branches + worktrees
git worktree add .claude/worktrees/instance-vscode -b claude/vscode-wip origin/main
git worktree add .claude/worktrees/instance-ps     -b claude/ps-wip     origin/main
git worktree add .claude/worktrees/instance-win    -b claude/win-wip    origin/main
```

Each instance gets its **own working directory**. A `git stash` in the PS worktree has zero effect on the Win worktree.

## Per-Instance Workflow

```bash
# PS instance — every session
cd /repo/.claude/worktrees/instance-ps

# Sync with latest
git rebase origin/main

# Do work, commit immediately
git add -A && git commit -m "docs: T-1 draft"

# Push to main
git push origin claude/ps-wip:main

# Keep worktree current
git rebase origin/main
```

## No More git stash — WIP Commit Pattern

If you have uncommitted changes before a rebase, use a WIP commit instead:

```bash
# Instead of git stash:
git add -A && git commit -m "WIP: $(date +%H:%M)"
git rebase origin/main
# Later: git reset HEAD~1 to unstage if needed
```

## Verify Your Worktree on Session Start

```bash
git rev-parse --show-toplevel
# Must return: /repo/.claude/worktrees/instance-ps
# If it returns the main repo path → cd to your worktree immediately
```

## Edit/Write Tool Path Safety

When Claude Code writes files, the path must start with the correct worktree:

```
✅ /repo/.claude/worktrees/instance-ps/docs/blog-drafts/draft.md
❌ /repo/docs/blog-drafts/draft.md  ← main repo = another instance's territory
```

Writing to the wrong path can corrupt another instance's in-progress work.

## Summary

| Before | After |
|--------|-------|
| All instances share main repo | Each instance has dedicated worktree |
| git stash affects everyone | stash isolated to own worktree |
| stash frequently used | WIP commits replace stash |
| Risk: another instance's work disappears | Independent — no cross-contamination |

At 5+ parallel instances, worktree isolation is not optional — it's the foundation.

---
Building in public: https://my-web-app-b67f4.web.app/
#git #buildinpublic #AI #Claude #paralleldev
