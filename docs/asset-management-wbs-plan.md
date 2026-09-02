# Asset Management WBS Plan

Last updated: 2026-08-29 JST

## Current WBS Snapshot

- This Codex session used a fresh worktree because the root tree was dirty.
- GitHub Issues WBS Sync succeeded through the latest Issue-triggered run after
  the NotebookLM batch. Manual run `26044482065` was cancelled by concurrency,
  but the last Issue-triggered run `26044490280` completed successfully.
- WBS Auto Reschedule was manually dispatched as run `26044670021` and
  completed successfully at `2026-05-19 00:56 JST`.
- The reschedule updated `880` open WBS tasks with `0` errors:
  `47` pinned tasks now run `2026-05-31 -> 2026-08-09`; GitHub Issue backlog
  then runs `2026-08-10 -> 2027-08-10`.
- #2448, #2449, #2450, #2451, #2452, #2453, #2456, #2508, #2521, and #2522 are
  already closed. The next open pinned asset-management implementation task is
  #2454.
- #2520 remains open only for live provider scoring and final scored verdict;
  the deterministic benchmark foundation and source recheck are already merged.
- NotebookLM requirement extraction now covers all `114` notebooks with `342`
  stable requirement slots linked to GitHub Issues.

The current WBS dates are the live `wbs.reschedule_realistic` output, not an
optimistic same-day backlog. Work should continue from the nearest due pinned
task unless Claude Code routes a product-judgment blocker first.

## Scheduling Rules

- One effort point is a small bounded change.
- Codex capacity is treated as 2 effort points per day.
- The two top-level lanes remain Claude Code #1 and Codex #1. Extra historical
  agent labels are dormant unless explicitly reactivated.
- Medium feature work is usually 2 effort points.
- Larger sync, import, or simulation work is 3 effort points.
- The asset-management roadmap is pinned first because this session explicitly
  prioritizes the asset/liability board.
- Existing Codex backlog resumes after the pinned asset-management window.
- NotebookLM issue extraction is an intake lane, not implementation capacity.
  Scheduled runs should keep the default creation cap of 9 new Issues per day;
  uncapped full backfills require explicit operator intent, dedup evidence, and
  a WBS reschedule immediately afterward.
- Two-instance routing is reflected in planning:
  - Claude Code owns ambiguous product judgment, architecture, prompt policy,
    and review-gate design.
  - Codex owns scoped implementation, SQL/migration review, CI, GitHub
    automation, deterministic checks, and merge follow-through.
- Every session must include memory/disk hygiene:
  - check free RAM and disk at start and wrap-up,
  - prefer fresh worktrees,
  - remove merged task worktrees and stale branches,
  - avoid full dependency/cache repair unless the task requires it.

## Current Goal

Use `/goal` as the durable execution frame when available. The local Codex CLI
is new enough for a pilot, but `codex --help` did not expose a non-interactive
goal command in this shell session, so this plan mirrors the same state through
GitHub Issue, WBS task, branch, PR body, and wrap-up prompt.

Goal statement:

```text
Keep the asset-management roadmap realistic, evaluate AI models with project
benchmarks instead of fixed social-media rankings, and continue implementation
from the nearest due WBS task.
```

## Asset Management Roadmap

Completed before this rebaseline: #2448-#2453, #2456, #2508, #2521, and #2522.
Current open pinned work starts here:

| Issue | Task | Estimate | Planned Start | Planned End |
|---:|---|---:|---|---|
| #2454 | Repayment simulation | 3d | 2026-05-31 | 2026-06-02 |
| #2455 | CSV import and restore | 2d | 2026-06-03 | 2026-06-04 |
| #2520 | Official AI model comparison benchmark foundation | 2d | 2026-06-06 | 2026-06-07 |

## Phase 2 Roadmap

| Issue | Task | Estimate | Planned Start | Planned End |
|---:|---|---:|---|---|
| #2460 | Monthly asset report DB schema | 1d | 2026-06-12 | 2026-06-12 |
| #2461 | EF monthly asset report with snapshot + LLM summary | 2d | 2026-06-13 | 2026-06-14 |
| #2462 | Month-end report cron | 1d | 2026-06-15 | 2026-06-15 |
| #2463 | Monthly report list/detail UI | 2d | 2026-06-16 | 2026-06-17 |
| #2464 | Monthly report integration test | 1d | 2026-06-18 | 2026-06-18 |
| #2465 | Investment assets DB schema | 1d | 2026-06-19 | 2026-06-19 |
| #2466 | Market price fetch/cache EF | 2d | 2026-06-20 | 2026-06-21 |
| #2467 | Investment asset Repository/Service | 1d | 2026-06-22 | 2026-06-22 |
| #2468 | Investment asset input/list UI | 2d | 2026-06-23 | 2026-06-24 |
| #2469 | Investment asset trend graph | 2d | 2026-06-25 | 2026-06-26 |
| #2470 | Investment CSV import | 2d | 2026-06-27 | 2026-06-28 |
| #2471 | Investment validation tests | 1d | 2026-06-29 | 2026-06-29 |
| #2472 | Monthly dashboard layout | 2d | 2026-06-30 | 2026-07-01 |
| #2473 | Net worth panel | 1d | 2026-07-02 | 2026-07-02 |
| #2474 | Cashflow panel | 1d | 2026-07-03 | 2026-07-03 |
| #2475 | Alert panel | 1d | 2026-07-04 | 2026-07-04 |
| #2476 | Anomaly detection DB | 1d | 2026-07-05 | 2026-07-05 |
| #2477 | EF anomaly detection | 2d | 2026-07-06 | 2026-07-07 |
| #2478 | Daily anomaly scan cron | 1d | 2026-07-08 | 2026-07-08 |
| #2479 | Anomaly review UI | 2d | 2026-07-09 | 2026-07-10 |
| #2480 | Department KPI link DB | 1d | 2026-07-11 | 2026-07-11 |
| #2481 | EF department finance summary | 2d | 2026-07-12 | 2026-07-13 |
| #2482 | Finance department asset summary panel | 1d | 2026-07-14 | 2026-07-14 |
| #2483 | Department-linked E2E test | 1d | 2026-07-15 | 2026-07-15 |
| #2484 | AI asset chat DB | 1d | 2026-07-16 | 2026-07-16 |
| #2485 | EF asset chat | 2d | 2026-07-17 | 2026-07-18 |
| #2486 | Sticky chat widget | 2d | 2026-07-19 | 2026-07-20 |
| #2487 | Chat history page | 1d | 2026-07-21 | 2026-07-21 |
| #2488 | PII guardrail | 1d | 2026-07-22 | 2026-07-22 |
| #2489 | Tax DB | 1d | 2026-07-23 | 2026-07-23 |
| #2490 | Furusato tax calculator | 1d | 2026-07-24 | 2026-07-24 |
| #2491 | Medical deduction tracking UI | 1d | 2026-07-25 | 2026-07-25 |
| #2492 | Tax export | 2d | 2026-07-26 | 2026-07-27 |
| #2493 | Invoice skeleton | 1d | 2026-07-28 | 2026-07-28 |
| #2496 | MoneyForward DB schema | 1d | 2026-07-29 | 2026-07-29 |
| #2497 | EF MoneyForward sync | 2d | 2026-07-30 | 2026-07-31 |
| #2498 | MoneyForward daily cron | 1d | 2026-08-01 | 2026-08-01 |
| #2499 | MoneyForward connection UI | 1d | 2026-08-02 | 2026-08-02 |
| #2500 | MoneyForward transaction merge | 1d | 2026-08-03 | 2026-08-03 |
| #2501 | MUFG eSmart Securities DB schema | 1d | 2026-08-04 | 2026-08-04 |
| #2502 | EF MUFG eSmart Securities sync | 2d | 2026-08-05 | 2026-08-06 |
| #2503 | MUFG eSmart daily cron | 1d | 2026-08-07 | 2026-08-07 |
| #2504 | MUFG eSmart connection UI | 1d | 2026-08-08 | 2026-08-08 |
| #2505 | MUFG eSmart holdings merge | 1d | 2026-08-09 | 2026-08-09 |
| #2508 | Memory/disk hygiene KPI dashboard | 2d | 2026-08-10 | 2026-08-11 |

## Implementation Order

1. Continue implementation from #2454, the nearest due open pinned
   asset-management feature.
2. Keep #2454 deterministic: repayment priority, extra payment, payoff date,
   and interest math must live in Dart service tests, not AI output.
3. Complete #2455 before broadening import/export flows.
4. Finish #2520 live-provider scoring only when API keys and operator approval
   are available; no production routing should depend on unverified social-media
   model rankings.
5. Start Phase 2 at #2460 with monthly reports, then investment assets, then
   dashboard/anomaly/tax work.
6. Defer MoneyForward and MUFG eSmart integrations until local/Supabase state,
   conflict handling, monthly reporting, and investment asset storage are stable.

## NotebookLM Requirement Batch

- `notebooklm list --json` returned `114` notebooks.
- All notebooks now have 3 requirement markers, for `342` total NotebookLM
  requirement slots.
- This session backfilled the missing notebooks and created Issues #2829-#2933.
- `scripts/notebooklm_requirements_to_issues.py` now tolerates raw control
  characters inside NotebookLM JSON strings so one malformed answer does not
  block a full batch.
- `.github/workflows/notebooklm-requirements-to-issues.yml` remains the daily
  automation entrypoint. Keep the default cap of 9 created Issues per scheduled
  run and rely on stable markers for dedup.
- After any manual full backfill, immediately run GitHub Issues WBS Sync and
  WBS Auto Reschedule, as was done in this session.

## Safety Notes

### Living Expense Priority Mode (#4999)

- The `生活費優先モード` toggle is shown above the asset-management action
  list and defaults to OFF so the existing severity/date/title order remains
  unchanged.
- ON applies the deterministic emergency-advice order immediately:
  1. minimum living expenses and lifelines (food, housing, and utilities),
  2. contact for overdue payments,
  3. high-interest card loans (annual rate of 10% or more),
  4. all remaining actions.
- Subscription fixed costs are not treated as housing or utilities, even though
  they share the `fullPaymentEstimate` representation. Within each priority
  group, the existing severity/date/title order is preserved.
- Switching OFF rebuilds the report with the original order. The mode changes
  presentation order only; it does not change balances, payment amounts, due
  dates, AI calculations, or persisted financial data.

- Money calculations stay in Dart service/repository code.
- AI can summarize or explain already-calculated values, but must not be the
  source of truth for balances, due dates, or available cash.
- Supabase sync stays feature-flagged until conflict resolution and rollback
  paths are proven.
- QA and monthly operations for the current asset-management surface are tracked
  in [`ASSET_MANAGEMENT_QA_OPERATIONS_RUNBOOK.md`](ASSET_MANAGEMENT_QA_OPERATIONS_RUNBOOK.md).
