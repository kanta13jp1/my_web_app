# プロンプトキャッシュ最適化と FinOps コスト監視仕様 (#2788)

## 1. 概要

LLM 呼び出しコストとキャッシュ効率を最適化するため、以下の 3 要素を独立モジュールとして実装する。

1. **静的プレフィックス整列と `cache_control: { type: "ephemeral" }` 付与**:
   - `system_prompt` → `db_schema` → `few_shot` の順に静的ブロックを前方配置し、動的入力（`user_input`）を末尾に配置する。
   - 静的プレフィックス合計が閾値（既定 `1024`）以上の場合に、最後の静的ブロックへ `ephemeral` キャッシュブレークポイントを付与する。
2. **非即時タスクの Message Batches API ルーティング**:
   - 即時性が不要なタスク（`batch_eligible`）を `message_batches_api` へ振り分け、即時応答が必要なタスク（`realtime`）のみ `messages_api` を使用する。
3. **FinOps テレメトリ集計**:
   - `baseInputCount` / `cacheReadCount` / `cacheCreationCount` / `outputCount`、および `cacheHitRate` と `batchOffloadRate` を継続記録する。

## 2. 一次情報と未確認事項の切り分け

- **確認済み一次情報**:
  - Anthropic Prompt Caching (`cache_control: {"type": "ephemeral"}` による静的プレフィックスのキャッシュ): <https://platform.claude.com/docs/en/build-with-claude/prompt-caching>
  - Anthropic Message Batches API (非同期バッチ処理によるコスト削減およびプロンプトキャッシュとの併用): <https://platform.claude.com/docs/en/build-with-claude/batch-processing>
- **未確認事項（Issue 起票元 NotebookLM メモ由来）**:
  - Opus 4.7 新トークナイザーによる「実質トークン消費最大 1.35 倍」という数値、および開発者コンソール上の特定パス（`/usage/cache`）は、本環境から一次公式ドキュメント上で直接裏取りできていないため **未確認** として扱う。実運用では実測値に基づいてコスト監視を行うこと。

## 3. 実装ファイル

- Edge Function 共有モジュール:
  - `supabase/functions/_shared/prompt_cache_finops.ts`
  - `supabase/functions/_shared/prompt_cache_finops_test.ts`
- Flutter サービス・ユニットテスト:
  - `lib/services/prompt_cache_finops_service.dart`
  - `test/services/prompt_cache_finops_service_test.dart`
