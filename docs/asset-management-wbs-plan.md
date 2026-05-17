# Asset Management WBS Plan

Last updated: 2026-05-16 13:45 JST

## Current WBS Snapshot

- Active WBS tasks still contain schedule drift after GitHub Issue sync.
- The live WBS again had many active rows scheduled for `2026-05-16 -> 2026-05-16`.
- Issue #2447 is completed, so the next asset-management implementation task is #2448.
- New model-evaluation and `/goal`/wrap-up tasks were added as #2520-#2523.

This is not a realistic execution plan. The rebaseline in
`20260516134500_rebalance_wbs_asset_ai_model_plan.sql` treats WBS dates as
planned work dates, estimates effort, and spreads active work by lane capacity.

## Scheduling Rules

- One effort point is a small bounded change.
- Codex capacity is treated as 2 effort points per day.
- Medium feature work is usually 2 effort points.
- Larger sync, import, or simulation work is 3 effort points.
- The asset-management roadmap is pinned first because this session explicitly
  prioritizes the asset/liability board.
- Existing Codex backlog resumes after the pinned asset-management window.
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

| Issue | Task | Estimate | Planned Start | Planned End |
|---:|---|---:|---|---|
| #2517 | Fix WBS list pagination duplication before relying on WBS views | 1d | 2026-05-16 | 2026-05-16 |
| #2523 | `/goal` WBS execution and wrap-up standardization | 1d | 2026-05-16 | 2026-05-16 |
| #2448 | Supabase sync conflict resolution UI | 2d | 2026-05-17 | 2026-05-18 |
| #2449 | Staged production write for Supabase persistence | 3d | 2026-05-19 | 2026-05-21 |
| #2450 | Planned vs actual payment difference management | 2d | 2026-05-22 | 2026-05-23 |
| #2451 | Card-billed statement import and reconciliation | 3d | 2026-05-24 | 2026-05-26 |
| #2452 | Account transfer suggestions as managed tasks | 2d | 2026-05-27 | 2026-05-28 |
| #2453 | Payment reminder notifications | 2d | 2026-05-29 | 2026-05-30 |
| #2454 | Repayment simulation | 3d | 2026-05-31 | 2026-06-02 |
| #2455 | CSV import and restore | 2d | 2026-06-03 | 2026-06-04 |
| #2456 | Asset-management QA and operations documentation | 1d | 2026-06-05 | 2026-06-05 |
| #2520 | Official AI model comparison benchmark foundation | 2d | 2026-06-06 | 2026-06-07 |
| #2521 | Asset-management AI provider routing for GPT/Gemini/Claude Opus | 2d | 2026-06-08 | 2026-06-09 |
| #2522 | Model cost/quality telemetry and monthly review | 2d | 2026-06-10 | 2026-06-11 |

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

1. Keep WBS reliable first: #2517 and #2523 prevent planning drift and session
   state loss.
2. Continue implementation from #2448, the nearest due asset-management feature.
3. Finish Supabase validation and conflict handling before enabling production
   writes.
4. Add reconciliation and reminder features after the storage model can safely
   persist monthly operational state.
5. Add AI model benchmarking before adding more model-specific behavior. Social
   posts can suggest candidates, but project benchmarks decide routing.
6. Defer MoneyForward and MUFG eSmart integrations until local/Supabase state,
   conflict handling, and monthly reporting are stable.

## Safety Notes

- Money calculations stay in Dart service/repository code.
- AI can summarize or explain already-calculated values, but must not be the
  source of truth for balances, due dates, or available cash.
- Supabase sync stays feature-flagged until conflict resolution and rollback
  paths are proven.
- QA and monthly operations for the current asset-management surface are tracked
  in [`ASSET_MANAGEMENT_QA_OPERATIONS_RUNBOOK.md`](ASSET_MANAGEMENT_QA_OPERATIONS_RUNBOOK.md).
