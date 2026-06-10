# Issue Fix Plan #1705

- Issue: [[追加要望][P2][NotebookLM] Notion DB ID + WorkOS AuthKit + Gemini Code Assist Quotas を運用統合](https://github.com/kanta13jp1/my_web_app/issues/1705)
- Labels: enhancement,priority:medium,追加要望,notebooklm
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/27079250993

## Goal

[追加要望][P2][NotebookLM] Notion DB ID + WorkOS AuthKit + Gemini Code Assist Quotas を運用統合

## Current Context

```text
## 背景

NotebookLM 運用系 3 本未蒸留:

- `47bd101a-...` Managing Notion Database IDs and API Page Properties
- `1b808a60-...` Streamlining MCP Authentication with WorkOS AuthKit
- `0dbe8df1-...` Gemini Code Assist: Quotas and System Limits

## 提案

- Notion DB ID 管理 → WBS-Notion 連携 (CLAUDE.md 12 instance 正本) の page property 設計を `docs/NOTION_INTEGRATION.md` に書き出す
- WorkOS AuthKit → MCP_AUTH_SECURITY_PRINCIPLES の 10 原則中 Bearer / DCR / Scope 章を実装例で補強
- Gemini Code Assist quotas → AI fallback runbook (= `docs/AI_FALLBACK_RUNBOOK.md`) の Gemini 章に quota 詳細追加 + quota-monitor.yml dashboard に Gemini metric 追加

## 受け入れ条件

- `docs/NOTION_INTEGRATION.md` 新規 (page property mapping + 同期 EF スキーマ)
- MCP_AUTH_SECURITY_PRINCIPLES.md の Bearer + DCR 章に WorkOS AuthKit 実装例追加
- `docs/AI_FALLBACK_RUNBOOK.md` Gemini 章 + quota-monitor.yml の Gemini gauge

## ソース notebooks

3 本.

## 担当候補

Codex#2 (運用 / 同期 EF) / Win版 (auth principles)

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
