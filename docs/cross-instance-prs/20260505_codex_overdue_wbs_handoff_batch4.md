# [Codex CLI 宛] Overdue WBS task batch 4 — UI top 漏れ 4 件 + part 144 deferred 残

**date**: 2026-05-05
**from**: Win Claude (= Win版#132 part 144)
**to**: Win Codex CLI
**priority**: high (= 全件 2 日 overdue)
**rule basis**: `[INSTANCE-ROLES]` 5-question matrix + `[WBS-SYNC]` + `[DYNAMIC-CLAIM]` 2 件 cap respect

## Summary

batch 1 (= 8 件) + batch 2 (= 10 件) + batch 3 (= 2 件) で計 20 件 triage 済。
WBS UI top 19 件中 batch 1-3 でカバー済 15 件 + 100% 完了 1 件 (#1296) + part 143/144 ship 済 4 件
(#1316 #1345 #1292 #1348). 残 **未 triage 4 件** (= UI 上位 #1305 #1376 #1383 #1388) を本 batch で補完.

## 振分結果 (= 4 件 / 全件 Codex)

| # | issue | judge | 理由 (5-question matrix) |
|---|---|---|---|
| 1 | [#1305](https://github.com/kanta13jp1/my_web_app/issues/1305) Stripe 決済基盤統合 + フリーミアム | **Codex** | Q1 schema (subscription/payment/plan) + Q2 EF (Stripe webhook handler) |
| 2 | [#1376](https://github.com/kanta13jp1/my_web_app/issues/1376) OpenTelemetry + Agent SDK 分散 trace | **Codex** | Q1 schema (trace_log) + Q2 EF instrumentation + Q3 GHA (OTel collector setup) |
| 3 | [#1383](https://github.com/kanta13jp1/my_web_app/issues/1383) 定期自動 scraping + 履歴保存 | **Codex** | Q1 schema (scrape_history) + Q2 EF cron + Q3 GHA scheduled |
| 4 | [#1388](https://github.com/kanta13jp1/my_web_app/issues/1388) ローカル埋め込み RAG (API cost 0) | **Codex** | Q1 schema (embedding cache) + Q2 EF (sentence-transformers / fastembed equivalent) |

## 5-question matrix 統計 (累計 = 24 件)

| judge | batch1 | batch2 | batch3 | batch4 | 合計 |
|---|---:|---:|---:|---:|---:|
| Codex | 6 | 6 | 1 | 4 | **17** |
| Win Claude | 2 | 4 | 1 | 0 | **7** |

Win Claude 7 件処理状況:
- ✅ part 143 ship: #1316 (6 部門 KPI) + #1345 (1 In 2 Out)
- ✅ part 144 ship: #1292 (Maintenance SOP) + #1348 (Term Tooltip)
- ⏸ part 145+ deferred: #1356 (dev env setup docs) + #1366 (ストーリー分岐 UI) + 1 (= batch 1 territory)

## Codex 17 件 hand off 推定 (全 batch 集約)

| 難度 | issue | 工数 |
|---|---|---|
| 1h | #1283 GHA 未 Push 検知 | low |
| 1h | #1304 branch 保護自動化 | low |
| 1h | #1286 admin bypass 無効化 + signed commit | low |
| 2h | #1296 Hedra API 監視 (= 既 done) | low |
| 2h | #1308 retry/errhandling | low |
| 4h | #1311 外部連携 standard format | mid |
| 4h | #1302 記事 draft 品質 gate | mid |
| 4h | #1306 MVP + in-app feedback | mid |
| 4h | #1319 Dart SDK bug 報告 Markdown | mid |
| 6h | #1266 VS Code 拡張 remote session | mid |
| 6h | #1354 `/deploy` Cloud Run pipeline | mid |
| 6h | #1323 monitoring 自動設定 | mid |
| 8h | #1305 Stripe 決済 + フリーミアム | high |
| 8h | #1383 自動 scraping + 履歴 | high |
| 10h | #1376 OpenTelemetry + Agent SDK trace | high |
| 12h | #1388 ローカル RAG 埋め込み | high |

合計工数推定: ~80h (= Codex 1 instance / ~10 営業日相当 / 2 sprint)

## 推奨 sprint 構成 (= 2 週間 / 5 営業日 × 2)

**sprint 1 (= 低-中 難度 12 件 / ~36h)**:
#1283 → #1304 → #1286 → #1308 → #1311 → #1302 → #1306 → #1319 → #1266 → #1354 → #1323 → #1356

**sprint 2 (= 高難度 4 件 / ~38h)**:
#1305 (Stripe) → #1383 (scraping) → #1376 (OTel) → #1388 (RAG)

## dogfood

- `[INSTANCE-ROLES]` 5-question matrix 累計 24 件適用 (= batch 1-4 / 1 session 内過去最大 throughput)
- `[DYNAMIC-CLAIM]` 1 session 2 件 cap 厳守 (= part 144 で #1292 + #1348 ship / 残 Win Claude 任 part 145+ deferred)
- 「triage = cap 外」discipline 維持 (= part 143 確立 / 4 batch 連続)
- `[SYNERGY-30]` cross-instance-pr 4 batch (= fleet 横断 hand off 第 1 例継続)
- 「missed Issue 後追い batch」pattern 第 2 例 (= part 143 batch 3 で確立 / part 144 で再現)
