# Issue Fix Plan #1702

- Issue: [[追加要望][P2][NotebookLM][fleet] Claude Code Masterclass agentic workflow を fleet 横断で標準化](https://github.com/kanta13jp1/my_web_app/issues/1702)
- Labels: enhancement,priority:medium,追加要望,notebooklm,fleet-synergy
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/26548677200

## Goal

[追加要望][P2][NotebookLM][fleet] Claude Code Masterclass agentic workflow を fleet 横断で標準化

## Current Context

```text
## 背景

NotebookLM `1aced136-1352-4933-b727-...` Claude Code Masterclass: From Foundations to Agentic Workflows + `ed1aac00-a9a0-4937-94c0-...` Mastering Claude: A Guide to Intelligent Collaboration 2 本由来. 12 instance fleet で各 instance の Claude Code 使い方が独自進化していて、agentic workflow (plan→execute→verify→commit) の標準化が未整備.

## 提案

- `docs/CLAUDE_CODE_AGENTIC_WORKFLOW.md` 新規 — fleet 共通の 5 phase template (探索 → 計画 → 実装 → 検証 → handoff)
- 各 phase で使う tool / hook / skill を表で固定
- 失敗 pattern (= 計画スキップで実装が逸脱 / 検証スキップで CI 落ち) と対策をまとめる
- AI_FLEET_SYNERGY_PLAYBOOK の **原則 2 Plan-Execute-Review Synergy** と接続

## 受け入れ条件

- `docs/CLAUDE_CODE_AGENTIC_WORKFLOW.md` 新規 (5 phase template + tool 表)
- inject-rules.txt に `[AGENTIC-WORKFLOW]` 1 行追加 (重要 task で 5 phase 必須)
- AI_FLEET_SYNERGY_PLAYBOOK 原則 2 から相互リンク

## ソース notebook

- [Claude Code Masterclass: From Foundations to Agentic Workflows](https://notebooklm.google.com/notebook/1aced136-1352-4933-b727-)
- [Mastering Claude: A Guide to Intelligent Collaboration](https://notebooklm.google.com/notebook/ed1aac00-a9a0-4937-94c0-)

## 担当候補

Claude Code Win版 (architect) / Codex#2 (exec template script)

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
