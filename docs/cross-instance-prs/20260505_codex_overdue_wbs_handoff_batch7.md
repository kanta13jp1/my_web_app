# [Codex CLI 宛] Overdue WBS task batch 7 — 期限 +7-10 日 next 20 件

**date**: 2026-05-05
**from**: Win Claude (= Win版#132 part 151)
**to**: Win Codex CLI
**priority**: medium (= 期限 +5-10 日 / overdue)
**rule basis**: `[INSTANCE-ROLES]` 5-question matrix + `[WBS-SYNC]` + `[DYNAMIC-CLAIM]` 2 件 cap respect

## Summary

batch 1-6 累計 59 件 triage 済. 本 batch 7 で **#1527-1577 next 20 件** triage.
P0/P1 priority issue (= 主に CI/automation/security 系) が中心 → 大半 Codex.

## 振分結果 (= 20 件)

| # | issue | judge | 理由 |
|---|---|---|---|
| 1 | [#1527](https://github.com/kanta13jp1/my_web_app/issues/1527) W&B Automations AI 評価 CI gate | **Codex** | Q3 GHA + Q2 EF |
| 2 | [#1528](https://github.com/kanta13jp1/my_web_app/issues/1528) W&B Weave LLM trace 品質監視 | **Codex** | Q1 schema + Q2 EF |
| 3 | [#1529](https://github.com/kanta13jp1/my_web_app/issues/1529) W&B Artifacts データ系譜管理 | **Codex** | Q1 schema + Q2 EF |
| 4 | [#1556](https://github.com/kanta13jp1/my_web_app/issues/1556) α版完成判定 + smoke test GHA | **Codex** | Q3 GHA |
| 5 | [#1557](https://github.com/kanta13jp1/my_web_app/issues/1557) CI 失敗 Issue 重複統合 + 自動 close | **Codex** | Q2 EF + Q3 GHA |
| 6 | [#1558](https://github.com/kanta13jp1/my_web_app/issues/1558) Secrets ドリフト監査 daily | **Codex** | Q3 GHA |
| 7 | [#1559](https://github.com/kanta13jp1/my_web_app/issues/1559) AI Tool Watch → Issue/WBS/PR 自動 routing | **Codex** | Q3 GHA + Q2 EF |
| 8 | [#1560](https://github.com/kanta13jp1/my_web_app/issues/1560) WBS/Issues/Notion/Slack 同期 health dashboard | **Codex** | Q1 schema + Q2 EF |
| 9 | [#1561](https://github.com/kanta13jp1/my_web_app/issues/1561) α版 50 user onboarding + 計測 | **Codex** | Q1 schema + Flutter |
| 10 | [#1562](https://github.com/kanta13jp1/my_web_app/issues/1562) Hurl EF API 契約 test + Stop Hook gate | **Codex** | Q3 GHA |
| 11 | [#1563](https://github.com/kanta13jp1/my_web_app/issues/1563) Codex in-app browser 視覚 E2E + Playwright | **Codex** | Q3 GHA |
| 12 | [#1564](https://github.com/kanta13jp1/my_web_app/issues/1564) Claude Code PreCompact/StatusLine 10 instance 記憶保全 | **Win Claude** | architect / hooks 設定 / **part 152+ deferred** |
| 13 | [#1565](https://github.com/kanta13jp1/my_web_app/issues/1565) Codex Thread Automations 低 risk PR 自律消化 | **Codex** | Q3 GHA |
| 14 | [#1566](https://github.com/kanta13jp1/my_web_app/issues/1566) MCP Tool Search 遅延ロード | **Codex** | Q5 dev tooling |
| 15 | [#1567](https://github.com/kanta13jp1/my_web_app/issues/1567) Linux CI bubblewrap sandbox | **Codex** | Q3 GHA |
| 16 | [#1568](https://github.com/kanta13jp1/my_web_app/issues/1568) claude mcp serve agent-in-agent | **Codex** | Q5 dev tooling |
| 17 | [#1569](https://github.com/kanta13jp1/my_web_app/issues/1569) 高 risk PR ultrareview 必須 gate | **Codex** | Q3 GHA |
| 18 | [#1574](https://github.com/kanta13jp1/my_web_app/issues/1574) Worktree registry + 衝突防止 preflight | **Codex** | Q5 dev tooling + Q3 GHA |
| 19 | [#1575](https://github.com/kanta13jp1/my_web_app/issues/1575) Schedule 実行履歴 + RLS + 監査 DB化 | **Codex** | Q1 schema + Q2 EF |
| 20 | [#1577](https://github.com/kanta13jp1/my_web_app/issues/1577) WorkOS AuthKit MCP 認可強化 | **Win Claude (sensitive)** | MCP-AUTH-27 10/10 必須 / **part 153+ deferred sensitive 第 4 候補** |

## 5-question matrix 統計 (累計 = 79 件)

| judge | batch1-6 | batch7 | 合計 |
|---|---:|---:|---:|
| Codex | 44 | 18 | **62** |
| Win Claude | 12 | 2 | **14** |
| CLOSE / 重複 / 検証 | 4 | 0 | **4** |

Win Claude territory 進捗 (= 14 件 / 全期間):
- ✅ part 143-150 ship 9 件 (= 6 通常 + 3 sensitive)
- ⏸ part 152+ deferred 5 件 (= #1397 #1399 #1564 #1577 sensitive 第 4 候補 + 1 残)

## sensitive design 第 4 候補 surface

[#1577](https://github.com/kanta13jp1/my_web_app/issues/1577) WorkOS AuthKit MCP 認可 = **MCP-AUTH-27 10/10 deny-by-default 必須**
→ MCP server security 領域は通常 8/8 + 7/7 を超える 10/10 必須 / sensitive design 第 4 例として
template §2 領域定義に「MCP server / 認可 layer」を追加候補.

## Codex sprint 1 進捗 update (= part 148 → part 151 / ~30 min)

batch 1-4 累計 17 件中 **4 件 merged (= 24% same-day)** = part 148 確認済から変化なし.
Codex も batch 7 並行で着手すると capacity overflow risk. → **sprint 1 を優先 / batch 7 は sprint 2 に組込推奨**.

## dogfood

- `[INSTANCE-ROLES]` 5-question matrix 累計 **79 件** (= batch 1-7 / 過去最大更新)
- `[DYNAMIC-CLAIM]` 6 part 連続 cap 厳守
- `[SYNERGY-30]` cross-instance-pr 7 batch (= fleet 横断 hand off 第 1 例継続)
- 「sensitive design 第 4 候補 surface」第 1 例 (= MCP-AUTH 領域 / 10/10 必須適用候補)
- 「Codex sprint priority 提言」第 1 例 (= sprint 1 優先 / batch 7 sprint 2 組込推奨)
