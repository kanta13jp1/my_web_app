# Issue Fix Plan #3288

- Issue: [[追加要望] [資産管理] 期限超過・高金利先への一括『連絡テンプレ生成』と送信ログ管理を追加](https://github.com/kanta13jp1/my_web_app/issues/3288)
- Labels: enhancement,追加要望,wbs
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/28068501971

## Goal

[追加要望] [資産管理] 期限超過・高金利先への一括『連絡テンプレ生成』と送信ログ管理を追加

## Current Context

```text
Home画面の追加要望フォームから登録されました。

## 要望
資産管理ページに、期限超過/高金利の支払先へ一括で連絡テンプレ（支払日変更・最低額変更・一時猶予）を生成し、送信ログ（連絡方法・時刻・メモ）を保存する導線を実装する。行動障壁を下げ、滞納の長期化と利息垂れ流しを防止する。

発行元: 資産管理画面 > 開発者向け改善提案
重要度: 確認
画面: /asset-management

## 根拠データ
- overduePayment=3（6/8×2件、6/10×1件）
- cashShortageRisk=9
- monthly_scheduled_interest_estimate_total=96,250.25
- payment_source_missing_count=12

## 変更候補ファイル
- lib/pages/asset_management_page.dart
- lib/services/asset_liability_planning_service.dart
- lib/services/asset_management_insight_service.dart
- supabase/functions/core-hub/index.ts
- docs/asset-management-wbs-plan.md

## 実装手順
- lib/services/asset_liability_planning_service.dart：WorkbookにcreditorContactTasks[]（account_id, due_date, status, contacted_at, next_follow_up, note）を追加し、payment_day_risksから自動生成
- lib/pages/asset_management_page.dart：一括連絡モーダルと口座別テンプレ挿入、送信ボタン、送信履歴モーダルを実装
- lib/services/asset_management_insight_service.dart：critical優先度カードにテンプレ差し込みと推奨アクションを追加
- supabase/functions/core-hub/index.ts：contact_log.submit（POST）を追加（バリデーション含む）
- docs/asset-management-wbs-plan.md：連絡業務のWBSと検証観点を追記

## 受け入れ条件
- 期限超過3件についてテンプレ生成→送信ログ保存→UIに『連絡済み』が反映される
- 次回フォロー日時が自動設定され、カード上に表示される
- 失敗時はエラーメッセージと再送オプションが表示される

## 期待する成果
資産管理画面の改善提案を開発ワークフローに乗せ、該当運用を画面上で確認・実行・監査できる状態にする。

## 分類
- カテゴリ: UX改善
- 優先度: low

```

## Autonomous Repair Loop

1. Reproduce the smallest failing path for this issue.
2. Apply the minimum safe fix on this branch.
3. Let normal CI run on the draft PR.
4. If CI fails on mechanical issues, `ci-auto-fix.yml` attempts `dart fix --apply` and `deno fmt`.
5. Merge only after CI is green and the issue scope is satisfied.

## Checklist

- [ ] Reproduction is clear
- [ ] Smallest safe fix is implemented
- [ ] Analyze/tests/CI are checked
- [ ] PR notes explain the change and the remaining risk
