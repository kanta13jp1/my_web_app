# LLMオーケストレーター・超低遅延インテントルーター仕様書 (#2776)

## 1. 背景と目的

ユーザー入力の意図解釈（ルーティング）と重い推論を単一の巨大モデルで直列実行すると、TTFT（Time To First Token）および全体応答時間が悪化する。
本仕様では、応答速度に優れた軽量・高速モデル（Groq `llama-3.3-70b-versatile`）を **オーケストレーター（ルーティング専用レイヤー）** として配置し、平均 **500ms 以内**（目標 ~200ms）で構造化 JSON を返却するハイブリッド構成を定義する。

- 軽い定型 Q&A・一般会話 → 高速モデル（Groq 等）のまま即時応答
- 複雑な推論・コード設計・長文分析 → 専門モデル（Claude Sonnet 等）または外部コンテナへ引き継ぎ
- 記憶検索・家計台帳・タスク計画 → 対応する専用 Edge Function / エージェントへルーティング

## 2. アーキテクチャ概要

```text
[Flutter Client: LlmIntentRouterService]
        │ (budget <= 500ms, fail-open local fallback)
        ▼
[Supabase Edge Helper: _shared/llm_intent_router.ts]
        │
        ├─ GROQ_API_KEY 設定済み & <= 500ms
        │    └─► Groq API (llama-3.3-70b-versatile, JSON mode, temp=0)
        │
        └─ キー未設定 / タイムアウト / 500ms超過 / HTTPエラー / JSON不正
             └─► Fail-Open Deterministic Fallback (0-network ルール分類)
        │
        ▼
[Structured JSON Result]
  { intent, targetAgent, targetHandler, confidence, latencyMs, withinSla500ms, provider, model, fallbackUsed }
```

## 3. 構造化 JSON 出力スキーマ

| フィールド | 型 | 説明 |
|---|---|---|
| `intent` | `RouterIntent` | 分類された意図キー |
| `targetAgent` | `string` | 引き継ぎ先の論理エージェント名 |
| `targetHandler` | `string` | 引き継ぎ先のバックエンド処理 / モデル / Edge Function 名 |
| `confidence` | `number` | 0.0〜1.0 の信頼度スコア |
| `latencyMs` | `number` | ルーティング処理時間（ミリ秒） |
| `withinSla500ms` | `boolean` | `latencyMs <= 500` を満たすか |
| `provider` | `"groq" \| "deterministic_fallback"` | 実際に判定を行ったプロバイダ |
| `model` | `string` | 使用モデル（例: `llama-3.3-70b-versatile` / `deterministic-rules-v1`） |
| `fallbackUsed` | `boolean` | フォールバックが発動したか |
| `fallbackReason` | `string \| null` | フォールバック理由（通常時は `null`） |
| `rationale` | `string` | 判定根拠の要約 |

## 4. インテントと引き継ぎ先マッピング

| `intent` | `targetAgent` | `targetHandler` | 用途 |
|---|---|---|---|
| `deep_reasoning` | `reasoning_specialist` | `claude-sonnet-5` | 複雑な比較分析・設計判断・論理推論 |
| `memory_recall` | `memory_retriever` | `memory-hub` | 長期記憶・過去ノート・文脈参照 |
| `finance_ledger` | `finance_analyst` | `core-hub` | 家計簿・資産・レシート・収支記録 |
| `coding_debug` | `code_architect` | `claude-sonnet-5` | コード生成・バグ調査・SQL/CI 修正 |
| `task_planning` | `planner_agent` | `app-hub` | タスク分解・スケジュール・WBS 計画 |
| `quick_qa` | `fast_responder` | `groq-llama-3.3-70b` | 短文質問・用語確認・即時応答 |
| `general_chat` | `fast_responder` | `groq-llama-3.3-70b` | 一般対話・挨拶・分類不能時の安全既定 |

## 5. セキュリティと SLA ガードレール

1. **秘密情報の非ハードコード**: Groq API キーは必ず環境変数 `GROQ_API_KEY`（Supabase Secrets）から取得し、コードやリポジトリに含めない。
2. **厳格な 500ms バジェット**: `AbortController` により既定 `500ms` で外部リクエストを中断し、超過時は即座に決定論的フォールバックへ切り替える（Fail-Open）。
3. **クライアント側 SLA 計測**: `LlmIntentRouterService` は `withinSla500ms`・平均レイテンシ・フォールバック率を集計し、監視テレメトリへ提供できる。
4. **DB マイグレーション不要**: 本コンポーネントはステートレスなオーケストレーション層として実装し、新規 DB スキーマ変更は行わない（`0` DB migrations）。
