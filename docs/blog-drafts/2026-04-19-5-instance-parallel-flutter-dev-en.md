---
title: "Running 5 Claude Code Instances in Parallel on One Flutter App"
tags: ClaudeCode,Flutter,CI/CD,buildinpublic,webdev
published: false
---

# Running 5 Claude Code Instances in Parallel on One Flutter App

## The Setup

Five Claude Code environments running simultaneously on the same Flutter Web project:

| Instance | Dedicated role |
|----------|---------------|
| **VSCode** | UI / DESIGN.md compliance |
| **PowerShell** | Blog publishing / WF management |
| **Windows App** | AI University providers / migrations / EF |
| **WEB** | Blog research / competitor monitoring (no local CLI) |
| **Mobile** | Real-device UAT / mobile bug triage |

Same repo. Same `main` branch. All five pushing simultaneously.

## Collision Patterns and Fixes

### 1. Concurrent writes to the same file

```bash
# Problem: VSCode and PS both update ROADMAP at the same time
VSCode: git push → success
PS:     git push → rejected (non-fast-forward)
```

**Fix**: rebase before every push:

```bash
git fetch origin main
git log HEAD..origin/main --oneline  # detect parallel commits
git pull --rebase origin main        # absorb before pushing
```

ROADMAP collisions are common. Having each instance append its own `### InstanceN#X` section at the bottom makes auto-rebase resolution work most of the time.

### 2. `cancel-in-progress: true` silently drops deploys

With 5 instances pushing within 30 seconds of each other, the deploy queue gets congested:

```yaml
# ❌ Later push cancels the earlier deploy mid-flight
concurrency:
  group: deploy-production
  cancel-in-progress: true
```

```yaml
# ✅ Queue deploys — all commits eventually land
concurrency:
  group: deploy-production
  cancel-in-progress: false  # waits up to 11min × N but nothing is lost
```

This is the non-obvious one. `cancel-in-progress: true` is fine for a single developer; with 5 parallel instances it destroys work silently.

### 3. Ownership boundaries prevent most collisions

```
lib/pages/**         → VSCode (UI owner)
supabase/functions/  → Windows App (EF owner)
docs/blog-drafts/    → PowerShell (blog owner)
.github/workflows/   → PowerShell (CI owner)
supabase/migrations/ → Windows App (migration owner)
```

When every instance has a different area of the codebase, parallel work mostly doesn't conflict.

### 4. Cross-instance PRs for handoffs

When work crosses ownership boundaries:

```markdown
# docs/cross-instance-prs/20260419_dart_fix.md
from: PowerShell
to: VSCode
---
philosophy_page.dart has a dart:ui_web compile error in tests.
Please fix when VSCode has context ready.
```

When done, move to `docs/cross-instance-prs/done/`. The file acts as a message bus between instances that have no shared memory.

## A Day's Timeline

```
06:00 JST  Windows: AI University provider migration pushed
06:05      PowerShell: 3 blog posts dispatched
06:30      VSCode: UI DESIGN.md fixes pushed
06:31      PowerShell: rebase absorbs VSCode commit → push succeeds
07:00      WEB: competitor monitoring → cross-instance-pr created
09:00      Mobile: real iPhone test → GitHub Issue created
```

## Numbers

| Metric | 1 instance | 5 instances |
|--------|-----------|-------------|
| T-1 blog posts/day | 2-3 | 12 (today's record) |
| UI pages fixed/day | 2-3 | 5-10 |
| AI University providers added/day | 2-3 | 5-8 |
| Deploy success rate | ~95% | ~90% (collision risk) |

Token consumption multiplies by 5, but $20/month delivers roughly $200 worth of work.

## What Makes This Work

1. **Ownership** — define who touches what; conflicts drop to near zero
2. **Cross-instance PRs** — async message passing between instances with no shared memory
3. `cancel-in-progress: false` — all pushes deploy, nothing is silently discarded
4. **Rebase-before-push** — absorb parallel commits before adding yours

It's essentially a multi-developer workflow, but the developers are AI instances rather than humans. The coordination patterns translate directly.

---
Building in public: https://my-web-app-b67f4.web.app/
#ClaudeCode #Flutter #buildinpublic #CI/CD
