---
title: "cancel-in-progress:true Silently Dropped Our Deploys — GitHub Actions Concurrency Gotcha"
tags: GitHubActions,CI/CD,Flutter,buildinpublic,devops
published: false
---

# cancel-in-progress:true Silently Dropped Our Deploys

## The Symptom

With multiple Claude Code instances pushing in parallel (VSCode, PowerShell, Windows), we noticed commits occasionally not showing up in production:

```
Commit A → push → deploy-prod starts
Commit B → push → deploy-prod starts → A's run gets CANCELLED
```

Commit B's deploy succeeds. Commit A's changes never reach production.

## Root Cause: Misusing `cancel-in-progress: true`

```yaml
# ❌ Dangerous for deploy workflows
concurrency:
  group: deploy-prod
  cancel-in-progress: true
```

`cancel-in-progress: true` cancels any in-progress run in the same concurrency group when a new run starts. For CI workflows (lint, tests) this is fine — you only care about the latest commit. For deploy workflows, **every commit needs to deploy**.

## The Fix

```yaml
# ✅ Safe for deploy workflows
concurrency:
  group: deploy-prod
  cancel-in-progress: false
```

With `false`, new runs queue behind the running job and execute after it finishes. All commits deploy in order.

## Decision Matrix

| Workflow type | cancel-in-progress | Reason |
|---------------|-------------------|--------|
| CI (lint/test) | `true` | Only latest commit needs to pass |
| **Deploy (prod/staging)** | **`false`** | **Every commit must deploy** |
| blog-publish | `true` | Prevents duplicate posts |
| daily-report | `true` | Only latest data needed |

## Queueing Overhead

With `false`, later pushes wait:

```
Max wait = run time × (parallel pushers - 1)
Example: 3 instances push simultaneously → last waits up to 22 min (11 min × 2)
```

For a 5-instance setup, worst case is ~44 minutes for the 5th push. Acceptable for deploy; unacceptable for CI.

## The Actual Fix

```yaml
# .github/workflows/deploy-prod.yml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: false
```

Adding `github.ref` to the group key means different branches run in separate concurrency groups — cross-branch parallelism is preserved.

## Why This Is Easy to Miss

The default GitHub Actions examples often show `cancel-in-progress: true` for "efficiency." It is efficient for CI. For deploy workflows it silently drops commits. With a single developer pushing one commit at a time, you'll never notice — only multi-instance or high-frequency push setups expose it.

---
Building in public: https://my-web-app-b67f4.web.app/
#GitHubActions #CI/CD #buildinpublic #devops
