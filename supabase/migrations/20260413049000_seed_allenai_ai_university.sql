-- Windows版#67: AI大学53社目 — Allen AI (AI2 / Olmo)
-- ワシントン大学/Paul Allen設立。Olmo-2が完全オープンソースでGPT-4クラスを達成

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order, is_active)
VALUES
(
  'allenai',
  'overview',
  'Allen AI (AI2) とは',
  E'## Allen AI (Allen Institute for AI / AI2) とは\n\nAI2 は**Microsoftの共同創業者 Paul G. Allen** が2014年に設立した非営利AI研究機関。\nワシントン大学と連携し、**完全オープンソースな大規模言語モデル「OLMo」**シリーズを開発・公開。\n学術・研究コミュニティにおける「透明なAI」の旗手として知られる。\n\n### 企業/機関概要\n- 設立: 2014年 (Paul G. Allen — Microsoft共同創業者)\n- 本拠: シアトル (ワシントン大学キャンパス隣接)\n- 形態: 非営利研究機関\n- 年間予算: 約1.5億ドル\n- 著名な研究者: Yejin Choi (MacArthur Fellow)、Hannaneh Hajishirzi など\n\n### 主要プロジェクト\n- **OLMo (Open Language Model)**: 学習データ・コード・重みを全公開した完全透明なLLM\n- **OLMo-2**: 7B/13B パラメータ、GPT-4oクラスの性能をオープンで達成\n- **Tulu-3**: インストラクション・チューニング特化モデル\n- **Dolma**: 3兆トークンの完全公開学習データセット\n- **Arc (AI2 Reasoning Challenge)**: 科学推論ベンチマーク (業界標準)\n- **MapNeuro**: 神経科学×AI\n- **S2 (Semantic Scholar)**: 科学論文検索AIエンジン\n- **Macaw**: 質疑応答特化モデル\n\n### 強み\n- **完全透明性**: 重み・学習データ・コード・評価全てを公開 (他社は重みのみが多い)\n- **学術的信頼性**: 非営利・ピアレビュー・再現可能な研究\n- **研究コミュニティへの貢献**: ARC/SWAG/HellaSwag など業界標準ベンチマークを多数作成\n- **ライセンス**: Apache 2.0 で完全商用利用可能\n\n> 公式: https://allenai.org/ | OLMo: https://allenai.org/olmo',
  'https://allenai.org/',
  '2026-04-13',
  1,
  true
),
(
  'allenai',
  'models',
  'Allen AI モデル一覧',
  E'## Allen AI モデル一覧\n\n### OLMo シリーズ (Open Language Model)\n| モデル | パラメータ | コンテキスト | ライセンス | 特徴 |\n| --- | --- | --- | --- | --- |\n| **OLMo-2-7B** | 7B | 4K | Apache 2.0 | GPT-4oクラス性能・完全公開 |\n| **OLMo-2-13B** | 13B | 4K | Apache 2.0 | 最高性能・学術SOTA |\n| **OLMo-1-7B** | 7B | 2K | Apache 2.0 | 初代・安定版 |\n| **OLMo-1-65B** | 65B | 2K | Apache 2.0 | 大規模版 |\n\n### Tulu シリーズ (インストラクション・チューニング)\n| モデル | ベースモデル | 特徴 |\n| --- | --- | --- |\n| **Tulu-3-8B** | OLMo-2-7B | 指示追従・高品質チャット |\n| **Tulu-3-70B** | Llama-3.1-70B | 大規模・高性能 |\n\n### 完全オープンソースの構成\n```\nOLMo-2 公開内容 (他社との差別化):\n\n1. モデル重み (weights)\n   → HuggingFace で直接ダウンロード可\n\n2. 学習データ (Dolma データセット)\n   → 3兆トークン・Web/書籍/論文を完全公開\n\n3. 学習コード (OLMo repo)\n   → PyTorch・マルチGPU分散学習スクリプト\n\n4. 評価コード\n   → 再現可能なベンチマーク評価\n\n5. 学習ログ (W&B)\n   → 損失曲線・チェックポイント履歴まで公開\n```\n\n### ベンチマーク (OLMo-2-13B)\n| ベンチマーク | OLMo-2-13B | Llama-3.1-70B | GPT-4o mini |\n| --- | --- | --- | --- |\n| MMLU | 67.5% | 79.3% | 82.0% |\n| HumanEval | 52.4% | 72.6% | 87.2% |\n| ARC-Challenge | 78.2% | 83.4% | 86.2% |\n| TruthfulQA | 58.3% | 59.1% | 61.2% |',
  'https://allenai.org/olmo',
  '2026-04-13',
  2,
  true
),
(
  'allenai',
  'api',
  'Allen AI API / OLMo 利用方法',
  E'## Allen AI API / OLMo 利用方法\n\n### HuggingFace 経由 (直接利用)\n```python\nfrom transformers import AutoTokenizer, AutoModelForCausalLM\nimport torch\n\n# OLMo-2-7B をローカルで実行\ntokenizer = AutoTokenizer.from_pretrained("allenai/OLMo-2-7B")\nmodel = AutoModelForCausalLM.from_pretrained(\n    "allenai/OLMo-2-7B",\n    torch_dtype=torch.bfloat16,\n    device_map="auto"\n)\n\ninputs = tokenizer("人工知能とは何ですか？", return_tensors="pt")\noutputs = model.generate(**inputs, max_new_tokens=200)\nprint(tokenizer.decode(outputs[0], skip_special_tokens=True))\n```\n\n### OLMo 推論 (ollama 経由)\n```bash\n# ollama で OLMo を実行\nollama pull olmo2:7b\nollama run olmo2:7b "日本の歴史について教えてください"\n```\n\n### Tulu-3 (チャット向け) を使う\n```python\nfrom transformers import pipeline\n\nchat = pipeline(\n    "text-generation",\n    model="allenai/Tulu-3-8B",\n    device_map="auto"\n)\n\nmessages = [\n    {"role": "user", "content": "Pythonでフィボナッチ数列を実装してください"}\n]\nresult = chat(messages, max_new_tokens=512)\nprint(result[0]["generated_text"][-1]["content"])\n```\n\n### クラウド API (OctoAI / Together AI 経由)\n```python\nfrom openai import OpenAI\n\n# Together AI 経由で OLMo を利用\nclient = OpenAI(\n    api_key="your_together_api_key",\n    base_url="https://api.together.xyz/v1"\n)\n\nresponse = client.chat.completions.create(\n    model="allenai/OLMo-2-13B-Instruct",\n    messages=[{"role": "user", "content": "こんにちは"}]\n)\n```\n\n### リソース\n- AI2公式: https://allenai.org/\n- OLMo: https://allenai.org/olmo\n- HuggingFace: https://huggingface.co/allenai\n- GitHub: https://github.com/allenai/OLMo\n- Dolma データセット: https://huggingface.co/datasets/allenai/dolma',
  'https://allenai.org/olmo',
  '2026-04-13',
  3,
  true
),
(
  'allenai',
  'news',
  'Allen AI 最新情報',
  E'## Allen AI 最新情報 (2026-04-13)\n\n### 注目トピック\n- **OLMo-2 リリース**: 7B・13B モデルがGPT-4oクラスの性能をオープンソースで達成。学術界・OSS界隈で大反響\n- **完全透明AIの旗手**: OpenAI/Anthropic/Googleが重みのみ公開にとどまる中、AI2は学習データ・コード・ログ全てを公開\n- **Dolma データセット**: 3兆トークンの学習データを完全公開。AI研究の民主化に貢献\n- **Tulu-3**: RLVR (Reinforcement Learning from Verifiable Rewards) を採用したインストラクション・チューニングでSOTA\n- **Semantic Scholar**: 2億本以上の科学論文をインデックス。AI研究者が最もよく使う論文検索エンジン\n- **Arc-Challenge 更新**: GPT-4が解けなかった難問科学問題集を継続更新中。AI評価の標準化に貢献\n\n### オープンソースAIの重要性\nAI2のミッション: **「AIを皆のためにオープンに」**\n- Big Techがクローズドモデルを強化する中、透明性・再現可能性・民主化を推進\n- 学術研究者が自由に改良・公開できるエコシステムを構築\n- 米国・EU・日本の規制論議でも「オープン vs クローズド AI」の参照事例に\n\n### 競合比較\n| 項目 | Allen AI (AI2) | Meta (LLaMA) | Mistral |\n| --- | --- | --- | --- |\n| 学習データ公開 | ◎ 完全公開 | × 非公開 | × 非公開 |\n| 学習コード公開 | ◎ 完全公開 | △ 一部 | △ 一部 |\n| 商用ライセンス | ◎ Apache 2.0 | △ 制限あり | ◎ Apache 2.0 |\n| 非営利運営 | ◎ 非営利 | × 商業 | × 商業 |\n| 評価ベンチマーク開発 | ◎ 多数作成 | △ | △ |\n\n> 公式: https://allenai.org/ | HuggingFace: https://huggingface.co/allenai',
  'https://allenai.org/',
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
