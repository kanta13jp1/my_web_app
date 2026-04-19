-- PS版#3 Session 10: Predibase — LLM ファインチューニング特化プラットフォーム
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'predibase',
  'overview',
  'Predibase — LoRA ファインチューニングを民主化するLLM開発プラットフォーム',
  E'## Predibase とは\n\nPredibase は 2021 年設立のサンフランシスコ発スタートアップ。\n**LLM のファインチューニングをシンプルにする**ことに特化し、\nLoRA (Low-Rank Adaptation) ベースの効率的なファインチューニングを提供。\n\nLudwig (Uber 発の ML フレームワーク) の開発者チームが創業。累計調達 $24.5M+。\n特に**複数の LoRA アダプターをシングル GPU で同時サーブ**できる\n「LoRAX」エンジンが技術的差別化ポイント。\n\n## 主な特徴\n\n- **LoRA ファインチューニング**: パラメータ効率的で安価なカスタマイズ\n- **LoRAX**: 1 GPU で 1000+ カスタムモデルを同時サーブ\n- **Serverless LoRA**: カスタムモデルをサーバーレスで公開\n- **Ludwig 統合**: 設定ファイルベースで ML パイプラインを構築\n- **対応モデル**: Llama / Mistral / Gemma / Phi / Falcon 等\n\n## 他サービスとの比較\n\n| 観点 | Predibase | OpenAI Fine-tuning | Together AI |\n|------|----------|-------------------|-------------|\n| **対応モデル** | OSS LLM 全般 | GPT-3.5/4o mini | OSS 多数 |\n| **LoRA** | ✅ 特化 | ❌ フルパラメータ | ✅ 対応 |\n| **マルチアダプター** | ✅ LoRAX | ❌ | ❌ |\n| **プライバシー** | ◎ データ共有なし | △ OpenAI 管理 | ○ |\n\n## 活用事例\n\n- **社内ドメイン特化 LLM**: 医療・法律・金融の専門用語を学習\n- **多言語カスタマイズ**: 日本語対応の弱いモデルを日本語特化に\n- **A/B テスト**: 複数の LoRA アダプターを同時デプロイして比較\n- **コスト削減**: GPT-4 相当の性能を小型ファインチューン済みモデルで実現',
  '2026-04-20'
),
(
  'predibase',
  'models',
  'Predibase 機能・LoRAX アーキテクチャ一覧',
  E'## LoRAX — Multi-LoRA サービングエンジン\n\n### アーキテクチャの革新\n\n```text\n従来: 1モデル = 1 GPU インスタンス\nLoRAX: ベースモデル × N = 1 GPU インスタンス (最大 1000+ アダプター)\n```\n\n- ベースモデル (Llama 3.1 70B など) は GPU に 1 回だけロード\n- LoRA アダプター (~数百MB) は動的に切り替え\n- リクエストごとに適切なアダプターを自動選択\n\n### 対応ベースモデル\n\n| モデル | パラメータ | 用途 |\n|--------|-----------|------|\n| Llama 3.1 8B | 8B | 軽量・高速 |\n| Llama 3.1 70B | 70B | 高精度 |\n| Mistral 7B | 7B | コード生成 |\n| Gemma 2 9B | 9B | Google 製 |\n| Phi-3 Mini | 3.8B | エッジ向け |\n\n### LoRA ハイパーパラメータ\n\n```yaml\n# predibase config\nmodel_id: meta-llama/Llama-3.1-8B-Instruct\nfine_tuning:\n  method: lora\n  rank: 16          # LoRA ランク (4/8/16/32)\n  alpha: 32         # スケーリング係数\n  target_modules:   # 適用レイヤー\n    - q_proj\n    - v_proj\n  dropout: 0.05\nepochs: 3\nlearning_rate: 2e-4\n```\n\n## Serverless LoRA\n\n- カスタムアダプターをサーバーレスエンドポイントとして公開\n- 使用量ゼロ時は自動スケールダウン (コスト 0)\n- コールドスタート ~5秒\n\n## 料金\n\n| プラン | 月額 | 内容 |\n|--------|------|------|\n| Developer | $0 | 無料 GPU 時間・1プロジェクト |\n| Starter | $149 | 20 GPU時間/月 |\n| Pro | $499 | 無制限 GPU・LoRAX 本番 |\n| Enterprise | 要相談 | VPC・SLA |',
  '2026-04-20'
),
(
  'predibase',
  'api',
  'Predibase 使い方',
  E'## インストール\n\n```bash\npip install predibase\nexport PREDIBASE_API_TOKEN="YOUR_TOKEN"\n```\n\n## LoRA ファインチューニング\n\n```python\nfrom predibase import Predibase\n\npb = Predibase(api_token="YOUR_TOKEN")\n\n# 1. データセットをアップロード\ndataset = pb.datasets.from_file(\n    "train.jsonl",  # {"prompt": "...", "completion": "..."} 形式\n    name="ai-university-qa"\n)\n\n# 2. ファインチューニング実行\nadapter = pb.adapters.create(\n    config={\n        "base_model": "meta-llama/Llama-3.1-8B-Instruct",\n        "fine_tuning_type": "lora",\n        "rank": 16,\n        "learning_rate": 2e-4,\n        "epochs": 3\n    },\n    dataset=dataset,\n    name="ai-university-expert"\n)\n\n# 学習完了まで待機\nadapter.wait_for_completion()\nprint(f"Adapter ID: {adapter.id}")\n```\n\n## LoRAX で推論 (カスタムアダプター)\n\n```python\nfrom predibase import Predibase\nfrom lorax import Client  # LoRAX クライアント\n\npb = Predibase(api_token="YOUR_TOKEN")\n\n# Predibase のエンドポイント経由でカスタムモデルを呼び出し\nresponse = pb.deployments.client("meta-llama/Llama-3.1-8B-Instruct").generate(\n    "AI大学のベクターデータベースを比較してください",\n    adapter_id="ai-university-expert/1",  # カスタムアダプター指定\n    max_new_tokens=512,\n    temperature=0.1\n)\nprint(response.generated_text)\n```\n\n## OpenAI 互換 API\n\n```python\nfrom openai import OpenAI\n\n# Predibase は OpenAI 互換エンドポイントを提供\nclient = OpenAI(\n    base_url="https://serving.app.predibase.com/v1",\n    api_key="YOUR_PREDIBASE_TOKEN"\n)\n\nresponse = client.chat.completions.create(\n    model="meta-llama/Llama-3.1-8B-Instruct/adapters/ai-university-expert",\n    messages=[{"role": "user", "content": "RAGとは？"}]\n)\nprint(response.choices[0].message.content)\n```\n\n## 学習データ形式 (JSONL)\n\n```jsonl\n{"prompt": "Pineconeとは？", "completion": "Pineconeはベクターデータベースの先駆者。RAG構築に最適。"}\n{"prompt": "LangChainとは？", "completion": "LangChainはLLMアプリ構築の事実上の標準フレームワーク。"}\n{"prompt": "Anthropicとは？", "completion": "AnthropicはClaude AIを開発するAI安全性企業。"}\n```\n\n## 活用シーン\n\n- **AI 大学 専門家モデル**: AI プロバイダー情報に特化したファインチューン済みモデル\n- **日本語強化**: Llama を日本語 QA データでファインチューン\n- **コスト最適化**: GPT-4o の代わりに安価なファインチューン済みモデルで EF を動かす',
  '2026-04-20'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
