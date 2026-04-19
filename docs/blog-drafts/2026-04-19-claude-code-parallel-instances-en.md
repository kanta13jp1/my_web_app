---
title: "Running 10 Claude Code Instances in Parallel — git worktree Isolation Design"
tags: ClaudeCode,git,buildinpublic,webdev
published: false
---

# Running 10 Claude Code Instances in Parallel

## The Problem: git stash Destroys Other Instances' Work

Running multiple Claude Code instances against the same repository causes silent data loss:

```
Instance A: editing lib/pages/home_page.dart (uncommitted)
Instance B: runs git pull --rebase
            → A's uncommitted changes get swept up in the rebase and lost

Instance C: runs git stash
            → Since all instances share the same workdir,
              A and B's changes end up in C's stash
```

Root cause: **all instances share the same working directory**.

## The Fix: Dedicated Worktree per Instance

```bash
git worktree add .claude/worktrees/instance-ps1 -b claude/ps1-wip
git worktree add .claude/worktrees/instance-ps2 -b claude/ps2-wip
git worktree add .claude/worktrees/instance-vscode -b claude/vscode-wip
git worktree add .claude/worktrees/instance-win -b claude/win-wip
```

Each instance operates exclusively in its own worktree. `git stash` and `git pull --rebase` in one instance have zero effect on others.

## 10-Instance Role Assignment

```
PS#1     → .claude/worktrees/instance-ps1   (CI/WF health monitoring)
PS#2     → .claude/worktrees/instance-ps2   (blog post dispatch)
PS#3     → .claude/worktrees/instance-ps3   (AI university content)
PS#4     → .claude/worktrees/instance-ps4   (competitor monitoring)
PS#5     → .claude/worktrees/instance-ps5   (on-call bug fixes)
PS#6     → .claude/worktrees/instance-ps6   (batch jobs / horse racing)
VSCode   → .claude/worktrees/instance-vscode (UI / design)
Windows  → .claude/worktrees/instance-win   (AI university / migrations)
WEB      → no worktree needed (GitHub MCP only)
Mobile   → no worktree needed (GitHub MCP only)
```

## Setup Script

```bash
#!/bin/bash
# .claude/scripts/setup-instance-worktree.sh
set -e

INSTANCE=$1
REPO_ROOT=$(git rev-parse --show-toplevel)
WORKTREE_DIR="$REPO_ROOT/.claude/worktrees/instance-$INSTANCE"
BRANCH="claude/${INSTANCE}-wip"

if [ -d "$WORKTREE_DIR" ]; then
  echo "worktree already exists: $WORKTREE_DIR"
  exit 0
fi

git worktree add "$WORKTREE_DIR" -b "$BRANCH" 2>/dev/null || \
  git worktree add "$WORKTREE_DIR" "$BRANCH"

echo "created: $WORKTREE_DIR (branch: $BRANCH)"
```

Usage:

```bash
bash .claude/scripts/setup-instance-worktree.sh ps1
bash .claude/scripts/setup-instance-worktree.sh vscode
```

## Pushing to main

Each instance pushes its wip branch tip to main:

```bash
cd .claude/worktrees/instance-ps1

git add docs/GROWTH_STRATEGY_ROADMAP.md
git commit -m "ci: Rule17 health check"

git pull --rebase origin main
git push origin claude/ps1-wip:main
```

When two instances push simultaneously, the second will get a "behind remote" rejection. Recovery:

```bash
git pull --rebase origin main   # fast-forward or resolve conflicts
git push origin claude/ps1-wip:main
```

## Registering Worktrees in .git/info/exclude

Worktrees are git internals — do **not** add them to `.gitignore` (that would break `git worktree list`). Instead use the local-only exclude file:

```
# .git/info/exclude
.claude/worktrees/
```

List active worktrees at any time:

```bash
git worktree list
# /path/to/my_web_app                    abc1234 [main]
# /path/to/.claude/worktrees/instance-ps1  def5678 [claude/ps1-wip]
# /path/to/.claude/worktrees/instance-ps2  ghi9012 [claude/ps2-wip]
```

## Results

| Problem | Before | After |
|---|---|---|
| stash interference | Changes from other instances disappear | **Each instance has its own stash** |
| pull --rebase | Sweeps up other instances' uncommitted work | **Only affects the local wip branch** |
| Parallel push | Collision / overwrite risk | **Always rebase-clean before push** |
| Debugging | Unclear which instance made a change | **Traceable by wip branch name** |

## Key Rules

1. **Never work in the main repo directory** — it's push target only
2. **git stash is banned** — WIP commit instead (`git commit -m "WIP"`)
3. **commit before pull --rebase** — staged-only changes can still be lost
4. **Edit → commit → push in a single bash invoke** — prevents linter revert interference

## Conclusion

`git worktree` is the standard solution for multiple processes sharing the same repository. For Claude Code's autonomous multi-instance model, it's not optional — it's the design. One worktree + wip branch per instance eliminates the entire class of "my changes disappeared" incidents.

---
Building in public: https://my-web-app-b67f4.web.app/
#ClaudeCode #git #buildinpublic
