# SDLC 工程 × WBS カバレッジ監査 — living doc (v1: 2026-06-10)

> **Win版#132 part 254 (2026-06-10)**: user 指示「企画から保守まで全工程で足りないタスクが一つもないように」への**検証可能な回答**。
> 再実行可能な監査手順 + 当日結果。次回監査時は本ファイルの §3-§5 を更新する (履歴は git)。

## 0. 監査の問い

[`AI_DRIVEN_DEV_OPERATING_MODEL.md`](AI_DRIVEN_DEV_OPERATING_MODEL.md) §2 は「各工程に欠落タスクを作らない」を要求する。本監査は **SDLC 7 工程それぞれに open (pending / in_progress) な WBS タスクが存在するか**を実データで確認し、不足があれば追加、重複があれば解消する。

## 1. 方法 (再実行手順)

1. PostgREST で全件数 + phase 分布を取得 (`Prefer: count=exact` / PostgREST 1000 cap は count header で回避):
   - 総タスク `3,159` / 未完了 (pending+in_progress) `807` / **phase 列設定済み `123` (3.9%)** (2026-06-10 時点)
2. phase 設定済み分の工程×status 集計。
3. **phase 未設定 96.1% への補正**: category / title prefix (`[企画]` `[設計]` `[実装]` `[テスト]` `[リリース]` `[保守]` 等) による proxy 分類で open タスクを工程へ写像。
4. 工程ごとに「open タスク 0 = 欠落」を判定。欠落時のみタスク追加 (追加は title 重複 NOT EXISTS guard 必須 = [WBS-DEDUP] 再発防止)。

## 2. 結果 (2026-06-10): 全 7 工程に open タスクあり = 欠落 0

| # | 工程 (phase) | tagged open | proxy open | 代表 open タスク (実在 id) | 判定 |
|---|--------------|------------:|-----------:|---------------------------|------|
| 1 | 企画 planning | 0 | 1 | `fcdfe241` [企画] ユーザー要望・新規企画の自動収集とバックログ優先度評価AI連携 (in_progress) | ✅ (thin) |
| 2 | 設計 design | 4 | 5 | `d097e9df` [設計] DESIGN_SPEC AI半自動レビュー / `32731c06` DESIGN.md 準拠 60% ほか | ✅ |
| 3 | 実装 impl | 23 | 597+ | `361c10d4` [実装] SDLC別バックログ実装レーン整備 + **GitHub Issue 系 pool 596 件** (実装実体) | ✅ |
| 4 | テスト test | 5 | 2 | `16f1de2a` [テスト] E2E/結合テストカバレッジ整備 / `3759b8d3` 回帰テスト継続監視 | ✅ |
| 5 | リリース release | 0 | 7 | `c6406237` #1495 iOS/Android 同時リリース準備 / `ea87d61a` GA リリース / `2d9cace9` リリースチェックリスト自動監査 | ✅ |
| 6 | 運用 ops | 17 | 95 | Claude Schedule 10 / GHA cron 群 / `e649b0a8` EF cap 維持 ほか | ✅ (厚い) |
| 7 | 保守 maintenance | 1 | 2 | `3be3c294` [保守] 依存更新と技術的負債の棚卸し / `43ada3db` 本番インフラ保守体制 | ✅ (thin) |

**結論: 不足タスクの新規追加は 0 件が正答。** 全工程に open タスクが実在するため、機械的な「工程別タスク一括追加」は [WBS-DEDUP] (2026-04-25 の cartesian INSERT 事故 = 9+ 重複) の再発になる。追加は「該当工程の open が 0 になったとき」のみ行う (§1 手順 4)。

## 3. 監査で検出した是正事項

| 検出 | 内容 | 処置 |
|------|------|------|
| **重複 1 件** | `3cb3aa46` インシデント対応プロセス (2026-04-25 起票 / 定義 = Runbook + RACI + Postmortem template) は、part 245 完了の `8830188a` 成果物 [`ONCALL_INCIDENT_SOP.md`](ONCALL_INCIDENT_SOP.md) が実質充足 (§5 Runbook dispatch 表 / §7 Postmortem テンプレート / §2+§6 役割分担 = RACI 相当) | **本監査と同 PR の migration で completed-by-reference 化** (形式 RACI 表が将来必要なら SOP 改訂として別 Issue) |
| **タグ欠損** | phase 列 96.1% 未設定 — 本監査の主精度制約 | 既存 handoff で対応中: `361c10d4` (L2/Codex) + [`cross-instance-prs/done/20260603_wbs_sdlc_phase.md`](cross-instance-prs/done/20260603_wbs_sdlc_phase.md)。**新タスク追加不要** |
| **thin 工程 watch** | planning open 1 / maintenance open 2 — 欠落ではないが薄い | 次回監査で open 0 化していたら追加検討 (§1 手順 4 の条件発火) |

## 4. user 標準セッション要求との対応 (verify 済み回答)

| 要求 | 現状 (本監査時点) |
|------|-------------------|
| 3 レーン (Antigravity+Gemini / VSCode+Codex / VSCode+Claude) | [`AI_DRIVEN_DEV_OPERATING_MODEL.md`](AI_DRIVEN_DEV_OPERATING_MODEL.md) §1 が canonical (L3 = 本インスタンスのみ駆動可 / L1・L2 は user 実行) |
| 24 社公式 doc を毎回 read | §4 の 2 層機構が現実版 canonical: 層 A per-task verify-first (context7 / WebFetch) + 層 B 週次 vendor-digest (最新 [`vendor-digests/2026-06-07.md`](vendor-digests/2026-06-07.md))。**user 指定 24 社リストは §4 ローテ対象と完全一致を確認 (差分 0 / 追加不要)** |
| 毎セッション WBS 1 タスク完了 + main merge | 運用モデル §3 セッション儀式が規定。本日 session 実績: 3 件 (PR #3180 / #3181 / 本 PR) |
| 古い docs 削除 | 運用モデル §5 (verify-first + inbound grep) が手順。既知 stale 候補 = `.github/COMPRESSED_PROMPT_V3.md` (§7 follow-up flag 済 / 削除には inbound 精査が必要なため本監査では未実施) |
| WBS 不足タスク追加 | **本監査の結論: 追加 0 件が正答 (§2)** |

## 5. 次回監査の発火条件

- いずれかの工程の open タスクが 0 になったとき (担当 milestone 完了時に発生しやすい)
- phase backfill (`361c10d4`) 完了後 — proxy 分類を tagged 集計へ置換して再監査
- 四半期境界 ([`IT_SECURITY_POLICY_V1.md`](IT_SECURITY_POLICY_V1.md) §7 の棚卸しと同周期で可)

## Links

- [`AI_DRIVEN_DEV_OPERATING_MODEL.md`](AI_DRIVEN_DEV_OPERATING_MODEL.md) — 3 レーン + SDLC 7 工程 + セッション儀式 (正本)
- [`ONCALL_INCIDENT_SOP.md`](ONCALL_INCIDENT_SOP.md) — `3cb3aa46` 充足の根拠成果物
- `docs/cross-instance-prs/done/20260603_wbs_sdlc_phase.md` — phase backfill handoff (L2)
- [`QUARTERLY_ROADMAP.md`](QUARTERLY_ROADMAP.md) / [`MVP_SCOPE.md`](MVP_SCOPE.md) — 工程の中身の正本
