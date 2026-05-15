# Asset Management WBS Plan

Last updated: 2026-05-16

## Current WBS Snapshot

- Active WBS tasks: 486
- Active tasks scheduled for `2026-05-15 -> 2026-05-15`: 366
- Issue-linked active tasks: 380
- Owner concentration: Codex owns 440 active rows

This is not a realistic execution plan. The rebaseline in
`20260516083100_rebalance_wbs_realistic_asset_plan.sql` treats WBS dates as
planned work dates, estimates effort, and spreads active work by lane capacity.

## Scheduling Rules

- One effort point is a small bounded change.
- Codex capacity is treated as 2 effort points per day.
- Medium feature work is usually 2 effort points.
- Larger sync, import, or simulation work is 3 effort points.
- The asset-management roadmap is pinned first because this session explicitly
  prioritizes the asset/liability board.
- Existing Codex backlog resumes after the pinned asset-management window.

## Asset Management Roadmap

| Issue | Task | Estimate | Planned Start | Planned End |
|---:|---|---:|---|---|
| #2445 | AI asset-management assistant: rule-based insight foundation | 2d | 2026-05-16 | 2026-05-17 |
| #2446 | AI assistant LLM summary via feature flag | 2d | 2026-05-18 | 2026-05-19 |
| #2447 | Supabase sync staging validation logs and audit display | 2d | 2026-05-20 | 2026-05-21 |
| #2448 | Supabase sync conflict resolution UI | 2d | 2026-05-22 | 2026-05-23 |
| #2449 | Staged production write for Supabase persistence | 3d | 2026-05-24 | 2026-05-26 |
| #2450 | Planned vs actual payment difference management | 2d | 2026-05-27 | 2026-05-28 |
| #2451 | Card-billed statement import and reconciliation | 3d | 2026-05-29 | 2026-05-31 |
| #2452 | Account transfer suggestions as managed tasks | 2d | 2026-06-01 | 2026-06-02 |
| #2453 | Payment reminder notifications | 2d | 2026-06-03 | 2026-06-04 |
| #2454 | Repayment simulation | 3d | 2026-06-05 | 2026-06-07 |
| #2455 | CSV import and restore | 2d | 2026-06-08 | 2026-06-09 |
| #2456 | Asset-management QA and operations documentation | 1d | 2026-06-10 | 2026-06-10 |

## Implementation Order

1. Ship #2445 first. It provides deterministic insights and prompt payloads
   without calling an external AI service.
2. Add optional LLM summarization only after #2445 has stable service tests.
3. Finish Supabase validation and conflict handling before enabling production
   writes.
4. Add reconciliation and reminder features after the storage model can safely
   persist monthly operational state.

## Safety Notes

- Money calculations stay in Dart service/repository code.
- AI can summarize or explain already-calculated values, but must not be the
  source of truth for balances, due dates, or available cash.
- Supabase sync stays feature-flagged until conflict resolution and rollback
  paths are proven.
