# AI Tool Token Usage & Model Specialization Evaluation Matrix (#2733)

## Overview
AIツールの利用量拡大に伴う従量課金コスト増加に対処するため、**システムプロンプトのキャッシュ境界最適化**・**Tool Search Tool パターンによるツール定義肥大化の抑制**・**用途特化型モデルの段階的ディスパッチ**に関する評価基準と計測指標を定義します。

> [!NOTE]
> 以下に示すコスト倍率・削減ポテンシャルは、各プロバイダーの公開価格仕様（Anthropic Prompt Caching / Google Gemini Context Caching）および VS Code の Tool Search / Prefix Caching アーキテクチャに基づく**理論参考値（Analytical Reference Estimates）**です。本番環境の生計測値は `ai_compute_cost_telemetry` および `context_cache_usage_metrics` から定期集計して分離管理します。

---

## 1. Prompt Cache 安定化と Tool Search Tool 設計

| 最適化パターン | 適用箇所 | 仕組みと効果 | 検知すべきアンチパターン |
| --- | --- | --- | --- |
| **静的プレフィックス固定** | `system` + 不変ドメイン仕様 + コアツール定義 | Anthropic `cache_control: { type: "ephemeral" }`（最大 4 ブレークポイント）の前方に不変ブロックのみを配置し、`cache_read_input_tokens` による再利用率を高める | タイムスタンプ・UUID・毎回変わるユーザー状態・ランダム順のキーをプレフィックス先頭へ混入し、毎回キャッシュミス（`0` hit）を起こす |
| **Tool Search Tool (遅延ロード)** | 多数の MCP / 外部連携ツール定義 | 常時必須のコアツールのみプレフィックスに含め、利用頻度の低い拡張ツールは検索・オンデマンド取得へ分離して入力膨張を防ぐ | 数十〜百件超のツールスキーマを全リクエストの先頭へ無条件展開する |
| **長時間タスク再キャッシュ** | 55分超の継続処理 | `prompt_cache_1h.ts` の `PROACTIVE_RECACHE_THRESHOLD_MINUTES`（55分）に基づき 1h TTL 期限切れ前にコンパクトな引継ダイジェストを生成 | 期限切れ後に未圧縮の全履歴を再送してフルプライス書き込みを繰り返す |

### 参照倍率（Anthropic Prompt Caching 公開レートカード基準）
- **5分 TTL キャッシュ書き込み**: 標準入力の **1.25x**（`prompt_cache_1h.ts`: `writeMultiplier5m`）
- **1時間 TTL キャッシュ書き込み**: 標準入力の **2.00x**（`prompt_cache_1h.ts`: `writeMultiplier1h`）
- **キャッシュ読み取り (`cache_read_input_tokens`)**: 標準入力の **0.10x**（`prompt_cache_1h.ts`: `readMultiplier`）
- **キャッシュ再利用指標 (`cacheReuseRatio`)**:
  `cached_read / (cached_read + cache_write + uncached_input)`

---

## 2. 用途特化型 AI モデル分散評価マトリクス

| タスク区分 (`specialization_tier`) | 推奨モデル群 | 主な担当用途 | 理論入力効率化方針（参考値） | 適用条件・制約 |
| --- | --- | --- | --- | --- |
| **検索・ツール探索 (`search_tool_discovery`)** | `gemini-2.5-flash-lite`, `claude-haiku-4-5` | リポジトリ内キーワード探索、Tool Search Tool によるツール候補抽出、ログ分類・タグ付け | 軽量モデルへオフロードし、上位フロンティアモデルの不要コンテキスト消費を回避 | 厳密な JSON Schema または件数上限を指定し、再推論ループを防ぐ |
| **定型実行・構造化抽出 (`bounded_execution`)** | `gpt-5.4-mini`, `gemini-2.5-flash` | 差分抽出、定型要約、スキーマ準拠 JSON 生成、単発ツール引数組み立て | コスト対精度バランスの高い実行モデル＋固定プレフィックスキャッシュで処理 | 破壊的操作や曖昧な仕様判断には使わず、確定済み手順に限定 |
| **高度推論・設計監査 (`complex_reasoning`)** | `claude-sonnet-4-6`, `claude-opus-4-7`, `gemini-3.1-pro-preview` | 複数ファイル横断設計、セキュリティ/RLS 監査、障害根本原因分析 | 静的システムプロンプトへ 1h/5m キャッシュブレークポイントを配置し、複数ターンの読み取りを `0.10x` 倍率帯へ寄せる | 探索作業を事前フィルタリング済みコンテキストで渡し、入力長を抑える |

---

## 3. モニタリング運用フロー
1. Edge Function (`ai-hub`: `ai_monitor.token_cache.record_tool_usage` / `summary` / `diagnose_prefix`) が `ai_compute_cost_telemetry` および `context_cache_usage_metrics` を集計・診断する。
2. 定期監視バッチ (`scripts/monitor_ai_token_cache.py`) がツール別トークン消費量、キャッシュ再利用率、動的プレフィックス不安定警告を評価し、閾値下回り時にレポートを生成する。
3. 管理画面 (`/ai-provider-status?view=token-cache-monitor`) でツール別集計・プレフィックス診断・本評価マトリクスを一元確認する。
