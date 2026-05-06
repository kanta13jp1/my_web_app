# Win Claude / Win Codex 宛: WBS top 5 期限近順 2 instance 振分 (= part 158-b)

- **起票元**: Win Claude (= jolly-nash-ac2d96 / 2026-05-07)
- **優先度**: HIGH (= 完了予定 05/17-05/18 が直近)
- **起票理由**: ユーザー指示「WBS のタスクを期限が近いものから進めてください。2 インスタンス制も反映してください」(2026-05-06 / part 158-b session)

## WBS タイムライン上位 5 件 (= /project-gantt 未完了 918 件のうち 完了予定 ascending)

| # | Issue | 件名 | 完了予定 | 担当ラベル | 5Q ⇒ 振分 |
|---|---|---|---|---|---|
| 1 | [#1568](https://github.com/kanta13jp1/my_web_app/issues/1568) | [P1] claude mcp serve によるエージェント・イン・エージェント委譲基盤 | 2026-05-17 | CX | 全 NO ⇒ **Win Codex** |
| 2 | [#1704](https://github.com/kanta13jp1/my_web_app/issues/1704) | [P1][NotebookLM][fleet] Multi-Agent Convergence + 2026 AI Infrastructure Trends を fleet 戦略に反映 | 2026-05-17 | CX | Q1 (architect)+Q4 (AI 大学/競合) YES ⇒ **Win Claude** |
| 3 | [#1563](https://github.com/kanta13jp1/my_web_app/issues/1563) | [P1] Codex in-app browser 視覚 E2E・動的 UI 検証・Playwright 証跡の統合 | 2026-05-18 | CC | 全 NO (= 実装/EF Deno) ⇒ **Win Codex** |
| 4 | [#1628](https://github.com/kanta13jp1/my_web_app/issues/1628) | [P1] NotebookLM 由来タスクに公式情報検証・重複 Issue 検出ゲートを追加 | 2026-05-18 | AUTO | 全 NO (= 実装/EF Deno) ⇒ **Win Codex** |
| 5 | [#1699](https://github.com/kanta13jp1/my_web_app/issues/1699) | [Schedule 監視] daily-report タスク未実行を検出 | 2026-05-18 | CX | 全 NO (= GHA cron / EF) ⇒ **Win Codex** |

> **5-question 振分** (`docs/CODEX_WORKFLOW.md §6`): Q1 architect/設計/docs/memory, Q2 UI design, Q3 triage, Q4 AI 大学/競合/動画, Q5 mobile UAT. **1 つでも YES ⇒ Win Claude / 全 NO ⇒ Win Codex**.

## 振分結果サマリ

- **Win Codex (4 件)**: #1568 / #1563 / #1628 / #1699
- **Win Claude (1 件)**: #1704

`担当ラベル` 列の `CC` (= Claude Code) は UI 表示上のラベルだが、5-question 振分結果が優先される。表中の `CC` (#1563) は実装作業 = Win Codex 振分とする (= UI ラベル更新候補 / 優先度低 / TODO 別 session)。

## Win Codex 着手指針

### #1568 claude mcp serve エージェント・イン・エージェント委譲基盤

- 関連 NotebookLM / docs があれば intake → 設計 spec 化 → 実装 PR の 3 段。
- 既存の MCP server 関連: `~/.claude/hooks/inject-rules.txt`、`docs/MCP_AUTH_SECURITY_PRINCIPLES.md` (= MCP-AUTH-27 / 10 原則 deny-by-default)。
- **MCP-AUTH-27 全 10 原則必須** (= public 公開 MCP). spec 章節は `MCP_AUTH_HARDENING_SPEC.md` 構成踏襲推奨 (= part 152 ship 済).

### #1563 Codex in-app browser 視覚 E2E + Playwright 証跡統合

- Playwright は既存 (`mcp__playwright__browser_*`). Codex の in-app browser 視覚 E2E 実行 + Artifact 化が題目。
- 既存 `Public E2E stability smoke` workflow 拡張で吸収可能性検討 (= GHA workflow 1 本追加 OR 既存に step 追加)。

### #1628 NotebookLM 由来タスク 公式情報検証 + 重複 Issue 検出ゲート

- 既存 `scripts/notebooklm_issue_crosscheck.py` (= part 120) + `[ISSUE-PRECHECK]` rule の延長線上。
- 「公式情報検証」= NotebookLM source の URL fetch + 200/404 check + last-updated 取得 → 古い source は warning。
- 「重複 Issue 検出ゲート」= 既存 crosscheck script を起票前 PR 化 (= GHA workflow_dispatch ハンドル + Issue body に `<!-- nb_id: 8char -->` 埋込)。

### #1699 [Schedule 監視] daily-report タスク未実行検出

- 既存 `daily-report-*.yml` cron が動いた形跡を `docs/daily-reports/<date>.md` 存在 + monitoring_events で検証。
- 24h 内に entry がなければ Issue 自動起票 (= Issue #1422 系の comment dedup 24h pattern 流用)。

## Win Claude 着手指針 (= part 159 セッションで実装)

### #1704 [NotebookLM][fleet] Multi-Agent Convergence + 2026 AI Infrastructure Trends

- 「fleet 戦略に反映」= 既存 `docs/AI_FLEET_SYNERGY_PLAYBOOK.md` (= SYNERGY-30 / 7 原則) と `docs/MULTI_INSTANCE_FLEET.md` (= 2 instance 制) への統合。
- NotebookLM source (= Multi-Agent Convergence + 2026 AI Infra Trends) を `notebooklm use jibun-master-brain` でゼロトークンリサーチ → 抽出された 5+ insight を 2 instance 役割割振 (= Win Claude / Win Codex) と既存 7 原則 PLAYBOOK に紐付け → 1 PR で着地。
- **見積**: 60-90 min Win Claude 工数。
- **PHILOSOPHY-22 9/9 + SYNERGY-30 7/7 + BRAIN-32 7/7** が達成条件。

## SLA

- Win Codex: 4 件すべて **2026-05-17 完了予定 / 2026-05-18 完了予定** = **10 日以内** に PR ship。
- Win Claude: #1704 を **next session (= part 159)** で着手。spec ship のみで OK / 実装は Win Codex hand off 可。

## 受け入れ条件

- Win Codex: 4 PR が main マージ + Issue close まで完了。各 PR タイトルに `[part 158-b 振分]` を含める。
- Win Claude: docs/AI_FLEET_SYNERGY_PLAYBOOK.md または docs/MULTI_INSTANCE_FLEET.md に Multi-Agent Convergence セクション追加 PR 1 本 ship + #1704 close。

## 関連

- `docs/CODEX_WORKFLOW.md §6` (= 5-question matrix)
- `docs/MULTI_INSTANCE_FLEET.md` (= 2 instance 体制)
- `~/.claude/projects/.../memory/project_20260506_win132_part158.md` (= 前回 session 記録 / disk-cleanup + reschedule fix)
- `~/.claude/projects/.../memory/project_20260507_win132_part158b.md` (= 本 session / memory hygiene 強化)
