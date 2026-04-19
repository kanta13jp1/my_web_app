-- PS版#3 Session 2: Baseten — エンタープライズ AI モデルデプロイメント基盤
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'baseten',
  'overview',
  'Baseten — 本番向け AI モデルデプロイメント基盤',
  E'## Baseten とは\n\nBaseten は 2019 年創業のサンフランシスコ発 MLOps スタートアップ。\n**「Model Serving Platform for Production Inference」**を掲げ、カスタムモデル・オープンソースモデルを本番環境にデプロイするためのインフラを提供する。\n\nReplicate や Modal と同じカテゴリだが、**エンタープライズ対応 (99.99% SLA)** と **Gen AI 特化の推論最適化**に強みを持つ。Google Cloud の公認パートナーであり、225% のコストパフォーマンス改善事例も公表。\n\n## 主な特徴\n\n- **Serverless + Dedicated**: 変動負荷は serverless API、高ボリュームは dedicated GPU インスタンス\n- **カスタムモデル対応**: Hugging Face / 独自 checkpoint を直接デプロイ可能\n- **Gen AI 最適化**: LLM / Diffusion / 音声など各カテゴリ別の推論スタック\n- **分単位課金**: 無駄なコストを最小化\n- **エンタープライズ**: データ居住性・カスタム SLA・オンプレ対応\n\n## 資金調達\n\n- 累計調達: 約 4,000 万ドル以上\n- Andreessen Horowitz (a16z)、8VC などが出資\n- 大手 AI 企業・Fortune 500 が顧客',
  '2026-04-19'
),
(
  'baseten',
  'models',
  'Baseten 対応モデル・ハードウェア',
  E'## Serverless API 対応モデル (トークン課金)\n\n| カテゴリ | モデル例 |\n|----------|----------|\n| **LLM** | Llama 3.3 70B, Mistral Large, Qwen 2.5 |\n| **音声 STT** | Whisper Large v3, Deepgram Nova-2 |\n| **画像生成** | Stable Diffusion XL, FLUX.1 |\n| **Embedding** | BGE-M3, E5-large |\n\n## Dedicated GPU インスタンス\n\n| GPU | 時間単価 | 用途 |\n|-----|----------|------|\n| T4 | $0.63/hr | 開発・小規模推論 |\n| A10G | $1.60/hr | 中規模 LLM |\n| A100 40GB | $3.20/hr | 大規模 LLM |\n| H100 | $7.50/hr | フロンティアモデル |\n| B200 | $9.98/hr | 次世代 AI |\n\n## カスタムモデル\n\n- Hugging Face Hub からの直接 import\n- 独自の checkpoint ファイル対応\n- `truss` フレームワークでパッケージング\n- A/B テスト・カナリアデプロイ対応\n\n## Baseten Inference Stack の最適化\n\n- LLM: continuous batching + KV キャッシュ最適化\n- Diffusion: CUDA graph + attention 最適化\n- 音声: ストリーミング対応',
  '2026-04-19'
),
(
  'baseten',
  'api',
  'Baseten API 使い方',
  E'## クイックスタート\n\n```python\nfrom baseten import BasetenClient\n\nclient = BasetenClient(api_key="YOUR_API_KEY")\n\n# Serverless API (トークン課金)\nresponse = client.run(\n    "llama-3-3-70b",\n    {"messages": [{"role": "user", "content": "Hello!"}]}\n)\nprint(response["output"])\n```\n\n## Truss でカスタムモデルをデプロイ\n\n```bash\npip install truss\ntruss init my-model\n# config.yaml でモデル設定\ntruss push\n```\n\n## REST API\n\n```bash\ncurl -X POST \\\n  "https://model-{MODEL_ID}.api.baseten.co/predict" \\\n  -H "Authorization: Api-Key YOUR_API_KEY" \\\n  -H "Content-Type: application/json" \\\n  -d ''{"prompt": "What is machine learning?"}'' \n```\n\n## 料金プラン\n\n| プラン | 月額 | 対象 |\n|--------|------|------|\n| Basic | 無料 | 開発・変動負荷 |\n| Pro | 要相談 | 高ボリューム・予測可能負荷 |\n| Enterprise | 要相談 | データ居住性・オンプレ |\n\n## 活用シーン\n\n- **カスタム fine-tuned モデル**の本番デプロイ\n- **マルチモーダル AI** (LLM + 画像 + 音声) の統合パイプライン\n- **エンタープライズ MLOps**: CI/CD 統合・監視・ロールバック',
  '2026-04-19'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
