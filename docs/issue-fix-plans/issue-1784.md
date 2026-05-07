# Issue Fix Plan #1784

- Issue: [[追加要望][P1][NotebookLM] 1aced136 Claude Code Masterclass — agentic workflow 強化パターン適用](https://github.com/kanta13jp1/my_web_app/issues/1784)
- Labels: enhancement,priority:high,automation,追加要望,notebooklm
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25470322509

## Goal

[追加要望][P1][NotebookLM] 1aced136 Claude Code Masterclass — agentic workflow 強化パターン適用

## Current Context

```text
## 概要
NotebookLM ノートブック 1aced136 (Claude Code Masterclass: From Foundations to Agentic Workflows) の未適用内容。

## 適用候補
- Claude Code の agentic workflow ベストプラクティスをこのプロジェクトに適用
- 12インスタンス fleet の agent 設計改善
- CLAUDE.md / inject-rules.txt / hooks 設定の最適化
- SubAgent パターン / tool-use パターンの高度化

## アクション
1. notebooklm use 1aced136 && notebooklm ask で適用可能なパターン抽出
2. CLAUDE.md / inject-rules.txt の改訂候補整理
3. 新規 hook/skill の候補整理

## 担当候補
Win版 (docs + hooks 設計)

## 参照
- NotebookLM: 1aced136-1352-4933-b727-...
- 関連: Issue #1638 (Claude Code未適用Notebook), #1717

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
