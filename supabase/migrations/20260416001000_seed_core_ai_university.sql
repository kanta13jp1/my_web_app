-- VSCode版#: Core AI を AI大学に追加
-- CoreWeave GPU インフラストラクチャ・AI コンピュート特化。2026年Q1に Series A 資金調達。

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order, is_active)
VALUES
(
  'core',
  'overview',
  'Core (CoreWeave) とは',
  E'## Core (CoreWeave) とは\n\nCoreは**GPU インフラストラクチャと AI コンピュート**に特化したクラウドプロバイダー。\nサンフランシスコを拠点とし、2026年Q1に Series A 資金調達を実施。\n分散型 GPU クラスタを活用した**LLM 推論・ファインチューニング・モデル学習**を開発者向けに提供している。\n\n### 起源と背景\n\nCoreWeave は 2017 年に暗号資産マイニング向けの GPU ホスティングで始まった企業だが、\n2024年〜2025年にかけて AI コンピュート市場への転換を加速。\n主要顧客はスタートアップ・研究機関・エンタープライズで、**NVIDIA H100 / H200** クラスタを大量保有する。\n\n### 主要なコンピュート機能\n\n- **LLM 推論エンドポイント**: vLLM・TensorRT-LLM・SGLangベースの超低レイテンシー推論\n- **ファインチューニング API**: 複数プロバイダー (Meta LLaMA / Mistral / Qwen) の SFT・DPO 対応\n- **Kubernetes 統合**: インフラレベルで K8s をサポート、既存MLOpsワークフロー互換\n- **リージョン展開**: 米国・EU・APAC に複数拠点（日本リージョン整備中）\n- **ハイパースケール**: 24/7 安定稼働の企業向けSLA保証\n\n## 強み\n\n- **GPU 専門**: クラウド大手 (AWS/Azure/GCP) より**20〜30%低レイテンシー**な推論\n- **API シンプル**: REST API 一統で、複数モデルを同じコードで試行可能\n- **価格競争力**: 時間単位レンタルで企業向け柔軟契約（スポット・オンデマンド）\n- **エコシステム開放**: HuggingFace・Together AI・Replicate 等と連携実績\n- **日本企業対応**: ドキュメント日本語化・サポート有り（準備中）',
  'https://www.coreweave.com/',
  '2026-04-16',
  1,
  true
),
(
  'core',
  'models',
  'Core (CoreWeave) コンピュートエンジン一覧 (2026年)',
  E'## コンピュートエンジン\n\n| エンジン | 対応 GPU | 推論速度 | 用途 |\n| :--- | :--- | :--- | :--- |\n| **vLLM** | H100/H200/L40S | <10ms (トークン/回) | 高スループット推論・チャットAPI |\n| **TensorRT-LLM** | H100/H200 | <5ms (トークン/回) | 超低レイテンシー推論・エッジ統合 |\n| **SGLang** | H100/H200 | <8ms (トークン/回) | 複雑クエリ・フロー制御推論 |\n| **VLLM + ROCm** | MI300X (AMD) | 同等性能 | AMD GPU での実行 |\n| **Llama.cpp** | L40S/RTX 6000 | 低コスト実行 | 小中規模モデル・ファインチューニング |\n\n## 対応モデル ファミリー\n\n### テキスト生成（LLM）\n- **Meta LLaMA 3.3 / 3.2 / 3.1** (70B/405B)\n- **Mistral Large 2 / Mixtral** (8x22B MoE)\n- **Qwen (QwQ / QVQ)** (32B/72B)\n- **Llama Guard** (安全フィルタリング)\n\n### マルチモーダル\n- **LLaVA / LLaMA-Vision** (画像理解)\n- **Pixtral** (Mistral マルチモーダル)\n- **OpenFlamingo** (オープンソース MLLM)\n\n### ファインチューニング対応\n- SFT (教師なし学習)\n- DPO (Direct Preference Optimization)\n- LoRA + QLoRA (パラメータ効率化)\n- Full Fine-tuning (全パラメータ更新)\n\n## クラスタスペック\n\n| リソース | 配置 | 料金目安 (時間単位) |\n| :--- | :--- | :--- |\n| **H200 GPU (2ユニット)** | 4x H200 = 1ノード | $40/h |\n| **H100 クラスタ** | 8x H100 = マルチノード | $32/h (ノード単価) |\n| **L40S (汎用)** | 4x L40S = 推論向け | $12/h |\n| **CPU のみ (小規模)** | 16C / 64GB RAM | $2/h |\n',
  'https://docs.coreweave.com/',
  '2026-04-16',
  2,
  true
),
(
  'core',
  'api',
  'Core (CoreWeave) API 入門',
  E'## CoreWeave API の始め方\n\n### 1. アカウント作成 & API キー発行\n\n```bash\n# CoreWeave Console にログイン\nhttps://console.coreweave.com/\n\n# API キー生成\n# → Settings → API Keys → Create New Key\n# 権限: compute, models (推奨)\n```\n\n### 2. Python SDK インストール\n\n```bash\npip install coreweave\n```\n\n### 3. LLM 推論の例 (vLLM)\n\n```python\nfrom openai import OpenAI\nimport os\n\n# CoreWeave エンドポイント（OpenAI互換）\nclient = OpenAI(\n    api_key=os.getenv(\"COREWEAVE_API_KEY\"),\n    base_url=\"https://api.coreweave.com/v1\"  # CoreWeave エンドポイント\n)\n\n# LLaMA 3.3 70B で推論\nresponse = client.chat.completions.create(\n    model=\"meta-llama/Llama-3.3-70B-Instruct\",\n    messages=[\n        {\"role\": \"user\", \"content\": \"日本語で自分株式会社の AI大学について説明してください\"}\n    ],\n    max_tokens=512,\n    temperature=0.7\n)\n\nprint(response.choices[0].message.content)\n```\n\n### 4. ファインチューニング API\n\n```python\nimport coreweave\n\ncoreweave.api_key = os.getenv(\"COREWEAVE_API_KEY\")\n\n# ファインチューニング ジョブ作成\njob = coreweave.Finetune.create(\n    model=\"meta-llama/Llama-3.3-70B-Instruct\",\n    training_data=\"s3://my-bucket/training_data.jsonl\",\n    learning_rate=2e-5,\n    num_epochs=3,\n    batch_size=32,\n    output_model_name=\"my-llama-finetuned\"\n)\n\nprint(f\"Job ID: {job.id}\")\nprint(f\"Status: {job.status}\")\n```\n\n## 料金 (2026年4月時点)\n\n| リソース | 単価 | 最小契約 | 割引 |\n| :--- | :--- | :--- | :--- |\n| **H200 (推論)** | $40/時間 | 1時間 | 月契約で 15-20% 割引 |\n| **H100 (推論)** | $32/時間 | 1時間 | スポット: 50-60% 割引 |\n| **L40S (推論)** | $12/時間 | 1時間 | バッチ割引: 25% off |\n| **ファインチューニング** | $50-200 / ジョブ | 小規模 | 大規模: 要相談 |\n| **ストレージ** | $0.023/GB/月 | — | — |\n\n## 公式リソース\n\n- **公式サイト**: https://www.coreweave.com/\n- **API ドキュメント**: https://docs.coreweave.com/\n- **Python SDK**: https://github.com/coreweave/python-sdk\n- **GitHub**: https://github.com/coreweave\n- **サポート**: support@coreweave.com\n\n## ユースケース\n\n- **スタートアップ**: GPU リソースの従量課金・24時間稼働\n- **研究機関**: マルチノード分散学習・大規模言語モデル学習\n- **エンタープライズ**: 専有GPU・SLA保証・セキュリティコンプライアンス',
  'https://docs.coreweave.com/',
  '2026-04-16',
  3,
  true
)

ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  source_url = EXCLUDED.source_url,
  published_at = EXCLUDED.published_at,
  updated_at = now();
