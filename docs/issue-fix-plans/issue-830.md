# Issue Fix Plan #830

- Issue: [[追加要望] パーソナルAIワークベンチでタスクDIY化を支援](https://github.com/kanta13jp1/my_web_app/issues/830)
- Labels: 
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25296973882

## Goal

[追加要望] パーソナルAIワークベンチでタスクDIY化を支援

## Current Context

```text
## 背景

NotebookLM `2fc6d86f-2bbd-4fdc-ad9e-f302d93b5c6e`（Imbue: Empowering Human Agency Through AI Reasoning and Coding）では、AIを「人間の主体性を拡張する道具」として扱い、Sculptorのように複数エージェントを人間が並列管理する思想が示されている。

自分株式会社にはAI役員会議、WBS、ユーザータスク、Self-Devin/Agent系UIがあるため、これらを「自分専用AI作業台」として束ねると、ユーザーがAI任せではなくAIを操縦する体験に寄せられる。

## 追加要望

ユーザーが任意の仕事・学習・開発タスクを登録し、AI役員/エージェントの役割、参照コンテキスト、次アクション、承認待ちステップを1画面で管理できる「パーソナルAIワークベンチ」を追加する。

## 実装スコープ案

- 既存の `wbs_tasks` / user task report / Agent Workspace 系UIとの接続方針を整理
- タスクごとに `目的`、`制約`、`参照メモ/NotebookLMソース`、`担当AIロール`、`次アクション` を保存
- AI提案はユーザー承認後にタスク更新へ反映
- NotebookLM用のスナップショット出力にワークベンチ履歴を含める

## 受け入れ条件

- [ ] ホームまたは業務メニューからワークベンチへ到達できる
- [ ] 新規タスクに目的・制約・AIロール・次アクションを登録できる
- [ ] AI提案とユーザー承認/却下の履歴が保存される
- [ ] 既存WBSまたはuser task reportと少なくとも片方向に連携する
- [ ] 主要ロジックまたはWidgetのテストが追加される

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
