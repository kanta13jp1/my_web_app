-- AI大学: DeepInfra (PS版#121 Option A 昇格)
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
  ('deepinfra', 'overview',
   'DeepInfra — コスト効率最高クラスのオープンモデル推論プラットフォーム',
   '## DeepInfra とは

DeepInfra は、**数百のオープンソース AI モデルを OpenAI 互換 API で提供する**推論インフラプロバイダーです。Llama、Mistral、Qwen など主要なオープンモデルを、業界最安水準の価格で利用できます。

## 特徴

- **200+ モデル対応**: Llama 3.1 70B、Mistral Large、Qwen 2.5 など多数
- **OpenAI 互換 API**: 既存コードをほぼ変更なしに移行可能
- **低コスト**: GPT-4o 比で最大 10分の1のコストでLlama 3.1 70B を利用可能
- **高スループット**: バッチ推論・並列リクエストに最適化
- **日本語対応**: Llama/Qwen 系モデルで日本語タスクも可

## ユースケース

| 用途 | 推奨モデル |
|------|----------|
| 汎用チャット | Meta-Llama-3.1-70B-Instruct-Turbo |
| コード生成 | Qwen2.5-Coder-32B-Instruct |
| 長文要約 | Mistral-Large-2411 |
| 高速応答 | Meta-Llama-3.1-8B-Instruct |',
   '2026-04-18'),

  ('deepinfra', 'models',
   'DeepInfra 主要モデル一覧',
   '## 主要モデル

| モデル | パラメータ | 特徴 | 価格目安 |
|--------|-----------|------|---------|
| **Meta-Llama-3.1-70B-Instruct-Turbo** | 70B | バランス最良・推奨 | ~$0.35/1Mtok |
| Meta-Llama-3.1-8B-Instruct | 8B | 超高速・低コスト | ~$0.06/1Mtok |
| Mistral-Large-2411 | 123B | 高品質・多言語 | ~$2/1Mtok |
| Qwen2.5-72B-Instruct | 72B | 中国語/日本語強 | ~$0.35/1Mtok |
| Qwen2.5-Coder-32B-Instruct | 32B | コード特化 | ~$0.2/1Mtok |
| deepseek-r1 | 671B | 推論特化 (MoE) | ~$2.5/1Mtok |

## デフォルトモデル

自分株式会社 AI Hub では `meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo` をデフォルトに設定。コストと品質のバランスが最良。',
   '2026-04-18'),

  ('deepinfra', 'api',
   'DeepInfra API 利用方法',
   '## API エンドポイント

```
https://api.deepinfra.com/v1/openai/chat/completions
```

## 認証

```bash
Authorization: Bearer $DEEPINFRA_API_KEY
```

## リクエスト例

```json
{
  "model": "meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo",
  "messages": [{"role": "user", "content": "Hello!"}],
  "max_tokens": 512
}
```

## 自分株式会社での設定

- **Tier**: Budget (4-Tier 自動ルーティング)
- **EF**: `ai-hub` action `provider.chat` / `provider.chat_auto`
- **シークレット**: `DEEPINFRA_API_KEY` (Supabase Secrets 要設定)',
   '2026-04-18')
ON CONFLICT (provider, category) DO UPDATE
  SET title = EXCLUDED.title,
      content = EXCLUDED.content,
      published_at = EXCLUDED.published_at,
      updated_at = NOW();
