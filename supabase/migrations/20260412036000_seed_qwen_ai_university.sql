-- Windows版#60: Qwen (qwen) — AI大学40社目
-- Alibaba Cloud 製 多言語対応LLM・DashScope API 公開済み

INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
  ('qwen', 'overview',
   'Qwen — Alibaba Cloud 製 多言語LLMプラットフォーム',
   E'## Qwen とは\n\nQwen (通義千問) は**Alibaba Cloud**が開発する大規模言語モデルシリーズ。\n中国・杭州拠点、2023年公開。\n\n「企業・開発者が自社サービスにAIを組み込める」をミッションとする。\n\n## 特徴\n\n### オープンソース戦略\n\n| 強み | 詳細 |\n|------|------|\n| **オープンモデル** | Qwen2.5シリーズをHugging Faceで公開 |\n| **多言語精度** | 中国語・日本語・英語で最高水準 |\n| **コンテキスト長** | 最大128Kトークン対応 |\n| **コスト効率** | GPT-4比で大幅に低コスト |\n| **マルチモーダル** | Qwen-VL: 画像・動画・音声対応 |\n\n## 主な用途\n\n- 多言語コンテンツ生成・翻訳\n- 企業向けチャットボット (中国語特化)\n- コード生成 (Qwen-Coder)\n- 画像・動画理解 (Qwen-VL)\n- 長文ドキュメント処理 (128Kコンテキスト)\n\n## 実績\n\n- MMLU・HumanEval などベンチマークで GPT-4 に匹敵\n- Hugging Face ダウンロード数: 累計数千万回\n- Alibaba Cloud DashScope 経由でAPI提供\n- 72Bパラメータモデルが最強クラスのオープンソースLLM評価',
   '2026-04-13'),

  ('qwen', 'models',
   'Qwen モデル一覧 (2026年4月現在)',
   E'## Qwen2.5-Max (最高精度・クラウド)\n\nQwenシリーズの最高峰クラウドモデル。推論・長文処理に最適。\n\n| スペック | 値 |\n|---------|----|\n| コンテキスト長 | 128K トークン |\n| 対応言語 | 29言語 (日本語含む) |\n| 用途 | 複雑な推論・エージェント |\n\n## Qwen2.5-72B (オープンソース最強)\n\nHugging Faceで公開されているオープンソース最強クラスのモデル。\n\n| スペック | 値 |\n|---------|----|\n| パラメータ | 72B |\n| コンテキスト長 | 128K |\n| ライセンス | Qwen License (商用可) |\n| MMLU スコア | 86.1% (GPT-4相当) |\n\n## Qwen2.5-Coder-32B\n\nコード生成に特化したモデル。HumanEvalで最高スコア達成。\n\n| 機能 | 詳細 |\n|------|------|\n| HumanEval スコア | 90.2% |\n| 対応言語 | Python/JS/Java/C++ 等40言語 |\n\n## Qwen-VL (マルチモーダル)\n\n画像・動画・音声を入力として処理できるマルチモーダルモデル。\n\n## QwQ-32B (推論特化)\n\nChain-of-Thoughtによる高度な推論に特化。数学・科学問題で SOTA。\n\n## 競合比較\n\n| 指標 | Qwen2.5-72B | Llama 3.1-70B | Mistral Large |\n|------|-------------|---------------|---------------|\n| MMLU | 86.1% | 83.6% | 81.2% |\n| 日本語精度 | ◎ | ○ | △ |\n| コスト | ◎ (OSS) | ◎ (OSS) | △ (有料) |\n| 商用ライセンス | ✓ | ✓ | ✓ |',
   '2026-04-13'),

  ('qwen', 'api',
   'Qwen API ガイド (DashScope)',
   E'## API アクセス\n\n**DashScope API** 経由でQwenモデルにアクセス。OpenAI互換形式対応。\n\n```\nベースURL: https://dashscope.aliyuncs.com/compatible-mode/v1\n認証: Authorization: Bearer {DASHSCOPE_API_KEY}\n```\n\n**OpenAI SDK互換で使用可能**:\n\n```python\nfrom openai import OpenAI\n\nclient = OpenAI(\n    api_key="YOUR_DASHSCOPE_API_KEY",\n    base_url="https://dashscope.aliyuncs.com/compatible-mode/v1"\n)\n\nresponse = client.chat.completions.create(\n    model="qwen-max",  # または qwen2.5-72b-instruct\n    messages=[\n        {"role": "user", "content": "量子コンピュータとは何ですか？"}\n    ]\n)\nprint(response.choices[0].message.content)\n```\n\n## 主要エンドポイント\n\n### テキスト生成\n```http\nPOST /chat/completions\nAuthorization: Bearer {API_KEY}\n\n{\n  "model": "qwen-max",\n  "messages": [{"role": "user", "content": "..."}],\n  "max_tokens": 2048\n}\n```\n\n### マルチモーダル (画像)\n```http\nPOST /chat/completions\n{\n  "model": "qwen-vl-max",\n  "messages": [\n    {\n      "role": "user",\n      "content": [\n        {"type": "image_url", "image_url": {"url": "https://..."}},\n        {"type": "text", "text": "この画像を説明してください"}\n      ]\n    }\n  ]\n}\n```\n\n## 料金 (2026年4月)\n\n| モデル | Input | Output |\n|--------|-------|--------|\n| qwen-max | ¥0.04/1K | ¥0.12/1K |\n| qwen-plus | ¥0.008/1K | ¥0.024/1K |\n| qwen-turbo | ¥0.003/1K | ¥0.006/1K |\n| qwen-long | ¥0.0005/1K | ¥0.002/1K |\n\n※ 人民元建て。無料枠: qwen-turbo は月100万トークン無料\n\n## オープンソース版 (無料)\n\n```bash\n# Ollama で Qwen2.5 をローカル実行\nollama pull qwen2.5:72b\nollama run qwen2.5:72b\n\n# または Hugging Face から\npip install transformers\nfrom transformers import AutoModelForCausalLM, AutoTokenizer\nmodel = AutoModelForCausalLM.from_pretrained("Qwen/Qwen2.5-7B-Instruct")\n```\n\n## 日本語リソース\n\n- X: `@Alibaba_Cloud_JP`\n- ドキュメント: https://help.aliyun.com/zh/model-studio/\n- HuggingFace: https://huggingface.co/Qwen',
   '2026-04-13')
ON CONFLICT (provider, category) DO UPDATE
  SET title = EXCLUDED.title,
      content = EXCLUDED.content,
      published_at = EXCLUDED.published_at;
