---
title: "Pushing from git worktree branches to main — Multi-Instance Conflict Recovery Guide"
tags: ClaudeCode,git,buildinpublic,webdev
published: true
---

# Pushing from git worktree branches to main

## TL;DR

When running multiple Claude Code instances, pushing from each instance's `wip` branch directly to `origin/main` is the simplest approach. Conflicts resolve with a single `git pull --rebase origin main` command.

## Setup: Worktree Layout

```
my_web_app/
  .claude/worktrees/
    instance-ps1/    ← branch: claude/ps1-wip
    instance-ps2/    ← branch: claude/ps2-wip
    instance-vscode/ ← branch: claude/vscode-wip
```

Each instance works exclusively on its `wip` branch and merges into `origin/main` only at push time.

## 3 Push Patterns

### Pattern 1: `HEAD:main` (recommended)

```bash
git push origin HEAD:main
```

Pushes the currently checked-out branch to `origin/main`. No need to remember branch names.

### Pattern 2: Explicit branch name

```bash
git push origin claude/ps1-wip:main
```

Better for scripts and CI where `HEAD` might be ambiguous.

### Pattern 3: Push from outside the worktree

```bash
git -C .claude/worktrees/instance-ps1 push origin HEAD:main
```

Useful when pushing another instance's changes from the main repo directory.

## Conflict Recovery

When two instances push simultaneously, the second one gets rejected:

```
! [rejected]        claude/ps1-wip -> main (non-fast-forward)
error: failed to push some refs
hint: Updates were rejected because the remote contains work that you do
hint: not have locally.
```

**Standard recovery (single command)**:

```bash
git pull --rebase origin main && git push origin HEAD:main
```

Using `rebase` avoids merge commits — keeps the log clean.

## Common Conflict Patterns and Fixes

### Simultaneous ROADMAP.md appends

`docs/GROWTH_STRATEGY_ROADMAP.md` gets appended by every instance at session end — it's the most conflict-prone file.

**Fix**: Assign a fixed section per instance:

```markdown
### PS版#1 Session Log

### PS版#2 Session Log

### VSCode Session Log
```

Instances never touch each other's sections, so rebase auto-merges succeed most of the time.

### Migration file timestamp collision

```
20260419220000_seed_foo.sql   ← created by PS#1
20260419220000_seed_bar.sql   ← created by Win at the same second
```

Identical timestamps cause `duplicate key` errors in Supabase deploy.

**Fix**: Before creating a migration file, check the current max timestamp for the day:

```bash
ls supabase/migrations/ | grep $(date +%Y%m%d) | sort | tail -1
# → 20260419220000_seed_foo.sql

# New file: +10 seconds
touch supabase/migrations/20260419220010_seed_bar.sql
```

### wip branch far behind main

After a long session, `origin/main` might be 20+ commits ahead, increasing rebase conflicts.

**Diagnosis**:

```bash
git log --oneline claude/ps1-wip..origin/main | wc -l
# If 20+, inspect before rebasing
```

**Fix**: If 3+ conflicts, switch to merge:

```bash
git rebase --abort
git fetch origin
git merge origin/main  # accept the merge commit
# resolve conflicts manually
git push origin HEAD:main
```

## Summary

| Situation | Command |
|---|---|
| Normal push | `git push origin HEAD:main` |
| Recovery after rejection | `git pull --rebase origin main && git push origin HEAD:main` |
| Heavy conflicts | `git rebase --abort && git merge origin/main` → manual resolution |
| Check migration timestamp | `ls supabase/migrations/ \| grep $(date +%Y%m%d) \| sort \| tail -1` |

Conflicts in multi-instance parallel development can't be completely eliminated. But by consistently using `rebase + direct push to main`, you can maintain a state where any conflict is recoverable in under 30 seconds.

---
Building in public: https://my-web-app-b67f4.web.app/
#ClaudeCode #git #buildinpublic
