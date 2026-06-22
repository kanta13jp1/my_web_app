# Issue Fix Plan #2939

- Issue: [[追加要望] [資産管理] 支払原資口座の未設定レビュー](https://github.com/kanta13jp1/my_web_app/issues/2939)
- Labels: 
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/26319604371

## Goal

[追加要望] [資産管理] 支払原資口座の未設定レビュー

## Current Context

```text
Home画面の追加要望フォームから登録されました。

## 要望
現状では支払原資口座が未設定のままでも運用できてしまいます。未設定項目を一括で確認・設定できる機能を追加してください。

発行元: 資産管理画面 > 開発者向け改善提案
重要度: 警戒
画面: /asset-management

## 期待する成果
資産管理画面の改善提案を開発ワークフローに乗せ、該当運用を画面上で確認・実行・監査できる状態にする。

## 分類
- カテゴリ: UX改善
- 優先度: medium
- 登録者: kanta13jp@gmail.com
- 登録日時: 2026-05-18T22:36:23.032Z

## WBS連携
このIssue作成後、同じ内容をWBSのユーザー要望タスクとして登録します。

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
