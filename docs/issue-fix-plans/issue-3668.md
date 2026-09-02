# Issue Fix Plan #3668

- Issue: [[追加要望] サインイン中アプリにアップグレード常設導線+使用量ナッジ(AI質問 N/30 今月)を追加](https://github.com/kanta13jp1/my_web_app/issues/3668)
- Labels: priority:high,ux,追加要望,monetization,growth
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/28487230525

## Goal

[追加要望] サインイン中アプリにアップグレード常設導線+使用量ナッジ(AI質問 N/30 今月)を追加

## Current Context

```text
**P1 / conversion / owner=claude**

アプリ内アップグレード入口がツールカタログタイルとapp_hubボタンしか無く、home_pageにアップグレードバナーもAI機能近傍の使用量表示も無い。壁に当たる前に '残りN回' を見せることが転換動機になる。

### 受け入れ条件
- AI機能近傍に '今月 N/30' の使用量表示を出す
- homeに'アップグレード'チップ(/billing)を常設
- subscription_billing_page.dart:332-356 の_UsageCardに30上限+残数をprogress barで表示
- Proユーザーには上限表示を出さない(または無制限表示)

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

- Added a persistent home usage card with the current-month `N/30` count, remaining queries, and `/billing` upgrade chip.
- Added the 30-query free-plan limit, remaining count, and progress bar to the billing usage card.
- Pro and Team users see an unlimited label without a quota progress bar.
- Kept the upgrade entry point visible when usage loading fails, and stacked the card safely on narrow viewports.

## Validation

- `flutter test --no-pub test/services/billing_service_test.dart test/widgets/home_billing_nudge_test.dart test/pages/subscription_billing_page_test.dart` (15 tests passed)
- `flutter analyze --no-pub` for the seven changed Dart implementation and test files
- `git diff --check`
- Live authenticated Supabase usage and post-merge browser smoke remain CI/deployment verification items.

## High-risk Ultrareview Gate

- Reviewer: Claude Code #1
- High-Risk-Ultrareview-Exception: additive usage display and billing navigation only; no auth, secrets, schema, migration, payment mutation, or deploy-control change
- Security: usage remains read-only and uses the existing authenticated billing status endpoint.
- Rollback: revert the implementation commit; no data rollback is required.
- Data migration: none.
- Prod smoke: verify the signed-in home and `/billing` route after the exact commit deploys.
- Observability: the visible count and existing billing funnel analytics cover the changed path.
- Unresolved ultrareview findings: none.

## Minimal E2E Gate

- Implementation-detail independent: the test asserts user-visible input/output, not private internals.
- Minimal scope: about 3 cases (happy path, error path, recovery or empty state).
- E2E: Flutter `integration_test/` flow or Playwright `test/e2e/` route.
- E2E-Exception: manual verification: widget tests cover free, Pro, unavailable usage, and narrow layout; live status requires authenticated Supabase state
