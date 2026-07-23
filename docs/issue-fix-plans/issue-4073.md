# Issue Fix Plan #4073

- Issue: [[追加要望] [資産管理] 支払原資口座の残高不足を先読みして自動警告する機能](https://github.com/kanta13jp1/my_web_app/issues/4073)
- Labels: enhancement,追加要望,wbs
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/29978175539

## Goal

[追加要望] [資産管理] 支払原資口座の残高不足を先読みして自動警告する機能

## Current Context

```text
Home画面の追加要望フォームから登録されました。

## 要望
見込み残高が不足する口座がある場合、そのショートフォール額と支払い期限に基づき、より強調された緊急アドバイスを生成し、ユーザーが不足を解消するための口座移動提案へ直接アクセスし実行できる導線を強化します。現金口座の不足は特に重要視し、画面上部に固定表示されるアラートや、視覚的に分かりやすいインジケーターで警告します。

発行元: 資産管理画面 > 開発者向け改善提案
重要度: 確認
画面: /asset-management

## 根拠データ
- 口座一覧: 現金 / 残高:4,817円
- 負債マスタ詳細: KDDI / 支払原資:現金 / 今月支払予定額:5,764円
- 口座別見込み: 現金 / 見込み残高:-947円 / リスク:short
- 口座移動提案: 三井住友銀行大塚支店 -> 現金 / 金額:947円 / 期限:2026/06/25

## 変更候補ファイル
- lib/services/asset_management_insight_service.dart
- lib/pages/asset_management_page.dart
- lib/models/asset_liability_workbook.dart

## 実装手順
- lib/services/asset_management_insight_service.dart に、account_cashflow_summaries で is_short: true となっている口座があった場合、そのショートフォール額と支払い期限に基づいて、より強調された緊急アドバイスを生成するロジックを追加する。
- 生成される緊急アドバイスに、具体的な不足口座名、不足額、対応すべき口座移動提案への直接リンクを含める。
- lib/pages/asset_management_page.dart で、この緊急アドバイスが最も目立つようにUIを調整する。例えば、画面上部に固定表示されるアラートバーや、視覚的に分かりやすいインジケーターなど。
- 口座移動提案を承認・実行するボタンを、不足口座の警告メッセージの近くに配置し、タップで直接タスク管理画面へ遷移できるようにする。

## 受け入れ条件
- 見込み残高が不足している口座がある場合、その口座名、不足額、不足を解消するための口座移動提案が画面上で明確に警告表示されること。
- 警告メッセージから、対応する口座移動タスクへ直接アクセスし、実行できる導線が用意されていること。
- 口座移動が実行されると、リアルタイムで見込み残高が更新され、警告が解消されること。

## 期待する成果
資産管理画面の改善提案を開発ワークフローに乗せ、該当運用を画面上で確認・実行・監査できる状態にする。

## 分類
- カテゴリ: UX改善
- 優先度: low
- 登録者ID: 0339ff05-7a57-43d3-827d-249ca4230838
- 登録日時: 2026-07-17T02:12:53.503Z


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
