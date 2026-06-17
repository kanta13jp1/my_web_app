# Issue Fix Plan #1840

- Issue: [[追加要望][P2][NotebookLM] 2026-05-03 残 7 本 triage — Notion comments + Claude Design plugin + Gemini RN + Competitor Discovery + Slack-Notion + Tech blog automation](https://github.com/kanta13jp1/my_web_app/issues/1840)
- Labels: enhancement,priority:medium,追加要望,notebooklm
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/27659840237

## Goal

[追加要望][P2][NotebookLM] 2026-05-03 残 7 本 triage — Notion comments + Claude Design plugin + Gemini RN + Competitor Discovery + Slack-Notion + Tech blog automation

## Current Context

```text
## 背景

Win版#132 part 119 で `notebooklm list` 確認時、part 115/117 の triage Issue (#1700-1707 / #1750) で未取込の **7 本** が 2026-05-03 のリストに残存:

| ID | Title | 推奨統合先 |
| --- | --- | --- |
| `9b2e686f` | Building Notion-Style Comments with Flutter and Supabase | VSCode版 — comments_page UI 設計 |
| `6deda071` | Anthropic Claude Design Plugin and Platform Ecosystem | docs/CLAUDE_DESIGN_INTEGRATION.md (Rule 16 拡張) |
| `72d24a65` | Gemini Code Assist Release Notes (Shared) | docs/AI_FALLBACK_RUNBOOK.md Gemini 章 update |
| `239c758b` | Gemini Code Assist Release Notes (Owner / 重複) | 上 72d24a65 と統合 / 重複 close |
| `d83954af` | Competitor Discovery Report: April 2026 Status Update | docs/competitor-reports/202604-discovery.md |
| `0b7a7406` | Slack and Notion Manual Setup Protocol | docs/SLACK_NOTION_SETUP.md |
| `64fc639e` | Automating Technical Blogs with Claude Code and Supabase EF | docs/TECH_BLOG_AUTOMATION.md (= PS#2 T-1 拡張) |

## 提案

各 notebook の蒸留先 docs を新規 or 既存に追加し、12 軸 docs 体系の対応軸に紐付ける.

特に重要:
- **9b2e686f Notion-Style Comments**: 既存 design system + Flutter + Supabase RLS の統合事例 — comments 機能未実装ページに直接転用可能
- **6deda071 Claude Design Plugin**: Anthropic Labs SaaS との統合 (= 既に Rule 16 / `claude-design-handoff` skill 整備済) を更に強化
- **64fc639e Tech Blog Automation**: PS#2 T-1 dispatch (= dev.to + Qiita) と整合 / EF 経由の自動化拡張余地あり

## 受け入れ条件

各 notebook 1 つ以上の docs/ 反映 commit があり、CLAUDE.md の 12 軸 docs 体系に追加される.

## 担当候補

VSCode版 (= UI: 9b2e686f) / Win版 (= docs: 6deda071 / 0b7a7406 / 64fc639e) / PS版#2 (= 64fc639e blog 自動化拡張) / Codex#2 (= AI_FALLBACK_RUNBOOK Gemini RN 反映)

## 関連

- Issue [#1700-1707](https://github.com/kanta13jp1/my_web_app/issues/1700) (= part 115 triage 8 件)
- Issue [#1750](https://github.com/kanta13jp1/my_web_app/issues/1750) (= part 117 triage 2 件)
- Issue [#1647](https://github.com/kanta13jp1/my_web_app/issues/1647) (= 受け入れ条件 #3 完結 / part 118)

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
