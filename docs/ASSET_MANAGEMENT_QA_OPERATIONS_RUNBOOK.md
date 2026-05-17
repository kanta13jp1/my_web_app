# Asset Management QA and Operations Runbook

Status: repo-managed runbook for Issue #2456.

This runbook keeps the asset/liability board operable while the roadmap adds
Supabase sync, AI summaries, card statement reconciliation, transfer tasks,
model routing, and future external integrations.

## Operating Principles

- Dart service and repository code is the source of truth for amounts, dates,
  risk levels, and cashflow math.
- AI may summarize or explain already-computed results. AI must not recalculate
  balances, due dates, payment totals, or available cash.
- UI code must go through `AssetLiabilityRepository`; it must not call Supabase
  directly.
- SharedPreferences remains the primary local store until Supabase production
  writes are deliberately enabled and verified.
- Supabase reads and writes are controlled separately. Keep writes off unless
  the release note or feature flag evidence explicitly says they are enabled.
- Every change must have a rollback path that preserves local monthly state.

## Source Map

| Area | Primary files | QA focus |
|---|---|---|
| Workbook model | `lib/models/asset_liability_workbook.dart` | Account, debt, cashflow, statement, income, and transfer task contracts |
| Local state | `lib/services/asset_liability_monthly_state_store.dart` | SharedPreferences keys, month scoping, copy behavior, JSON compatibility |
| Persistence payloads | `lib/models/asset_liability_persistence.dart` | Supabase JSON field names, backward-compatible decode, user/month scoping |
| Repository | `lib/services/asset_liability_repository.dart` | Feature flags, sync preview, conflict resolution, audit log |
| Planning math | `lib/services/asset_liability_planning_service.dart` | Deterministic cashflow, payment difference, card billing, transfer suggestions |
| AI summary | `lib/services/asset_management_ai_summary_service.dart` | Feature flag, fallback, PII boundary, no recalculation |
| Insight report | `lib/services/asset_management_insight_service.dart` | Available money, action items, emergency advice, developer requests |
| UI surface | `lib/pages/asset_management_page.dart` | Monthly workflow, save/load, sync affordances, empty/error states |

## Monthly Operator Workflow

Use this flow when closing the previous month or starting the next month.

1. Open the asset-management page and select the target month.
2. Confirm the latest account snapshot is present before editing monthly state.
3. Review payment source defaults and card billing defaults before entering
   one-off monthly overrides.
4. Enter expected income plans and recurring income templates before reviewing
   available cash.
5. Import or enter card statement lines, then compare statement totals with the
   configured card-billed detail total.
6. Review planned payments and record actual payment amounts only after a
   payment is actually completed.
7. Convert account transfer suggestions into managed transfer tasks when the
   movement is actionable. Mark a transfer task complete only after the bank or
   wallet balance already reflects the transfer.
8. Review cashflow rows by due date and payment source. Confirm overdue rows
   are either paid, rescheduled, or intentionally left open.
9. Generate or refresh the AI summary only as an explanation layer. If AI is
   disabled or fails, use the deterministic summary.
10. Save the month locally, then run Supabase sync preview if sync is enabled.
11. Save a monthly snapshot after the month is reviewed and before copying
   forward.

## Supabase Sync Workflow

1. Run preview first. Do not click a write action when preview shows conflict.
2. Treat each target independently:
   - `monthly_state`
   - `payment_source_settings`
   - `card_billing_defaults`
   - `recurring_income_templates`
   - `monthly_snapshots`
3. If remote is empty and local has data, upload is acceptable after checking
   the month key.
4. If local is empty and remote has data, download is acceptable after checking
   user identity and month key.
5. If both sides have data and values differ, record the intended resolution:
   `local_wins`, `supabase_wins`, or `skip`.
6. Confirm the sync audit log records the target, choice, result, and timestamp.
7. If a write fails, keep local data as canonical and retry only after the
   underlying error is understood.

## PR QA Checklist

Use this checklist on every asset-management PR.

### Data and Calculation

- [ ] New monthly state fields are scoped by `monthKey`.
- [ ] Copy-previous-month behavior is intentional and tested.
- [ ] Completed transfer tasks do not double-count projected cash.
- [ ] Card-billed items do not appear as direct cashflow rows unless configured.
- [ ] Paid rows use actual payment amount when present.
- [ ] Payment difference amount is only shown for paid rows with actual amount.
- [ ] Income plans affect available cash only when not received.
- [ ] No AI output becomes a source of truth for a numeric field.

### Supabase and Sync

- [ ] Payload encode/decode accepts snake_case and legacy camelCase where needed.
- [ ] New fields are included in sync equality checks.
- [ ] Preview can distinguish upload, download, conflict, and no-op.
- [ ] Conflict resolution can skip one target without blocking other targets.
- [ ] Feature flag OFF keeps the local-only workflow usable.
- [ ] Failed remote write does not delete local SharedPreferences state.
- [ ] Audit log captures success/failure evidence without PII.

### UI and Manual Smoke

- [ ] Empty month loads without crash.
- [ ] Month change reloads the correct local and remote state.
- [ ] Edit, save, reload, and delete flows survive a hot restart or page reload.
- [ ] Manual sync disabled state is visible and non-blocking.
- [ ] Conflict state explains that automatic overwrite will not run.
- [ ] AI disabled, AI success, and AI fallback states are distinguishable.
- [ ] Long account names and large yen values do not overflow compact panels.

### Tests

Run the narrowest relevant set first, then broaden when shared contracts changed.

```powershell
C:\app\flutter\bin\dart.bat format --output=none --set-exit-if-changed .
C:\app\flutter\bin\flutter.bat analyze --no-pub
C:\app\flutter\bin\flutter.bat test --no-pub `
  test\services\asset_liability_planning_service_test.dart `
  test\services\asset_liability_monthly_state_store_test.dart `
  test\services\asset_liability_repository_test.dart `
  test\services\asset_liability_card_statement_import_service_test.dart `
  test\services\asset_management_insight_service_test.dart `
  test\services\asset_management_ai_summary_service_test.dart
```

If dependency cache was cleaned during session hygiene, run
`C:\app\flutter\bin\flutter.bat pub get` first and revert any unrelated generated
file churn before committing.

## Release Checklist

- [ ] PR body references the issue and has the minimal E2E declaration or an
  explicit implementation-detail exception.
- [ ] PR checks are green.
- [ ] Deploy to Production is green after merge.
- [ ] GitHub Issues WBS Sync is green after merge.
- [ ] Issue comment includes PR number, merge commit, validation commands, and
  deploy/WBS sync run IDs.
- [ ] Merged branch and worktree are removed.
- [ ] C: free space, top memory processes, and leftover process checks are
  recorded in wrap-up.

## Known Caveats

- Some legacy Japanese UI labels in asset-management service files are mojibake.
  Do not rewrite broad labels unless the PR scope is explicitly text cleanup.
- Supabase writes are staged. A read path passing does not imply production
  writes should be enabled.
- External site integrations such as MoneyForward and MUFG eSmart are future
  tasks and require explicit credential/user approval before live side effects.
- Card statement import is reconciliation support, not a live card provider
  integration.
- AI summaries can be stale, unavailable, or provider-specific. The deterministic
  summary must remain usable.
- Transfer tasks represent planned movements. A completed task is assumed to be
  reflected in the current account balance.

## Rollback Paths

| Failure | Immediate action | Recovery |
|---|---|---|
| Bad UI release | Revert or hotfix the Flutter PR | Keep local state untouched; redeploy after checks |
| Bad Supabase payload | Disable writes / use local-only path | Decode remote JSON, choose `local_wins`, then add regression test |
| Sync conflict | Do not auto-resolve | Use preview, pick target-by-target choice, record issue comment |
| AI summary regression | Turn feature flag OFF | Keep deterministic fallback and add prompt/payload test |
| Card double count | Disable affected setting in UI | Add planning-service test for direct vs included-in-card rows |
| Transfer double count | Mark task pending or remove task | Verify account cashflow summary after reload |

## Incident Triage

1. Capture the month key, user-visible symptom, local action, and whether sync
   was enabled.
2. Identify the layer: UI, local state, planning math, Supabase payload,
   repository sync, or AI summary.
3. Reproduce with a unit test before editing production logic.
4. Prefer additive decoders and feature-flagged behavior over destructive data
   migrations.
5. Comment on the GitHub issue with the root cause, affected layer, and
   rollback decision.

## Ownership

- Codex #1 owns deterministic implementation slices, tests, CI, Supabase payload
  review, and merge/deploy follow-through.
- Claude Code #1 owns ambiguous product judgment, design review, prompt policy,
  and non-repo/user-home closure evidence.
- Guarded child subagents may be used only as short-lived workers with recorded
  lead owner, role, scope, validation, risk, and cleanup evidence.
