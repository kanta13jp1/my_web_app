# 機能リリースサイクル方針 (隔週) — 自分株式会社

> **Win版#132 part 255 (2026-06-10)**: WBS `39b30ef2` (milestone `paying-100` / category business-product /
> 定義 = 隔週 release note / changelog page) の成果物。**方針 v1 (CEO 承認で発効 / 初回サイクル起点日は CEO 確定)**。

## 0. このドキュメントについて

- **目的**: 機能リリースの**隔週サイクル**を確立する方針の正本 (SSOT)。「いつ・何を・どう伝えるか」のリズムを定義する。
- **完了の定義 (honest scope)**: 本書は cadence の「設計・文書化」が成果物。**実際に隔週で回っている実績はまだ無い** — 初回サイクル運行 (§5) から実績が始まる。リリース手順そのもの ([`RELEASE_CHECKLIST_ROLLBACK.md`](RELEASE_CHECKLIST_ROLLBACK.md)) や四半期計画 ([`QUARTERLY_ROADMAP.md`](QUARTERLY_ROADMAP.md)) は本書の範囲外。
- **既存資産の上に乗る (新規開発ゼロ)**: release note 生成は自動化済み (`scripts/generate_release_notes.py` → `web/release-notes.json` / PR・GitHub Releases・deploy metadata から決定的に生成 = [`release-notes/README.md`](release-notes/README.md))。表示面も既存 (`release_notes_page.dart` / `changelog_manager_page.dart` / `development_achievements_page.dart`)。**本書が足すのはリズムと編纂規律のみ** ([EF-FIRST] / [EF-CAP-50] 非該当)。

## 1. 3 層の整合 (非重複の軸分け)

| 層 | 正本 | 問い |
|----|------|------|
| 四半期 | [`QUARTERLY_ROADMAP.md`](QUARTERLY_ROADMAP.md) | この四半期に何を達成するか |
| **隔週 (本書)** | RELEASE_CYCLE_POLICY.md | **この 2 週間で何を出し、ユーザーにどう伝えるか** |
| 毎リリース | [`RELEASE_CHECKLIST_ROLLBACK.md`](RELEASE_CHECKLIST_ROLLBACK.md) | 1 回のデプロイを安全にどう実行するか |

**技術デプロイは継続デプロイのまま** (main merge → `deploy-prod` 即時 / [CONCURRENCY] cancel-in-progress: false)。隔週サイクルは**その上の対外コミュニケーション・編纂のリズム**であり、デプロイを 2 週間貯める意味ではない (リスク集中を避ける = 原則 7)。

## 2. 隔週サイクルの定義

| 項目 | 規定 |
|------|------|
| 周期 | **2 週間** (起点曜日 = 金曜 JST 案 / 初回起点日は `【CEO確定】` §5) |
| Cycle 計画 (Day 1) | milestone ([`MVP_SCOPE.md`](MVP_SCOPE.md) / QUARTERLY_ROADMAP) から今 cycle の feature 候補を WBS で選定。L2 (Codex) 実装レーンへ |
| Cut (Day 12) | cycle 終盤 2 日は新規 feature merge を控え、fix / docs / 計測のみ (soft freeze / 強制力は CI でなく規律) |
| Release note 編纂 (Day 13-14) | 自動生成 JSON (`web/release-notes.json`) を基に、**ユーザー向けの言葉で** highlights を編纂。BRAND_GUIDELINE のトーン / 誇張・未検証数値ゼロ |
| 公開 (Day 14) | release_notes_page / development_achievements ページ (既存 changelog 面) + 必要に応じ blog/SNS 連携 (既存 blog 自動化 / [AUTO-REPLY] cap 遵守) |
| ふりかえり (次 cycle Day 1) | 前 cycle の出荷実績 vs 計画 + deploy-prod 成功率を 5 分で確認 (重い retro 儀式は作らない = 原則 6) |

## 3. Release note 編纂規律

- **自動生成が事実の正本** (PR/Release/deploy metadata = 決定的)。編纂は「翻訳」であり事実の追加・誇張をしない ([REAL-DATA])。
- highlights は最大 5 件 (利用者価値があるもののみ)。内部 refactor / CI 変更は含めない (changelog page には残る)。
- 障害・既知問題があった cycle は **隠さず記載** ([`ONCALL_INCIDENT_SOP.md`](ONCALL_INCIDENT_SOP.md) §7 postmortem と整合 / 信頼 = 資産)。
- 言語: JA 主 / EN は blog 連携時に既存 pipeline に従う。

## 4. 役割 (3 レーン整合 = [`AI_DRIVEN_DEV_OPERATING_MODEL.md`](AI_DRIVEN_DEV_OPERATING_MODEL.md))

| 工程 | 担当 |
|------|------|
| Cycle 計画の叩き台 / note 編纂ドラフト / gate | L3 (Win Claude) |
| feature 実装 / fix / 自動化スクリプト保守 | L2 (Win Codex) |
| Cycle scope 最終決定 / note 公開承認 / 起点日確定 | **CEO** |

## 5. 初回サイクル (発効条件)

- 起点日: `【CEO確定】` (案: 直近の金曜 2026-06-19 を Cycle #1 Day 1 とし、公開 = 2026-07-03)。
- 発効 = CEO が起点日を確定し、Cycle #1 の release note が公開された時点。**それまで本書は「確立済み」を名乗らない** (方針の存在 ≠ 運用実績)。
- Cycle #1 の計画候補は WBS `paying-100` / `beta` milestone の in_progress 群から選定 (新規タスク追加はしない — [`SDLC_WBS_COVERAGE_AUDIT.md`](SDLC_WBS_COVERAGE_AUDIT.md) §2 の通り不足なし)。

## 6. 計測 (最小)

- cycle ごと: 出荷 feature 数 / deploy-prod 成功率 (既存 [`PRODUCTION_MONITORING_RUNBOOK.md`](PRODUCTION_MONITORING_RUNBOOK.md) の監視値を参照するだけ / 新規計測基盤は作らない)。
- 3 cycle 回して負荷過大なら周期を月次へ見直す (規律のための規律にしない / 原則 9)。

## 7. Deferred (本書では扱わない)

| 項目 | 行き先 |
|------|--------|
| release note の in-app 通知 / バッジ UI | L2 Issue (必要になったら起票) |
| note 編纂の AI 自動ドラフト化 | 既存 blog-draft 自動化の拡張として別タスク |
| EN 同時公開の完全自動化 | #1950 ブログ/ニュース配信 E2E の継続スコープ |

## 8. Philosophy Alignment ([`PHILOSOPHY.md`](PHILOSOPHY.md) 9 原則)

- **原則 1 (CEO 感)**: scope 決定・公開承認・起点日 = CEO (§4/§5) ✅
- **原則 4 (6 部署)**: リリース = マーケ営業部の定常発信に接続 (§2 公開) ✅
- **原則 5 (商品=価値)**: note は利用者価値のみ記載 (§3) ✅
- **原則 6 (資本=時間)**: 既存自動化の上にリズムだけ足す / 重い儀式を作らない (§0/§2/§6) ✅
- **原則 7 (資産負債)**: 継続デプロイ維持でリスク集中回避 / 正直な note = 信頼資産 (§1/§3) ✅
- **原則 8 (KPI)**: 出荷数・成功率を既存監視から参照 (§6) ✅
- **原則 9 (IPO)**: 持続可能なリズム / 3 cycle で見直し条項 (§6) ✅

**7+/9 ✅**。

## Links

- [`release-notes/README.md`](release-notes/README.md) — 自動生成機構 (事実の正本)
- [`RELEASE_CHECKLIST_ROLLBACK.md`](RELEASE_CHECKLIST_ROLLBACK.md) / [`QUARTERLY_ROADMAP.md`](QUARTERLY_ROADMAP.md) — 上下の層
- [`PRODUCTION_MONITORING_RUNBOOK.md`](PRODUCTION_MONITORING_RUNBOOK.md) — §6 計測の参照元
- [`BRAND_GUIDELINE.md`](BRAND_GUIDELINE.md) — §3 トーン
- [`SDLC_WBS_COVERAGE_AUDIT.md`](SDLC_WBS_COVERAGE_AUDIT.md) — release 工程カバレッジの実測
