-- AI大学: SiliconFlow (硅基流动) コンテンツ seed (PS版 daily-development 2026-04-18)
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
  ('siliconflow', 'overview',
   'SiliconFlow (硅基流动) — 中国最大の推論プラットフォーム',
   E'## SiliconFlow とは\n\nSiliconFlow (硅基流動) は2023年創業の中国AI推論スタートアップ。OpenAI互換APIを通じて100+のオープンソースモデルを低コストで提供する。2024年にユニコーン評価額を達成し、現在は月間数十億トークンを処理する中国最大級のAI推論プラットフォームとなっている。\n\n## 強み\n- **OpenAI互換API**: `https://api.siliconflow.cn/v1/` で既存コードをほぼ無改修で移行可能\n- **無料枠**: 登録後すぐに無料クレジット付与。Qwen2.5-7B等の軽量モデルは無料で利用可能\n- **豊富なモデル**: Qwen2.5シリーズ・DeepSeek-V3・GLM-4・Llama-3シリーズ等\n- **マルチモーダル**: テキスト・画像生成・音声合成まで対応\n\n## 主な用途\n- コスト重視のプロダクション推論\n- 中国語タスクの最適化 (Qwen/GLM)\n- オープンソースモデルの商業利用',
   '2026-04-18'),
  ('siliconflow', 'models',
   'SiliconFlow 主要モデル一覧',
   E'## テキスト生成モデル\n\n| モデル | パラメータ | 価格 (input/output per 1M) | 特徴 |\n|-------|-----------|--------------------------|------|\n| Qwen/Qwen2.5-72B-Instruct | 72B | ¥4.13/¥13.43 | 最高精度・多言語 |\n| Qwen/Qwen2.5-7B-Instruct | 7B | 無料 | 軽量・高速 |\n| deepseek-ai/DeepSeek-V3 | 671B MoE | ¥2.19/¥8.75 | 推論特化 |\n| THUDM/glm-4-9b-chat | 9B | ¥0.44/¥0.44 | 中国語特化 |\n| meta-llama/Meta-Llama-3.1-8B-Instruct | 8B | 無料 | 英語汎用 |\n\n## 画像生成モデル\n- **FLUX.1-dev**: Black Forest Labs製・高品質画像生成\n- **Stable Diffusion 3**: 多様なスタイル対応\n\n## 音声合成\n- **FishAudio**: 日本語・中国語・英語対応の自然な音声\n\n## 料金体系\n- 登録ボーナス: 14元 (約280円) の無料クレジット\n- 月次サブスクリプションで追加割引あり',
   '2026-04-18'),
  ('siliconflow', 'api',
   'SiliconFlow API 入門ガイド',
   E'## APIキーの取得\n1. https://siliconflow.cn にアクセス\n2. 右上「登録」→ メールアドレス・パスワードで登録\n3. ダッシュボード → API Keys → 新規キー作成\n\n## クイックスタート (OpenAI互換)\n```python\nfrom openai import OpenAI\n\nclient = OpenAI(\n    api_key="your-siliconflow-api-key",\n    base_url="https://api.siliconflow.cn/v1"\n)\n\nresponse = client.chat.completions.create(\n    model="Qwen/Qwen2.5-72B-Instruct",\n    messages=[{"role": "user", "content": "こんにちは！"}]\n)\nprint(response.choices[0].message.content)\n```\n\n## 自分株式会社での利用\n- **ai-hub EF**: `action: provider.chat` + `provider: siliconflow`\n- **必要シークレット**: `SILICONFLOW_API_KEY`\n- **推奨モデル**: `Qwen/Qwen2.5-72B-Instruct` (高精度) or `Qwen/Qwen2.5-7B-Instruct` (無料)\n\n## レート制限\n- 無料枠: 2 RPM・1,000 RPD\n- 有料プラン: 20 RPM・100,000 RPD',
   '2026-04-18')
ON CONFLICT (provider, category) DO UPDATE
  SET title = EXCLUDED.title,
      content = EXCLUDED.content,
      published_at = EXCLUDED.published_at,
      updated_at = NOW();
