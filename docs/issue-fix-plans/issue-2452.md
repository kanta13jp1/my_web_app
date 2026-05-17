# Issue Fix Plan #2452

- Issue: [[追加要望][P1][資産管理] 口座間移動提案をタスク管理化](https://github.com/kanta13jp1/my_web_app/issues/2452)
- Labels: enhancement,ui,priority:high,flutter,追加要望
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25977877397

## Goal

[追加要望][P1][資産管理] 口座間移動提案をタスク管理化

## Current Context

```text
## 概要
資産/負債ボードを継続運用できる資金繰り管理へ進めるための追加要望です。

## スコープ
- 口座別資金繰りの不足額から移動タスクを作成する
- 移動元、移動先、金額、期限、完了状態を保存する
- 完了済み移動は現在残高に反映済みとして扱う説明を追加する

## 受け入れ条件
- [ ] 移動提案から実行タスクへ変換できる
- [ ] 完了/未完了が口座別資金繰りに反映される
- [ ] 二重計上防止の注記がある

## WBS見積り
- 見積り工数: 2日
- WBS予定開始: 2026-06-01
- WBS予定完了: 2026-06-02
- 同日作業ルール: 1日あたりCodex実装容量を概ね2 effort pointまでとして扱い、同日に詰め込みすぎない

## 注意
金額計算・同期判断はアプリ/Repository/Service層で deterministic に行い、AIは要約・説明補助に留めます。

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
