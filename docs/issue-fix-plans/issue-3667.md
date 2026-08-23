# Issue Fix Plan #3667

- Issue: [[追加要望] 課金ファネルを計測(billing閲覧/upgradeクリック/checkout成功・cancel)](https://github.com/kanta13jp1/my_web_app/issues/3667)
- Labels: priority:high,追加要望,monetization,growth,analytics
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/28413852663

## Goal

[追加要望] 課金ファネルを計測(billing閲覧/upgradeクリック/checkout成功・cancel)

## Current Context

```text
**P1 / analytics / owner=claude**

BillingService.createCheckoutSession(billing_service.dart:87-96)とsubscription_billing_pageはupgradeクリックやcheckout成否で一切funnel eventを発火しない。既存の無料signupファネルはapp_analyticsで完全計測されているのに、有料ファネルは観測不能。既存のapp_analytics source_details機構を再利用すれば無料funnelと同等に可観測化できる。

### 受け入れ条件
- billing-page閲覧で funnel_billing_view を発火
- upgradeボタンクリックで funnel_upgrade_click を発火
- checkout success/cancel戻りURLで funnel_checkout_success/cancel を発火
- 既存 app_analytics 機構へ記録(新規third-party JSは追加しない)
- ダッシュボードでbilling閲覧→upgradeクリック→成功のステップが追える

統括: #3663 ／ 親: 収益化 #3639


```

## Autonomous Repair Loop

1. Reproduce the smallest failing path for this issue.
2. Apply the minimum safe fix on this branch.
3. Let normal CI run on the draft PR.
4. If CI fails on mechanical issues, `ci-auto-fix.yml` attempts `dart fix --apply` and `deno fmt`.
5. Merge only after CI is green and the issue scope is satisfied.

## Checklist

- [x] Reproduction is clear
- [x] Smallest safe fix is implemented
- [x] Analyze/tests are checked locally; CI is pending the implementation push
- [x] PR notes explain the change and the remaining risk

## Implementation Result

- Reused `app_analytics.source_details` for four billing funnel events.
- Added billing view, upgrade click, checkout success, and checkout cancel tracking.
- Added a 30-day billing funnel card to the admin analytics dashboard.
- Added Flutter and Deno regression coverage for the client and Edge Function allowlist.

## Validation

- `flutter test test/services/growth_acquisition_service_test.dart test/pages/subscription_billing_page_test.dart`
- `flutter analyze` for the changed Dart implementation and tests
- `deno test`, `deno lint`, and `deno check` for the growth-hub acquisition allowlist
- Local Chrome test compilation stalled before execution twice; GitHub Actions remains the browser/build source of truth.

## High-risk Ultrareview Gate

- Reviewer: Claude Code #1
- High-Risk-Ultrareview-Exception: additive analytics allowlist and dashboard wiring only; no auth, secrets, schema, migration, destructive write, or deploy-control change
- Security: unknown funnel keys remain rejected by the explicit server allowlist.
- Rollback: revert the implementation commit; no data rollback is required.
- Data migration: none.
- Prod smoke: verify the billing route and growth-hub deployment after merge.
- Observability: the admin dashboard exposes the three funnel steps and cancellations.
- Unresolved ultrareview findings: none.

## Minimal E2E Gate

- Implementation-detail independent: tests assert visible billing results, upgrade input, and dashboard output.
- Minimal scope: about 3 cases (happy path, cancel path, empty dashboard state).
- E2E: no new Flutter `integration_test/` or Playwright `test/e2e/` route is added.
- E2E-Exception: live completion requires external Stripe and authenticated Supabase state; widget and Edge Function tests cover the deterministic boundary without creating a payment.
