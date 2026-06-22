# L2 (Win Codex) 実装 handoff — 2026-06-10 設計完了 3 件の実装残

> From: Win Claude (L3 / part 262) / To: **Win Codex (L2)** / Priority: **medium** (うち #2599 Phase A は high 寄り)
> 背景: 本日 parts 252-261 で設計・策定タスクを 12 件解消した際、**split 型** (策定 = L3 完了 / 実装 = L2 残) で
> Issue を open 維持した実装項目を集約する。各 Issue に criteria 状況 comment 済み — 本 doc は Codex 着手用の front door。

## 1. Issue #2599 — Flutter 縮退運転モード (Phase A/B)

- **設計仕様**: `docs/SPOF_FAILOVER_STRATEGY.md` §5 (part 258 / merge `28e831825`)
- **Phase A (先行推奨)**: Supabase 接続失敗時の共通エラー UX 統一 — 主要ページの白画面排除 + 「読み込めません + 再試行」統一表示。新規依存なし。
- **Phase B**: 読み取りキャッシュ — ダッシュボード/ノート一覧の最終取得値を `shared_preferences` 系に保持し、接続失敗時に「オフライン表示 (最終更新時刻付き)」へ縮退。**書き込みは対象外** (競合を作らない)。
- 現状 verify 済み: Sentry + `ErrorReporter` + auth-unavailable graceful は実装済 / オフラインキャッシュ未実装。
- 完了条件: Phase A/B 実装 + minimal E2E (実装詳細に依存しない I/O 3 ケース) + Issue #2599 close。

## 2. Issue #2694 — コスト可視化 + 暴走停止アラート (基準 2-3)

- **設計仕様**: `docs/DEV_PROCESS_MULTI_AI.md`「コスト tier ルーティング」節 (part 261 / merge `d0628d389`)
- 基準 2: モデル別トークン消費の集計可視化 — 既存 `quota-monitor.yml` + claude.ai Routine `ci-cd-cost-audit` の拡張として実装 (新規 workflow 乱立を避ける)。
- 基準 3: コスト上限アラート + エージェントループ (トークン過剰消費) 検知の自動停止/通知 — 既存 Slack webhook (`SLACK_WEBHOOK_URL`) 経路を流用。
- 完了条件: 2 点実装 + Issue #2694 close。

## 3. Issue #2847 — 新規参画者向けインフラ構成ドキュメント自動生成パイプライン

- **判定 (part 262 verify)**: 受入基準 3 点すべて自動化実装 (main 更新時の自動生成 / 自動デプロイ / Mermaid 構成図生成) = **L2 本体タスク** (L3 で doc を手書きしても基準を満たさない)。
- 入力素材は既存: `supabase/migrations/` (スキーマ SSOT) / `.github/workflows/*.yml` / `docs/EDGE_FUNCTION_LIST.md` / `docs/DIRECTORY_STRUCTURE.md`。
- 注意: 生成物の置き場は「Wiki または指定 docs」— 既存 `scripts/wiki_compile.py` (Karpathy Compile) との統合を検討してから新規 pipeline を作る ([EF-FIRST] の精神 = 既存基盤優先)。
- 完了条件: pipeline 実装 + 初回生成物 + Issue #2847 close (+ 対応 WBS `c83ff238` flip)。

## 共通規約

- worktree = `.claude/worktrees/instance-codex` / PR gate recipe = docs-only でない場合 minimal E2E 宣言必須 (3 ケース I/O / integration_test or Playwright)。
- 着手時: 各 Issue へ「着手」comment → 完了時 close ([ISSUE-PRECHECK] 整合)。
- 本 handoff 処理後は本ファイルを `docs/cross-instance-prs/done/` へ移動 + **inbound 参照 grep** (part 254 教訓: done/ 移動は dead link を作る)。

*Win版#132 part 262 / 2026-06-10 / L3 設計完了分の実装 handoff (Architect-Implementer ③ パターン)*
