---
title: "Running 12 AI Instances in Parallel: My Claude Code Fleet Architecture"
tags: claude-code,ai,architecture,indiedev
published: false
---

# Running 12 AI Instances in Parallel: My Claude Code Fleet Architecture

As a solo developer, I run **10 Claude Code instances + 2 Codex CLI instances = 12 AI slots simultaneously**. Here's how the architecture works and why it's worth the complexity.

## Why 12 Instances?

Single-AI development hits a ceiling:

- **Context pollution**: Long sessions cause early decisions to drift
- **No true parallelism**: Can't touch Flutter UI and DB migrations at the same time
- **Generalist mediocrity**: One instance doing everything does nothing great

The solution: role-specific dedicated instances.

## Instance Role Table

| Instance | Domain | Worktree |
|---|---|---|
| VSCode | Flutter UI + Edge Functions | `instance-vscode` |
| Windows | Docs + video pipeline | `instance-win` |
| PS#1 | Workflow health monitoring | `instance-ps1` |
| PS#2 | Blog dispatch (dev.to/Qiita) | `instance-ps2` |
| PS#3 | AI University content | `instance-ps3` |
| PS#4 | 172-company competitor data | `instance-ps4` |
| PS#5 | EF integration + auth guard | `instance-ps5` |
| PS#6 | Horse racing AI pipeline | `instance-ps6` |
| Codex#1 | Cross-cutting research + fix PRs | `instance-codex1` |
| Codex#2 | CI/sync/ops assist | `instance-codex2` |

## Git Worktree Isolation

The cardinal rule: **never edit the main repo directly**.

```bash
# Each instance works in its own worktree
git worktree add .claude/worktrees/instance-ps2 -b claude/ps2-wip
cd .claude/worktrees/instance-ps2
```

Worktree isolation means:
- Each instance works on an independent branch
- Changes merge to main after push
- Rebase absorbs push conflicts automatically

## Push Conflicts Are Normal

With 12 parallel pushers, rejected pushes are daily life. The fix:

```bash
# Always fetch + rebase before push
git pull --rebase origin main && git push origin HEAD:main
```

I see 10-20 `rejected` pushes per day, but `--rebase` resolves almost all of them automatically.

## Migration Timestamp Collisions

When 12 instances create SQL migrations on the same day, `YYYYMMDD000000` timestamps collide and cause `SQLSTATE 23505` errors.

**Fix**: Reserve timestamp slots in 500-increment bands:
- instance-ps3: `20260428001000`, `001500`, `002000`...
- instance-win: `20260428010000`, `010500`...

A `check_migration_timestamps.py` script runs pre-push to catch collisions early.

## Claude vs Codex Split

| Task | Primary | Reason |
|---|---|---|
| Architecture decisions | Claude | Requires design reasoning |
| SQL optimization | Codex | Fast code generation |
| GHA workflows (YAML) | Codex | Template-heavy, Codex excels |
| Memory consolidation | Claude | Cross-session judgment needed |
| Flutter widget creation | Claude | Design system awareness |

## Monthly Cost Reality

- Claude Max plan: ~$100/month (10 instances)
- Codex: ~$20/month (API usage)
- **Total: ~$120/month for mid-team-scale output**

As a solo founder, this is the highest-ROI investment I've made.

## The Five Rules That Make It Work

1. **Lock roles** — each instance has one domain, no scope creep
2. **Isolate with worktrees** — prevents file conflicts before they happen
3. **Rebase everything** — absorbs parallel push conflicts
4. **Reserve timestamps** — prevents DB migration collisions
5. **Let Claude handle architecture** — delegate implementation to Codex/Copilot

With this architecture, my project consistently produces 50-80 commits per day from one person's keyboard.

The complexity is real, but so is the output. Once the rules are set, the system runs itself.
