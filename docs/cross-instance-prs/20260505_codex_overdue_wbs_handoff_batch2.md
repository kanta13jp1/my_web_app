# [Codex CLI 宛] Overdue WBS task batch 2 — 次 10 件 5-question 振分

**date**: 2026-05-05
**from**: Win Claude (= Win版#132 part 142)
**to**: Win Codex CLI
**priority**: high (= 全件 2-3 日 overdue)
**rule basis**: `[INSTANCE-ROLES]` 5-question matrix + `[WBS-SYNC]` + `[DYNAMIC-CLAIM]` 2 件 cap respect

## Summary

batch 1 (= 8 件 / `20260505_codex_overdue_wbs_handoff.md`) に続く 9-18 番目の overdue task。
[DYNAMIC-CLAIM] cap (= 1 session 2 件) を遵守して Win Claude は claim せず、
全件 triage + 担当判定 + Win Claude 対応の場合は既存 skill 紐付け推奨に留める。

## 振分結果 (= 10 件)

| # | issue | judge | 既存 skill / hand off |
|---|---|---|---|
| 1 | [#1306](https://github.com/kanta13jp1/my_web_app/issues/1306) MVP + in-app feedback | **Codex** (実装) | Flutter widget + Supabase table |
| 2 | [#1311](https://github.com/kanta13jp1/my_web_app/issues/1311) 外部連携標準 format + dynamic mapping | **Codex** (実装/EF) | EF Deno + JSON schema mapping |
| 3 | [#1316](https://github.com/kanta13jp1/my_web_app/issues/1316) 6 部門 KPI 外部 DB 永続化 | **Win Claude** (architect / 6 部署 = PHILOSOPHY-22 #4) | **part 143 設計 spec 候補** |
| 4 | [#1319](https://github.com/kanta13jp1/my_web_app/issues/1319) Dart SDK バグ報告 Markdown 生成 | **Codex** (実装 / dev tool) | Dart script + GHA |
| 5 | [#1323](https://github.com/kanta13jp1/my_web_app/issues/1323) 新規 service deploy 時 monitoring 自動設定 | **Codex** (GHA / EF) | deploy-prod.yml 拡張 |
| 6 | [#1345](https://github.com/kanta13jp1/my_web_app/issues/1345) 「1 In 2 Out」型 UI 整理アシスト | **Win Claude** (UI design) | **part 143 設計 spec 候補** |
| 7 | [#1348](https://github.com/kanta13jp1/my_web_app/issues/1348) 専門用語・法令 inline tooltip | **Win Claude** (UI design + content) | `ui-design` skill + AI 大学 terminology DB |
| 8 | [#1354](https://github.com/kanta13jp1/my_web_app/issues/1354) Agent Mode `/deploy` Cloud Run pipeline | **Codex** (GHA / Cloud Run) | new yml + service account 設定 |
| 9 | [#1356](https://github.com/kanta13jp1/my_web_app/issues/1356) 開発環境自動 setup + proxy 対策 | **Codex** (dev env / scripts) | scripts/ 新規 + setup-cowork pattern |
| 10 | [#1366](https://github.com/kanta13jp1/my_web_app/issues/1366) ストーリー分岐 / 文脈移行 UI action | **Win Claude** (UI design) | `ui-design` skill |

## 5-question matrix 統計

| judge | 件数 |
|---|---:|
| Codex | 6 |
| Win Claude | 4 |

## Win Claude 4 件の処理 path

| # | path | 着手 timing |
|---|---|---|
| #1316 6 部門 KPI 永続化 | 設計 spec (= 重い architect work) | **part 143** primary |
| #1345 1 In 2 Out UI | 設計 spec (= UI 単独で完結 / 軽め) | **part 143** secondary |
| #1348 inline tooltip | `ui-design` skill 経由で widget catalog 化 → AI 大学 terminology DB join | part 143-144 |
| #1366 ストーリー分岐 UI | `ui-design` skill 経由で general action pattern 化 | part 143-144 |

## Codex 6 件の hand off

batch 1 (= 6 件) と合算で **計 12 件** が Codex CLI で同 session triage 推奨。

実装難度低い順:
1. #1283 GHA 未 Push 検知 (= 既存 yml 拡張 / 1h)
2. #1304 branch 保護自動化 (= GitHub API 1 call / 1h)
3. #1296 Hedra API 監視 (= EF + cron / 2h)
4. #1308 retry/errhandling helper (= EF 共通 util / 2h)
5. #1356 dev env setup script (= Bash + WSL / 2h)
6. #1311 外部連携 standard format + dynamic mapping (= 設計込 / 4h)
7. #1302 記事 draft 品質 gate (= textlint + LLM eval / 4h)
8. #1306 MVP + in-app feedback (= Flutter + Supabase / 4h)
9. #1319 Dart SDK bug 報告 Markdown gen (= Dart script / 4h)
10. #1266 VS Code 拡張 remote session (= dev env tooling / 6h)
11. #1354 `/deploy` Cloud Run pipeline (= GHA + Cloud Run / 6h)
12. #1323 monitoring 自動設定 (= deploy-prod.yml 拡張 / 6h)

合計工数推定: ~44h (= Codex 1 instance / ~5 営業日相当)

## dogfood

- `[INSTANCE-ROLES]` 5-question matrix 18 件累計適用 (= batch 1 + 2)
- `[DYNAMIC-CLAIM]` 1 session 2 件 cap 厳守 (= 残 4 件 Win Claude は part 143 deferred)
- `[WBS-SYNC]` overdue triage の 2 batch 化 (= 拡張時 2 batch/session が現実的)
- `[SYNERGY-30]` cross-instance-pr 18 件 = fleet 横断 hand off 第 1 例
