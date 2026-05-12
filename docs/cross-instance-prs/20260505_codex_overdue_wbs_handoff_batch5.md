# [Codex CLI 宛] Overdue WBS task batch 5 — 期限 +3-5 日 next 20 件

**date**: 2026-05-05
**from**: Win Claude (= Win版#132 part 146)
**to**: Win Codex CLI
**priority**: medium-high (= 全件 1-3 日 overdue)
**rule basis**: `[INSTANCE-ROLES]` 5-question matrix + `[WBS-SYNC]` + `[DYNAMIC-CLAIM]` 2 件 cap respect

## Summary

batch 1-4 で計 24 件 triage 済 (= UI top 19 + 補完 5). 本 batch 5 で WBS UI scroll 下
**期限 +3-5 日 next 20 件** を 5-question matrix で振分.

## 振分結果 (= 20 件)

| # | issue | judge | 理由 (5-question matrix) |
|---|---|---|---|
| 1 | [#1324](https://github.com/kanta13jp1/my_web_app/issues/1324) インフラ変更 blast radius 事前可視化 | **Codex** | Q1 schema (impact_log) + Q3 GHA (deploy diff) |
| 2 | [#1374](https://github.com/kanta13jp1/my_web_app/issues/1374) prompt cache + batch API LLM コスト最適化 | **Codex** | Q1 schema (cache) + Q2 EF (router) |
| 3 | [#1375](https://github.com/kanta13jp1/my_web_app/issues/1375) 高解像度 vision Opus 4.7 UI 解析 E2E | **Codex** | Q3 GHA (E2E) + Q2 EF (vision call) |
| 4 | [#1377](https://github.com/kanta13jp1/my_web_app/issues/1377) AI モデル動的 routing | **Codex** | Q2 EF (router logic) + Q1 schema (model perf log) |
| 5 | [#1378](https://github.com/kanta13jp1/my_web_app/issues/1378) 自律 Vault 永続メモリ | **CLOSE 候補** | 既 implementation by Win Claude (= memory_ingest.py / Karpathy 4 cycle 100% / part 132) |
| 6 | [#1379](https://github.com/kanta13jp1/my_web_app/issues/1379) 事前評価 gate (無駄処理防止) | **Codex** | Q2 EF (pre-eval gate) |
| 7 | [#1380](https://github.com/kanta13jp1/my_web_app/issues/1380) 多層 cost サーキットブレーカー | **Codex** | Q1 schema (budget) + Q2 EF (breaker) |
| 8 | [#1381](https://github.com/kanta13jp1/my_web_app/issues/1381) trace ベース可観測性 | **Codex** | #1376 OTel と統合 / Q1 + Q2 |
| 9 | [#1382](https://github.com/kanta13jp1/my_web_app/issues/1382) deny-by-default + auth layer + env var 検証 | **Codex** | Q2 EF (validation gate) + Q1 schema (auth_audit) |
| 10 | [#1385](https://github.com/kanta13jp1/my_web_app/issues/1385) AI 購入アドバイザー「買い時」判定 | **Codex** | Q1 schema (price_history) + Q2 EF (price_judge) |
| 11 | [#1386](https://github.com/kanta13jp1/my_web_app/issues/1386) FSRS 間隔反復 アルゴリズム学習・task 優先度 | **Codex** | Q1 schema (review_card) + Flutter (= impl heavy) |
| 12 | [#1387](https://github.com/kanta13jp1/my_web_app/issues/1387) UTF-8 編集 Python 代替 util | **Codex** | scripts/ Python util |
| 13 | [#1389](https://github.com/kanta13jp1/my_web_app/issues/1389) テナント fail-closed 検証 | **Codex** | Q1 schema (RLS強化) + Q2 EF (validation) |
| 14 | [#1390](https://github.com/kanta13jp1/my_web_app/issues/1390) 評価 score ローカル化 + グローバル昇格 opt-in | **Codex** | Q1 schema (eval_score local/global) + Q2 EF |
| 15 | [#1391](https://github.com/kanta13jp1/my_web_app/issues/1391) schema 変更無停止移行 dual-write | **Codex** | Q1 schema (migration pattern) + Q3 GHA |
| 16 | [#1392](https://github.com/kanta13jp1/my_web_app/issues/1392) スキル資産 portfolio | **Codex** | Q1 schema (skills) + Flutter |
| 17 | [#1393](https://github.com/kanta13jp1/my_web_app/issues/1393) メンタルヘルス risk 管理 | **Win Claude** | sensitive design / AI-CHARACTER-24 #6 倫理 gate / **part 147+ deferred** |
| 18 | [#1394](https://github.com/kanta13jp1/my_web_app/issues/1394) キャリア KPI 月次決算 | **Codex** | #1316 6 部門 KPI と統合 / Q1 + Flutter |
| 19 | [#1395](https://github.com/kanta13jp1/my_web_app/issues/1395) Firebase Spark + 無料枠監視 | **Codex** | Q3 GHA (cron 監視) + docs |
| 20 | [#1396](https://github.com/kanta13jp1/my_web_app/issues/1396) Firestore 最適化 (但し Supabase 主体検証必要) | **検証 → Codex or CLOSE** | Q5 supabase 主体ならスコープ外 確認要 |

## 5-question matrix 統計 (累計 = 44 件)

| judge | batch1 | batch2 | batch3 | batch4 | batch5 | 合計 |
|---|---:|---:|---:|---:|---:|---:|
| Codex | 6 | 6 | 1 | 4 | 17 | **34** |
| Win Claude | 2 | 4 | 1 | 0 | 1 | **8** |
| CLOSE 候補 | 0 | 0 | 0 | 0 | 1 | **1** |
| 検証要 | 0 | 0 | 0 | 0 | 1 | **1** |

Win Claude territory 進捗:
- ✅ part 143 ship: #1316 + #1345
- ✅ part 144 ship: #1292 + #1348
- ✅ part 145 ship: #1366 + #1356
- ⏸ part 147+ deferred: #1393 メンタルヘルス (= AI-CHARACTER #6 倫理 gate / sensitive design / 慎重 spec 必要)

## CLOSE 候補 + 検証要 + Win Claude 1 件 詳細

### #1378 自律 Vault 永続メモリ (CLOSE 候補)

既 implementation:
- `scripts/memory_ingest.py` (= part 111 / Atomic Note 生成 / Obsidian 互換)
- `scripts/wiki_compile.py` (= part 132 / docs/concepts/ 自動生成)
- `scripts/knowledge_vault_lint.py` (= part 105 / Health Score)
- NotebookLM CLI (= part 140 / ゼロトークン Query)
- Karpathy 4 cycle 100% dogfood (= part 132 達成 / BRAIN-32 7/7 ✅)

→ 受入条件 cross-check 後 CLOSE 推奨 (= Win Codex 担当 / 5 min 確認).

### #1396 Firestore 最適化 (検証要)

本プロジェクトは **Supabase 主体** (= PostgreSQL + Edge Functions Deno).
Firebase Hosting のみ使用 (= Firestore 不使用).
→ 受入条件 read 後、Supabase に置換可能なら scope 化 / Firestore 固有なら **CLOSE** 推奨.

### #1393 メンタルヘルス risk 管理 (Win Claude / part 147+ deferred)

reason: AI-CHARACTER-24 #6 倫理 gate + AI-DEV-23 #5 memory + sensitive data RLS 設計が
慎重を要する → 普通の設計 spec template では不足 / **倫理 review section 追加** が必要.
→ part 147+ で **MENTAL_HEALTH_RISK_SPEC.md** 設計 (= AI-CHARACTER 8 原則 + 倫理レビュー追加).

## Codex sprint 1 進捗 (= 2026-05-05 17:30 時点)

batch 1-4 累計 17 件中、本日中に **3 件 merged** (= 18% 完了 / 1 day 内):
- ✅ #2014 [#1283](https://github.com/kanta13jp1/my_web_app/issues/1283) prepush guard (= GHA dispatch block)
- ✅ #2016 [#1296](https://github.com/kanta13jp1/my_web_app/issues/1296) Hedra credit monitor
- ✅ #2018 [#1302](https://github.com/kanta13jp1/my_web_app/issues/1302) blog draft quality gate

残 sprint 1 低-中難度 9 件 + sprint 2 高難度 4 件 + batch 5 新規 17 件 = **計 30 件 推定 ~120h**.

## Codex 累計 hand off (batch 1-5)

| 難度 | 件数 | 推定 |
|---|---:|---:|
| 低 (1-2h) | 8 | ~12h |
| 中 (3-6h) | 14 | ~60h |
| 高 (8-12h) | 10 | ~100h |
| **合計** | **32** | **~172h (= ~22 営業日 / 4 sprint)** |

## dogfood

- `[INSTANCE-ROLES]` 5-question matrix 累計 **44 件** (= batch 1-5 / 過去 1 日 throughput 過去最大更新)
- `[DYNAMIC-CLAIM]` 4 part 連続 cap 厳守 (= 計 6 ship + 1 deferred)
- `[SYNERGY-30]` cross-instance-pr 5 batch (= fleet 横断 hand off 第 1 例継続)
- 「Codex sprint 1 進捗 same-day 18% merged」(= AI-FLEET 効率 第 1 数値化)
- 「CLOSE 候補 / 検証要 surface」(= triage 質向上 / scope creep 防止)
- 「sensitive design は spec template 拡張」(= #1393 由来 / part 147+ で実証)
