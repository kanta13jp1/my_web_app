# Issue Fix Plan #795

- Issue: [[追加要望] Task Budget対応のAI自律タスク実行コスト制御](https://github.com/kanta13jp1/my_web_app/issues/795)
- Labels: enhancement,追加要望
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25266885047

## Goal

[追加要望] Task Budget対応のAI自律タスク実行コスト制御

## Current Context

```text
## 背景
NotebookLM ノート `e89d2ca7-1dc9-41a1-8fe2-bad5103a757b` では、AIエージェントが長時間タスクを自律実行する際に、Task Budget のような予算制御でコストと品質を管理する重要性が示されています。本プロジェクトには、WBS同期、Issue同期、選挙データ取得、AIシェア生成、競合ニュース取得など、定期実行・自律実行系の処理が増えています。

## 目的
AI連携タスクごとに品質優先・コスト優先・短時間確認などの実行モードを設定し、API利用量や失敗リスクを可視化しながら安定運用できるようにします。

## 主要要件
- AI実行タスクに budget / mode / expected_tokens / actual_tokens / retry_count を記録する設計を追加する
- WBS同期、Issue同期、AIシェア生成、選挙データ分析などの定期処理に実行予算の概念を導入する
- コスト超過・リトライ過多・未完了タスクをダッシュボードで警告する
- 重要タスクは品質優先、通常巡回タスクはコスト優先など、用途別プリセットを用意する

## 受け入れ条件
- AI実行タスクごとの想定コスト・実績・失敗回数が確認できる
- コスト優先モードでは、長時間タスクが予算超過前に要約・中断・再スケジュールできる
- WBSまたは管理画面上で、AIタスクの実行状況と改善アクションが見える

## 参考
https://notebooklm.google.com/notebook/e89d2ca7-1dc9-41a1-8fe2-bad5103a757b

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
