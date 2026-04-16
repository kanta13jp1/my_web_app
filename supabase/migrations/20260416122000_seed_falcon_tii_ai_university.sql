-- AI大学: Falcon / TII (Technology Innovation Institute) コンテンツ seed
-- Windows版#63 2026-04-16

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order, is_active)
VALUES
(
  'falcon_tii',
  'overview',
  'Falcon LLM (TII) とは',
  E'## Falcon LLM とは\n\n**Technology Innovation Institute (TII)** は UAE（アラブ首長国連邦）アブダビの政府系研究機関。\n2023年に **Falcon シリーズ** を Apache 2.0 ライセンスで公開し、世界トップクラスのオープンウェイト LLM として注目を集めた。\n\n## 主な特徴\n\n| 特徴 | 詳細 |\n|---|---|\n| **完全オープン** | 商用利用可能な Apache 2.0 ライセンス |\n| **高品質トレーニング** | RefinedWeb（厳選Webデータ）で学習 |\n| **アーキテクチャ最適化** | Multi-Query Attention で推論高速化 |\n| **多言語対応** | 英語・フランス語・ドイツ語・スペイン語等 |\n\n## なぜ重要か\n\n- 公開当初（2023年5月）はオープンソースでトップのEloスコアを獲得\n- 中東発のAI研究として地政学的にも注目\n- 完全オープンウェイトのため、ファインチューニング・ローカルデプロイの教材として最適\n- RefinedWebのデータキュレーション手法が学術界で広く参照される',
  'https://falconllm.tii.ae/',
  '2026-04-16',
  1,
  true
),
(
  'falcon_tii',
  'models',
  'Falcon モデルシリーズ一覧',
  E'## Falcon モデルシリーズ\n\n### Falcon 1 (2023)\n\n| モデル | パラメータ | 用途 |\n|---|---|---|\n| falcon-7b | 7B | 軽量・高速推論 |\n| falcon-7b-instruct | 7B | 指示追従 |\n| falcon-40b | 40B | 高品質生成 |\n| falcon-40b-instruct | 40B | 商用グレード |\n| falcon-180b | 180B | 最大規模 |\n\n### Falcon 2 (2024)\n\n| モデル | 特徴 |\n|---|---|\n| falcon2-11b | 11Bで Llama 3 8B を超える性能 |\n| falcon2-11b-vlm | ビジョン言語モデル（画像理解対応） |\n\n### RefinedWeb データセット\n\nFalconの品質を支えるWebデータセット:\n- CommonCrawlから高品質コンテンツをフィルタリング\n- 重複排除・品質スコアリングを徹底\n- 5兆トークン規模\n- データ品質がモデル性能に直結することを示した先行研究\n\n### ベンチマーク結果（Falcon2-11B）\n\n- MMLU: 58.0%\n- HellaSwag: 82.9%\n- TruthfulQA: 52.5%\n- 同サイズクラスでトップ水準',
  'https://huggingface.co/tiiuae',
  '2026-04-16',
  2,
  true
),
(
  'falcon_tii',
  'api',
  'Falcon API の使い方 (HuggingFace / ローカル)',
  E'## Falcon API の使い方\n\n### 方法1: Hugging Face Hub 経由\n\n```python\nfrom transformers import AutoTokenizer, AutoModelForCausalLM\nimport torch\n\nmodel_name = "tiiuae/falcon2-11b"\ntokenizer = AutoTokenizer.from_pretrained(model_name)\nmodel = AutoModelForCausalLM.from_pretrained(\n    model_name,\n    torch_dtype=torch.bfloat16,\n    device_map="auto"\n)\n\ninputs = tokenizer("AI大学へようこそ！", return_tensors="pt")\noutputs = model.generate(**inputs, max_new_tokens=100)\nprint(tokenizer.decode(outputs[0], skip_special_tokens=True))\n```\n\n### 方法2: Hugging Face Inference API\n\n```python\nimport requests\n\nAPI_URL = "https://api-inference.huggingface.co/models/tiiuae/falcon-7b-instruct"\nheaders = {"Authorization": "Bearer <HF_TOKEN>"}\n\nresponse = requests.post(\n    API_URL,\n    headers=headers,\n    json={"inputs": "What is Falcon LLM?"}\n)\nprint(response.json())\n```\n\n### 方法3: Together AI 経由 (推奨・高速)\n\n```python\nfrom openai import OpenAI\n\nclient = OpenAI(\n    api_key="<TOGETHER_API_KEY>",\n    base_url="https://api.together.xyz/v1"\n)\nresponse = client.chat.completions.create(\n    model="togethercomputer/falcon-40b-instruct",\n    messages=[{"role": "user", "content": "Hello!"}]\n)\n```\n\n### ローカル実行 (Ollama)\n\n```bash\n# Ollama でFalcon実行\nollama run falcon\n```\n\n## ライセンス\n\n- Apache 2.0: 商用利用・改変・再配布すべて無償で可能\n- **注意**: falcon-180b のみ Falcon-180B ライセンス（商用利用には別途確認が必要）',
  'https://huggingface.co/tiiuae/falcon2-11b',
  '2026-04-16',
  3,
  true
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = now();
