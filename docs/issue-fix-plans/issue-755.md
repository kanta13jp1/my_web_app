# Issue Fix Plan #755

- Issue: [[追加要望] 【Krisp】SDKを使った音声機能組み込み（将来のAIコーチ機能）](https://github.com/kanta13jp1/my_web_app/issues/755)
- Labels: 
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/24945446240

## Goal

[追加要望] 【Krisp】SDKを使った音声機能組み込み（将来のAIコーチ機能）

## Current Context

```text
Home画面の追加要望フォームから登録されました。

## 要望
【Krisp】SDKを使った音声機能組み込み（将来のAIコーチ機能）

## 期待する成果
【Krisp】SDKを使った音声機能組み込み（将来のAIコーチ機能）

## 分類
- カテゴリ: 機能追加
- 優先度: medium
- 登録者: kanta13jp@gmail.com
- 登録日時: 2026-04-25T16:18:04.656Z

## WBS連携
このIssue作成後、同じ内容をWBSのユーザー要望タスクとして登録します。

```

## Autonomous Repair Loop

1. Reproduce the smallest failing path for this issue.
2. Apply the minimum safe fix on this branch.
3. Let normal CI run on the draft PR.
4. If CI fails on mechanical issues, `ci-auto-fix.yml` attempts `dart fix --apply` and `deno fmt`.
5. Merge only after CI is green and the issue scope is satisfied.

## Codex #1 Update

- Added explicit SDK readiness gates for the future AI coach flow.
- Added a browser-side audio pipeline handoff from mic capture through Krisp filtering, VAD, STT, and coach response.
- Kept external blockers visible: Krisp SDK contract/API key and model distribution terms are still user/vendor decisions.

## Checklist

- [x] Reproduction is clear
- [x] Smallest safe fix is implemented
- [x] Analyze/tests are checked locally
- [x] PR notes explain the change and the remaining risk
