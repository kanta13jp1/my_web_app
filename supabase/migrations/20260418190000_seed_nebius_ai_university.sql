-- AI大学: Nebius AI Studio (PS版#121 Option A 昇格)
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
  ('nebius', 'overview',
   'Nebius AI Studio — Yandex系欧州AI基盤の高性能推論クラウド',
   '## Nebius AI Studio とは

**Nebius AI Studio** は、旧 Yandex グループが欧州で展開する AI クラウドサービスです。
GPU クラスター + 高性能推論インフラを組み合わせ、**エンタープライズ向けの高品質モデルを OpenAI 互換 API で提供**します。

## 特徴

- **Yandex Technology**: 旧 Yandex AI 研究チームが開発・運営
- **欧州データセンター**: GDPR 準拠、EU 内データ処理
- **高性能モデル**: Llama 3.3 70B など最新オープンモデルに対応
- **OpenAI 互換**: 既存の OpenAI SDK をそのまま利用可能
- **Performance Tier**: 自分株式会社の 4-Tier では performance 層に分類

## ユースケース

| 用途 | 特徴 |
|------|------|
| エンタープライズチャット | 高品質・安定性重視 |
| 長文処理 | 大コンテキスト対応 |
| 欧州規制対応 | GDPR準拠データ処理 |',
   '2026-04-18'),

  ('nebius', 'models',
   'Nebius AI Studio 主要モデル',
   '## 主要モデル

| モデル | 特徴 |
|--------|------|
| **meta-llama/Llama-3.3-70B-Instruct** | デフォルト・バランス最良 |
| meta-llama/Llama-3.1-405B-Instruct | 最高品質・大規模推論 |
| mistralai/Mistral-Nemo-Instruct-2407 | 軽量・高速 |
| Qwen/Qwen2.5-72B-Instruct | 多言語・日本語強 |
| deepseek-ai/DeepSeek-V3 | 最新 MoE アーキテクチャ |

## デフォルトモデル

自分株式会社 AI Hub では `meta-llama/Llama-3.3-70B-Instruct` をデフォルトに設定。
Llama 3.3 70B は Llama 3.1 70B の後継で、推論品質が向上。',
   '2026-04-18'),

  ('nebius', 'api',
   'Nebius AI Studio API 利用方法',
   '## API エンドポイント

```
https://api.studio.nebius.com/v1/chat/completions
```

## 認証

```bash
Authorization: Bearer $NEBIUS_API_KEY
```

## リクエスト例

```json
{
  "model": "meta-llama/Llama-3.3-70B-Instruct",
  "messages": [{"role": "user", "content": "こんにちは"}],
  "max_tokens": 512
}
```

## 自分株式会社での設定

- **Tier**: Performance (4-Tier 自動ルーティング)
- **EF**: `ai-hub` action `provider.chat` / `provider.chat_auto`
- **シークレット**: `NEBIUS_API_KEY` (Supabase Secrets 要設定)',
   '2026-04-18')
ON CONFLICT (provider, category) DO UPDATE
  SET title = EXCLUDED.title,
      content = EXCLUDED.content,
      published_at = EXCLUDED.published_at,
      updated_at = NOW();
