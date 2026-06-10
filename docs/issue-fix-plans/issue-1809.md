# Issue Fix Plan #1809

- Issue: [[追加要望][P3][Win版] NotebookLM 0b7a7406 Slack & Notion Manual Setup — OPS統合手順文書化](https://github.com/kanta13jp1/my_web_app/issues/1809)
- Labels: enhancement,追加要望,notebooklm
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/27048622800

## Goal

[追加要望][P3][Win版] NotebookLM 0b7a7406 Slack & Notion Manual Setup — OPS統合手順文書化

## Current Context

```text
## 概要
NotebookLM 0b7a7406「Slack and Notion Manual Setup Protocol」の内容を OPS 統合に反映。

## 適用内容
- Slack / Notion の手動セットアップ手順を `docs/OPERATIONS_CHARTER.md` に追記
- 新インスタンス立ち上げ時のチェックリストに Slack/Notion 接続確認を追加
- fleet オンボーディング手順書の整備

## 担当
Win版 (OPS憲章管理)

## 優先度
P3

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
