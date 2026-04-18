-- AI大学: Novita AI コンテンツ seed (PS版 daily-development 2026-04-18)
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
  ('novita_ai', 'overview',
   'Novita AI — 100+モデル対応のクレジット制推論プラットフォーム',
   E'## Novita AI とは\n\nNovita AI は2023年設立の推論インフラ企業。100以上のオープンソース大規模言語モデル・画像生成モデルを、OpenAI互換APIとクレジット課金制で提供する。特にコスト効率と豊富なモデル選択肢が強みで、個人開発者からエンタープライズまで幅広く利用されている。\n\n## 強み\n- **OpenAI互換**: `https://api.novita.ai/v3/openai/` でほぼ無改修移行可能\n- **100+モデル**: Llama・Qwen・Mistral・Phi・Gemmaなど多数\n- **低価格**: Llama-3.1-70B が input/output ともに $0.23/1M という低コスト\n- **クレジット制**: 使った分だけ支払い・サブスクリプション不要\n- **画像生成**: FLUX・Stable Diffusion系も対応\n\n## 主な用途\n- コスト最適化した推論パイプライン\n- 複数モデルのA/Bテスト\n- バッチ処理・非同期ワークフロー',
   '2026-04-18'),
  ('novita_ai', 'models',
   'Novita AI 主要モデル一覧',
   E'## テキスト生成モデル\n\n| モデル | 価格 (input/output per 1M) | コンテキスト | 特徴 |\n|-------|--------------------------|------------|------|\n| meta-llama/llama-3.1-70b-instruct | $0.23/$0.23 | 128K | バランス型・汎用 |\n| meta-llama/llama-3.1-8b-instruct | $0.06/$0.06 | 128K | 超低コスト |\n| Qwen/Qwen2.5-72B-Instruct | $0.23/$0.23 | 32K | 多言語・高精度 |\n| mistralai/mistral-7b-instruct | $0.03/$0.03 | 32K | 最安値帯 |\n| microsoft/phi-3-medium-128k-instruct | $0.14/$0.14 | 128K | 長コンテキスト |\n\n## 画像生成モデル\n- **FLUX.1-schnell**: 高速・低コスト画像生成\n- **stable-diffusion-xl-base-1.0**: SD XLベース汎用\n- **dreamshaper-xl-v2-turbo**: アニメ・イラスト特化\n\n## 音声・動画\n- **Whisper Large V3**: 音声認識\n- **CosyVoice**: 多言語音声合成 (日本語対応)\n\n## 料金体系\n- クレジット購入制: $5〜\n- 有効期限なし・使った分だけ消費',
   '2026-04-18'),
  ('novita_ai', 'api',
   'Novita AI API 入門ガイド',
   E'## APIキーの取得\n1. https://novita.ai にアクセス\n2. "Get Started" → Google/メール認証\n3. Dashboard → API Keys → Create API Key\n4. 新規登録ボーナスクレジットが自動付与される\n\n## クイックスタート (OpenAI互換)\n```python\nfrom openai import OpenAI\n\nclient = OpenAI(\n    api_key="your-novita-api-key",\n    base_url="https://api.novita.ai/v3/openai"\n)\n\nresponse = client.chat.completions.create(\n    model="meta-llama/llama-3.1-70b-instruct",\n    messages=[{"role": "user", "content": "Hello!"}]\n)\nprint(response.choices[0].message.content)\n```\n\n## 自分株式会社での利用\n- **ai-hub EF**: `action: provider.chat` + `provider: novita_ai`\n- **必要シークレット**: `NOVITA_API_KEY`\n- **推奨モデル**: `meta-llama/llama-3.1-70b-instruct` (バランス) or `meta-llama/llama-3.1-8b-instruct` (低コスト)\n\n## ストリーミング対応\n```python\nstream = client.chat.completions.create(\n    model="meta-llama/llama-3.1-70b-instruct",\n    messages=[{"role": "user", "content": "Tell me a story"}],\n    stream=True\n)\nfor chunk in stream:\n    print(chunk.choices[0].delta.content, end="")\n```',
   '2026-04-18')
ON CONFLICT (provider, category) DO UPDATE
  SET title = EXCLUDED.title,
      content = EXCLUDED.content,
      published_at = EXCLUDED.published_at,
      updated_at = NOW();
