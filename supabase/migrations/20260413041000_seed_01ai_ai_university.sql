-- Windows版#62: AI大学45社目 — 01.AI (Yi-series)
-- 李開復 (Kai-Fu Lee) が率いる中国発のAIスタートアップ。Yi系LLMで注目

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order, is_active)
VALUES
(
  '01ai',
  'overview',
  '01.AI (Yi) とは',
  E'## 01.AI (Yi) とは\n\n**01.AI** (零一万物) は著名なAI投資家・起業家の**李開復 (Kai-Fu Lee)** が2023年に創業した中国のAIスタートアップ。\n**Yi (易)** シリーズの大規模言語モデルを開発・提供している。\n\n### 企業概要\n- 設立: 2023年3月\n- 創業者: 李開復 (元Google中国社長・Sinovation Ventures創業者)\n- 本社: 北京\n- 評価額: 約10億ドル超 (ユニコーン, 2024年)\n- 主力: Yi-Lightningなどの高性能・軽量LLM\n\n### Yi シリーズの特徴\n- **多言語対応**: 英語・中国語・日本語・韓国語など主要言語に対応\n- **オープンソース**: Yi-6B / Yi-34B はHugging Face / GitHub で公開\n- **長コンテキスト**: Yi-200K は最大200,000トークンのコンテキストに対応\n- **商業利用可**: Apache 2.0ライセンスで商用プロジェクトに使用可\n- **マルチモーダル**: Yi-VL (Visual Language) モデルで画像理解に対応\n\n### 主要サービス\n- **Yi-Lightning API**: 超高速・低コストの推論API\n- **Yi Chat**: チャットインターフェース (chat.01.ai)\n- **Hugging Face**: モデル公開 (01-ai organization)\n\n> 公式サイト: https://www.01.ai/ | APIプラットフォーム: https://platform.01.ai/',
  'https://www.01.ai/',
  '2026-04-13',
  1,
  true
),
(
  '01ai',
  'models',
  '01.AI (Yi) モデル一覧',
  E'## 01.AI Yi モデル一覧\n\n### クラウドAPI モデル\n\n| モデル | コンテキスト | 特徴 | 推奨用途 |\n| --- | --- | --- | --- |\n| **Yi-Lightning** | 16K | 超高速・低コスト旗艦 | チャット・要約・Q&A |\n| **Yi-Large** | 32K | 最高品質フラッグシップ | 複雑な推論・コード |\n| **Yi-Large-Turbo** | 16K | 高速版Large | バランス型 |\n| **Yi-Medium** | 16K | コスト効率重視 | 一般タスク |\n| **Yi-Spark** | 16K | 軽量・最速 | 単純タスク・分類 |\n| **Yi-Vision** | 4K | 画像理解対応 | マルチモーダル |\n\n### オープンソース モデル (Hugging Face)\n\n| モデル | パラメータ | ライセンス | 特徴 |\n| --- | --- | --- | --- |\n| **Yi-34B** | 34B | Apache 2.0 | 高品質・商用可 |\n| **Yi-34B-200K** | 34B | Apache 2.0 | 超長文コンテキスト |\n| **Yi-9B** | 9B | Apache 2.0 | バランス型 |\n| **Yi-6B** | 6B | Apache 2.0 | 軽量・デプロイ向け |\n| **Yi-VL-34B** | 34B | Apache 2.0 | 画像+テキスト理解 |\n\n### 料金 (API)\n| モデル | 入力 (100万token) | 出力 (100万token) |\n| --- | --- | --- |\n| Yi-Lightning | $0.14 | $0.14 |\n| Yi-Large | $3.00 | $3.00 |\n| Yi-Medium | $0.30 | $0.30 |',
  'https://platform.01.ai/docs',
  '2026-04-13',
  2,
  true
),
(
  '01ai',
  'api',
  '01.AI (Yi) API 利用方法',
  E'## 01.AI (Yi) API 利用方法\n\n### 特徴: OpenAI互換API\n01.AI の API は **OpenAI API と互換性**があり、`base_url` を変更するだけで移行可能。\n既存のOpenAIコードをほぼ変更なく利用できる。\n\n### 認証\n```bash\n# APIキー取得: https://platform.01.ai/\nexport YI_API_KEY="your_api_key"\n```\n\n### Python (openai SDK 互換)\n```python\nfrom openai import OpenAI\n\nclient = OpenAI(\n    api_key="YOUR_YI_API_KEY",\n    base_url="https://api.01.ai/v1"\n)\n\nresponse = client.chat.completions.create(\n    model="yi-lightning",\n    messages=[\n        {"role": "system", "content": "あなたは役立つアシスタントです。"},\n        {"role": "user", "content": "Pythonでフィボナッチ数列を生成してください。"}\n    ]\n)\n\nprint(response.choices[0].message.content)\n```\n\n### cURL\n```bash\ncurl -X POST https://api.01.ai/v1/chat/completions \\\n  -H "Authorization: Bearer $YI_API_KEY" \\\n  -H "Content-Type: application/json" \\\n  -d ''{\n    "model": "yi-lightning",\n    "messages": [\n      {"role": "user", "content": "Hello!"}\n    ]\n  }''\n```\n\n### ストリーミング\n```python\nstream = client.chat.completions.create(\n    model="yi-lightning",\n    messages=[{"role": "user", "content": "日本のAI産業について教えて"}],\n    stream=True\n)\n\nfor chunk in stream:\n    if chunk.choices[0].delta.content:\n        print(chunk.choices[0].delta.content, end="")\n```\n\n### ローカル実行 (オープンソース)\n```bash\n# Hugging Face からモデルダウンロード\npip install transformers torch\n\nfrom transformers import AutoModelForCausalLM, AutoTokenizer\nmodel = AutoModelForCausalLM.from_pretrained("01-ai/Yi-6B")\ntokenizer = AutoTokenizer.from_pretrained("01-ai/Yi-6B")\n```\n\n### リソース\n- APIプラットフォーム: https://platform.01.ai/\n- Hugging Face: https://huggingface.co/01-ai\n- GitHub: https://github.com/01-ai/Yi\n- ドキュメント: https://platform.01.ai/docs',
  'https://platform.01.ai/docs',
  '2026-04-13',
  3,
  true
),
(
  '01ai',
  'news',
  '01.AI (Yi) 最新情報',
  E'## 01.AI (Yi) 最新情報 (2026-04-13)\n\n### 注目トピック\n- **Yi-Lightning**: 最新フラッグシップ。GPT-4oと同等性能を大幅に低いコストで提供\n- **マルチモーダル拡張**: Yi-VLシリーズで画像理解・OCR・図表分析に対応\n- **オープンソース戦略継続**: Yi-34B/9B/6B を Apache 2.0 で公開。カスタムファインチューニングを促進\n- **エンタープライズ展開**: 金融・医療・製造業向けのYi-Enterpriseプランを展開中\n- **日本語強化**: Yi-Lightning / Yi-Large で日本語品質が向上。日本市場での採用事例が増加\n- **コスト競争力**: $0.14/100万token (Yi-Lightning) — GPT-4oの1/50以下のコスト\n\n### 李開復コメント\n「我々のゴールはAIを民主化すること。Yi-Lightningはコストと性能の最良バランスを実現した」\n\n### 競合比較\n| 項目 | Yi-Lightning | GPT-4o-mini | Claude Haiku |\n| --- | --- | --- | --- |\n| 入力価格/100万token | $0.14 | $0.15 | $0.25 |\n| 速度 | 高速 | 高速 | 高速 |\n| 日本語品質 | 高 | 高 | 非常に高 |\n\n> 公式: https://www.01.ai/ | API: https://platform.01.ai/ | GitHub: https://github.com/01-ai',
  'https://www.01.ai/',
  '2026-04-13',
  1,
  true
)
ON CONFLICT (provider, category) DO UPDATE
  SET title = EXCLUDED.title,
      content = EXCLUDED.content,
      source_url = EXCLUDED.source_url,
      published_at = EXCLUDED.published_at,
      updated_at = now();
