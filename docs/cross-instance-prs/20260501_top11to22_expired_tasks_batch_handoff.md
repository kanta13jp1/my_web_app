# Cross-Instance PR: Top 11-22 期限超過 task batch handoff (= part 104)

**作成**: Win版#132 part 104 / 2026-05-01
**FROM**: Win版 (User 6 度目要望 / N-time alarm Phase 6 dogfood)
**TO**: 複数 instance (= 各 task 別 territory)
**優先度**: HIGH
**期限**: 2026-05-08 (1 週間)
**親軸**: AI_FLEET_SYNERGY #1 + N-time alarm Phase 6 (定常自律実行)

---

## 1. 背景

User 6 度目要望 = N-time alarm rule **第 7 適用** = **Phase 6「定常自律実行」** dogfood.

= part 103 で 1-12 位 triage 完了 → 本 part で **次層 13-22 位** を継続 triage.

「**Phase 5 template 定常運用**」の証 = User reminder なしでも自走 cycle.

## 2. Top 11-22 triage

| # | Title (excerpt) | Owner | 状態 |
| --- | --- | --- | --- |
| 1270 | 手持ち無沙汰の解消とリフレッシュ行動の提案 | VSCode | UI 実装 |
| 1271 | 外部AI連携による日記の自動分析・フィードバック | Codex#2 + VSCode | EF + UI |
| 1272 | 自己接触行動のトラッキング・代替アクション | VSCode | UI 実装 |
| 1274 | TOT 状態のサポートおよびセルフケア Tips | VSCode | UI 実装 |
| 1404 | CFO（最高財務責任者）オフィス機能の実装 | VSCode + Codex#2 | UI + EF (= AI_CHARACTER 軸) |
| 1405 | NotebookLM リサーチ及び競合モニタリングデータ統合 | **Win** | **part 104-105 候補** |
| 974 | AI第二の脳 Ingest パイプライン Obsidian/Markdown Vault | **Win** + VSCode | **SECOND_BRAIN 軸 dogfood** |
| 976 | Knowledge Vault Lint と index.md/log.md 自動メンテナンス | **Win** + PS#1 | **既 PS#1 委譲済 / 進捗確認** |
| 1125 | Build in Public 成果化 Developer Wins 外部発信 | **Win** + PS#2 | **INDIE #7 dogfood** |
| 1124 | (= part 103 で扱い済 / VSCode handoff) | VSCode | continue |

### Win territory 候補 (= 本 part もしくは part 105 で着手)

- **#1405**: NotebookLM 蒸留 routine (= 既 6 例 part 64/66/67/68/92/98) を **monthly cron 化**
- **#974**: SECOND_BRAIN ingest pipeline (= memory/ + Obsidian compat 設計)
- **#976**: PS#1 lint 進捗確認 + log.md auto-maintain script 拡張
- **#1125**: Build in Public 自動化 (= ROADMAP-LOG → dev.to / X 自動投稿)

### handoff 必要

| 対象 instance | task |
| --- | --- |
| VSCode | #1270 / #1272 / #1274 / #1404 (UI 部分) |
| Codex#2 | #1271 (EF) / #1404 (EF) |
| PS#1 | #976 (= 既起票済 part 69 cross-instance-pr の進捗 follow up) |
| PS#2 | #1125 (= dev.to 自動投稿 routine 拡張) |

## 3. Phase 6 適用記録

本 cross-instance-pr 自体が Phase 6 dogfood:
- User trigger に **literal 反応せず**、**template に基づく次層 triage 自走**
- 「User 6 度目同一要望」signal を **「定常運用入った」確認** として処理
- 新規 infra 構築なし → 既存 infra 適用 + 軽量 docs / migration のみ

= AI fleet **成熟期** 突入の証.

## 4. 受入基準

- [ ] 各 instance が担当 task に着手 (= 1 週間以内 / 0% → 30%+)
- [ ] Win 側で #1405 / #974 / #976 / #1125 を 1 件以上着手
- [ ] cross-instance-pr 完了時 `done/` 移動

## 5. 連携

- 前 batch: docs/cross-instance-prs/20260430_top10_expired_tasks_batch_handoff.md (= part 103 / 1-12 位)
- N-time alarm: docs/N_TIME_ALARM_PATTERN.md Phase 6 セクション

---

*Win版#132 part 104 / 2026-05-01 起票 / Top 11-22 batch handoff / N-time alarm Phase 6 dogfood / 定常自律実行*
