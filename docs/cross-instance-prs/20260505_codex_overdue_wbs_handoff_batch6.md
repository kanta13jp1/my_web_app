# [Codex CLI 宛] Overdue WBS task batch 6 — 期限 +5-7 日 next 15 件

**date**: 2026-05-05
**from**: Win Claude (= Win版#132 part 148)
**to**: Win Codex CLI
**priority**: medium (= 全件 1-3 日 overdue)
**rule basis**: `[INSTANCE-ROLES]` 5-question matrix + `[WBS-SYNC]` + `[DYNAMIC-CLAIM]` 2 件 cap respect

## Summary

batch 1-5 で計 44 件 triage 済. 本 batch 6 で **#1397-1412 next 15 件** を 5-question matrix で振分.
sensitive design 候補も並行 surface (= AI ペルソナ系 / 金融 / 農業).

## 振分結果 (= 15 件)

| # | issue | judge | 理由 (5-question matrix) |
|---|---|---|---|
| 1 | [#1397](https://github.com/kanta13jp1/my_web_app/issues/1397) 公式サポート + AI 機能 + community 開発推進ガイド | **Win Claude** (docs) | Q2 docs / **part 149+ deferred** (= `docs/DEV_SUPPORT_GUIDE.md` 候補) |
| 2 | [#1398](https://github.com/kanta13jp1/my_web_app/issues/1398) AI「焦り (Desperation)」状態検知 + 緩和 | **Win Claude (sensitive)** | Q1 schema + AI-CHARACTER #6 倫理 gate / **sensitive 第 2 例候補** |
| 3 | [#1399](https://github.com/kanta13jp1/my_web_app/issues/1399) ユーザー context 応じ「機能的感情」引き出し | **Win Claude** | Q5 architect + AI-CHARACTER 横断 / **part 149+ deferred** |
| 4 | [#1400](https://github.com/kanta13jp1/my_web_app/issues/1400) ハイステークス環境向け「強靭 AI ペルソナ」構築 + test | **Win Claude (sensitive)** | AI-CHARACTER #6 倫理 gate / **sensitive 第 3 例候補** |
| 5 | [#1402](https://github.com/kanta13jp1/my_web_app/issues/1402) AI 企業資金調達 + 投資動向 dashboard | **Codex** | Q1 schema + Q2 EF (news scrape 既基盤拡張) |
| 6 | [#1403](https://github.com/kanta13jp1/my_web_app/issues/1403) 新 LLM 投資ニュース自動要約 + インサイト | **Codex** | Q2 EF (LLM call) |
| 7 | [#1404](https://github.com/kanta13jp1/my_web_app/issues/1404) CFO オフィス機能実装 | **Codex** | Q1 schema + Flutter (= [#1316 6 部門 KPI](#1316) 拡張 / 既 spec 流用) |
| 8 | [#1405](https://github.com/kanta13jp1/my_web_app/issues/1405) NotebookLM + 競合 monitoring UI 統合 | **Codex** | Q1 schema + Flutter (= 既基盤統合) |
| 9 | [#1406](https://github.com/kanta13jp1/my_web_app/issues/1406) CHRO 動的 gamification + 実績評価 | **Codex** | Q1 schema + Flutter (= 6 部門 KPI 連動) |
| 10 | [#1407](https://github.com/kanta13jp1/my_web_app/issues/1407) Agent Mode `/deploy` Cloud Run 検証 | **Codex** | #1354 と重複 (= batch 2) / **重複 close 候補** |
| 11 | [#1408](https://github.com/kanta13jp1/my_web_app/issues/1408) Agent multi-file 編集 + full-project context refactor | **Codex** | Q3 GHA + Q5 dev tooling |
| 12 | [#1409](https://github.com/kanta13jp1/my_web_app/issues/1409) Code Customization コーディング規約自動適用 | **Codex** | Q3 GHA + Q5 lint config |
| 13 | [#1410](https://github.com/kanta13jp1/my_web_app/issues/1410) 米市場価格 + 備蓄 dashboard | **Codex** | Q1 schema + Q2 EF (scrape) |
| 14 | [#1411](https://github.com/kanta13jp1/my_web_app/issues/1411) 農業生産者所得 + コスト simulation | **Codex** | Q1 schema + Flutter (= calc-heavy) |
| 15 | [#1412](https://github.com/kanta13jp1/my_web_app/issues/1412) 消費者+生産者「農政・価格 ニュース」配信 | **Codex** | Q1 schema + Q2 EF (news 既基盤流用) |

## 5-question matrix 統計 (累計 = 59 件)

| judge | batch1 | batch2 | batch3 | batch4 | batch5 | batch6 | 合計 |
|---|---:|---:|---:|---:|---:|---:|---:|
| Codex | 6 | 6 | 1 | 4 | 17 | 10 | **44** |
| Win Claude | 2 | 4 | 1 | 0 | 1 | 4 | **12** |
| CLOSE 候補 / 重複 | 0 | 0 | 0 | 0 | 1 | 1 | **2** |
| 検証要 | 0 | 0 | 0 | 0 | 1 | 0 | **1** |

Win Claude territory 進捗 (= 12 件 / 全期間):
- ✅ 7 ship 済 (= part 143-147)
- ⏸ 5 deferred (= #1393 [済 part 147] + #1397 #1399 + sensitive 2 例 = #1398 #1400)
- 訂正: ⏸ 4 deferred (= #1397 #1398 #1399 #1400 / part 148-150 順次 ship 候補)

## sensitive design 第 2-3 例候補 surface (= part 147 確立 template 適用)

| # | issue | sensitive 観点 | 倫理 review 必須要素 |
|---|---|---|---|
| #1398 焦り検知 | AI 状態 mind-reading risk | 「焦り」誤検知時のラベリング害 / 自律性尊重 / opt-in / mentor 介入 cap |
| #1400 強靭 AI ペルソナ ハイステークス | 高 stakes 判断ミス risk | 医療/金融/法務 NG list / human-in-loop 必須 / 失敗時 rollback |
| #1399 機能的感情引き出し | 操作 (manipulation) risk | dark pattern 禁止 / opt-out 即時 / 倫理 review |

→ part 149-151 で順次 sensitive 設計 spec ship 推奨.

## #1407 重複 CLOSE 候補

[#1407](https://github.com/kanta13jp1/my_web_app/issues/1407) Agent Mode `/deploy` Cloud Run 検証 = batch 2 [#1354](https://github.com/kanta13jp1/my_web_app/issues/1354) と完全同題.
→ 受入条件 cross-check 後、片方を CLOSE 推奨 (= duplicate / 番号若い #1354 を keep).

## Codex sprint 1 進捗 update (= 2026-05-05 18:46 時点 / part 146 1h 後)

batch 1-4 累計 17 件中 **4 件 merged** (= 24% same-day):
- ✅ PR #2014 [#1283](https://github.com/kanta13jp1/my_web_app/issues/1283) prepush guard
- ✅ PR #2016 [#1296](https://github.com/kanta13jp1/my_web_app/issues/1296) Hedra credit monitor
- ✅ PR #2018 [#1302](https://github.com/kanta13jp1/my_web_app/issues/1302) blog draft quality gate
- ✅ PR #2019 [#1304](https://github.com/kanta13jp1/my_web_app/issues/1304) branch protection status

→ 1h で +1 件 progress (= 18% → 24% / Codex 効率継続証拠 第 2 例).

## dogfood

- `[INSTANCE-ROLES]` 5-question matrix 累計 **59 件** (= batch 1-6 / 過去最大更新)
- `[DYNAMIC-CLAIM]` 5 part 連続 cap 厳守
- `[SYNERGY-30]` cross-instance-pr 6 batch (= fleet 横断 hand off 第 1 例継続)
- 「sensitive design 候補 batch 内 surface」第 1 例 (= 4 件 flag / part 149+ ship 計画)
- 「重複 issue surface」第 1 例 (= #1407 #1354)
- 「Codex 効率継続証拠」第 2 例 (= 1h で +6% / 24% same-day 突破)
