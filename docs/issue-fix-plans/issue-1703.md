# Issue Fix Plan #1703

- Issue: [[追加要望][P2][NotebookLM][competitor] Cursor / Devin / W&B / Descript を AI 大学 + 競合21社の月次 watch に追加](https://github.com/kanta13jp1/my_web_app/issues/1703)
- Labels: enhancement,priority:medium,追加要望,notebooklm
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/26700012523

## Goal

[追加要望][P2][NotebookLM][competitor] Cursor / Devin / W&B / Descript を AI 大学 + 競合21社の月次 watch に追加

## Current Context

```text
## 背景

NotebookLM 由来の最新 competitor / AI tool 5 本未取込:

- `fdea9e6d-...` Cursor Product Updates and Agent Innovation Changelog
- `f985728b-...` Devin Documentation Release Notes 2026
- `7ccb0520-...` Weights & Biases: Comprehensive AI Developer Platform Guide
- `2f516389-...` Mastering Descript: AI Video Editing and Underlord Co-Editor Guide
- `f56cc07c-...` TraceHawk vs Datadog: AI Agent Observability in 2026

## 提案

- AI 大学 provider 評価 (Cursor / Devin / W&B / Descript / TraceHawk / Datadog) → seed migration
- 競合 21 社モニタリング cron に Cursor + Devin (= Claude Code 直接競合) を追加
- AI_VIDEO_PRINCIPLES に Descript + Underlord の章を追加 (= AI 動画パイプラインに統合)
- AI agent observability (TraceHawk / Datadog) を `docs/OBSERVABILITY_PRINCIPLES.md` 新規にまとめる

## 受け入れ条件

- AI 大学に 6 provider 追加 (Codex#1 担当 = template ベース migration)
- competitor-monitoring.yml の watch list に Cursor + Devin 追加
- AI_VIDEO_PRINCIPLES に Descript 章 (= VSCode / Win 担当)
- `docs/OBSERVABILITY_PRINCIPLES.md` 新規 (= TraceHawk vs Datadog 蒸留)

## ソース notebooks

5 本。詳細は背景参照.

## 担当候補

Codex#1 (AI大学 seed) / VSCode版 (UI) / Win版 (observability principles)

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
