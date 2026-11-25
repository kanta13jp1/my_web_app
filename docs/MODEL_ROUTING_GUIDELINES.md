# AI モデルルーティング戦略・推論コスト最適化ガイドライン (#2694)

従量課金環境における推論コストの膨張と無制御なエージェントループを抑止するため、タスク難易度に応じたモデル選定基準・可視化指標・自動停止ゲートを以下に定めます。

## 1. タスク難易度別モデル選定マトリクス (`config/llm_routing_rules.json`)

| 複雑度ティア (`tier`) | Effort | 優先モデル (Primary) | 対象タスク例 |
| --- | --- | --- | --- |
| **trivial** (低コスト) | `low` | `claude-haiku-4-5` (フォールバック: `llama-3.3-70b-versatile`, `gemini-2.5-flash`) | Flutter 定型 UI 配置・文言調整 (`flutter_ui_routine`, `flutter_widget_copy`)、分類、検索リランク |
| **standard** (標準) | `medium` | `gpt-5.4-mini` | 要約、単発リント修正、一般チャット (`summarization`, `memory.lint`) |
| **complex** (高推論) | `high` | `claude-sonnet-4-6` (フォールバック: `gpt-5.4`, `gemini-3.1-pro-preview`) | アーキテクチャ設計・PR コードレビュー (`architecture_design`, `code_review`) |
| **critical** (最上位推論) | `xhigh` | `claude-opus-4-7` (フォールバック: `gpt-5.5`, `claude-sonnet-4-6`) | Supabase RLS・マイグレーション設計 (`supabase_migration_design`, `supabase_rls_architecture`)、本番障害の根本原因調査 (`root_cause_analysis`)、権限監査 |

### 運用原則

1. Flutter の単純 UI 改修や静的文言調整には `critical` / `complex` モデルを使わず、`trivial` / `standard` レーンに限定します。
2. Supabase のスキーマ変更・RLS 設計・クロススタックの障害調査は誤判断コストが高いため `complex` 以上へ割り当て、残予算が `low_budget_threshold_usd`（$5.00）未満となった場合のみ自動ダウングレードします。

## 2. 外部モデルの費用対効果 PoC 検証基準

新モデル（例: Composer 2 等の低コストモデル）の「他モデルの 20% 以下のコストで同等品質」といった公称値をそのまま前提にせず、採用前には本リポジトリ実課題（Flutter ウィジェット修正 + Supabase RLS/Edge Function テスト）を使ったオフライン PoC で以下を測定して比較します。

- 1 タスクあたりの実トークン消費量 (`input_tokens + output_tokens + thinking_tokens`) と実推定コスト (`estimated_cost_usd`)
- 静的解析 / テスト一発通過率および差し戻し再試行回数（再試行ループを含めた実質コスト）
- `scripts/dynamic_llm_router.py --telemetry-input <jsonl>` によるフロンティア比率 (`frontier_cost_share`) の変化

## 3. コスト可視化・異常ループ自動停止ポリシー (`loop_guard`)

エージェントの無限再試行やトークン急騰を防ぐため、`scripts/dynamic_llm_router.py`・Edge Router (`effort_router.ts`)・AI コスト監視 UI (`AiComputeCostMonitorView`) で以下を監視し、いずれかに該当した時点で**自動停止 (`auto_halted = true`) および管理者アラート**を発火します。

| 検知条件 | 既定閾値 | 挙動 |
| --- | --- | --- |
| 連続リトライ / 同一反復ループ (`consecutive_retry_loop`) | 連続 `>= 5` 回 | 新規呼び出しを自動停止・警告バナー表示 |
| セッション内トークン消費急騰 (`token_burn_spike`) | 合計 `>= 120,000` tokens | 自動停止・モデル別トークン内訳の点検要求 |
| 分間呼び出しレート超過 (`call_rate_spike`) | `>= 12` calls/min | スロットリング停止 |
| 予算上限到達 (`budget_cap_exceeded`) | 残予算 `<= 0` または日別/月別コスト上限超過 | 自動停止・管理者閾値確認までブロック |
