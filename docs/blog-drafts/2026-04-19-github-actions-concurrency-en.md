---
title: "GitHub Actions Concurrency Trap — cancel-in-progress: false Still Drops Queued Runs"
tags: GitHubActions,CI/CD,buildinpublic,webdev
published: false
---

# GitHub Actions Concurrency Trap

## TL;DR

`cancel-in-progress: false` only protects **running** jobs. **Queued** jobs are still cancelled by newer runs.

## The Problem: 6 Deploys Cancelled in a Row

```
deploy-prod cancelled 2026-04-19T10:00:59
deploy-prod cancelled 2026-04-19T10:02:30
deploy-prod cancelled 2026-04-19T10:04:03
deploy-prod cancelled 2026-04-19T10:07:30
deploy-prod cancelled 2026-04-19T10:08:41
deploy-prod cancelled 2026-04-19T10:08:56
deploy-prod success  2026-04-19T10:09:34  ← only the last one ran
```

The config said `cancel-in-progress: false`. So why all the cancellations?

## How GitHub Actions Concurrency Actually Works

```yaml
concurrency:
  group: deploy-prod
  cancel-in-progress: false
```

What this setting actually controls:

| Job State | cancel-in-progress: true | cancel-in-progress: false |
|---|---|---|
| **Currently running** | Gets cancelled | **Protected** ✅ |
| **Queued (waiting)** | Gets cancelled | **Still gets cancelled** ⚠️ |

The key insight: `cancel-in-progress` only governs the *running* job. The queue slot holds exactly **one** run — any newer run evicts the previous queued run unconditionally.

## The Mechanics

GitHub Actions concurrency groups enforce:

1. At most **1 running** job per group
2. At most **1 queued** job per group
3. When a new run arrives:
   - If something is running → respect `cancel-in-progress`
   - If something is queued → **always cancel it**, new run takes the queue slot

Think of the queue as a single reservation: it always reflects the most recent pending run.

## What Happened in Our Case

A blog-publish workflow generated 8 commits in 10 minutes → 8 deploy-prod triggers:

```
push #1 → deploy A: running
push #2 → deploy B: queued   (waits for A)
push #3 → deploy C: queued   (cancels B, C takes queue)
push #4 → deploy D: queued   (cancels C, D takes queue)
...
push #8 → deploy H: queued   (last one standing)
deploy A completes → deploy H: runs → success
```

Result: #2–#7 cancelled (6 runs), #1 and #8 executed.

## Is This a Problem?

**Not in our case.** The blog-publish commits only flip `published: true` in a frontmatter file. Deploy #8 reflects the final state — skipping #2–#7 doesn't matter.

**When it would be a problem:**

```yaml
# DB migrations that must run in order:
# migration A → migration B → migration C
# If B and C get queue-cancelled, only A applies — broken schema
```

## Solutions

### Option 1: Keep as-is (fine when final state is what matters)

```yaml
concurrency:
  group: deploy-prod
  cancel-in-progress: false
```

Works for frontend deploys, static asset updates — anything where "latest wins."

### Option 2: Unique group per commit

```yaml
concurrency:
  group: ${{ github.sha }}
  cancel-in-progress: false
```

Every commit gets its own group → every run executes. Watch your resource usage.

### Option 3: Filter out noisy triggers

```yaml
on:
  push:
    branches: [main]
    paths:
      - 'lib/**'
      - 'supabase/functions/**'
      - '!docs/blog-drafts/**'  # skip published:true marker commits
```

The root fix: don't trigger deploys for commits that don't need them.

## Summary

| Setting | Protects Running | Protects Queued | Use When |
|---|---|---|---|
| `cancel-in-progress: true` | ❌ | ❌ | Fast iteration, interrupts OK |
| `cancel-in-progress: false` | ✅ | ❌ | Frontend deploy (latest wins) |
| `group: ${{ github.sha }}` | — | ✅ (all run) | DB migrations, ordered deploys |

`cancel-in-progress: false` is commonly misread as "all runs will execute." It means "don't interrupt the run in progress." If you see mass cancellations, check whether the final deployed state is still correct before panicking.

---
Building in public: https://my-web-app-b67f4.web.app/
#GitHubActions #CICD #buildinpublic
