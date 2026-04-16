-- Windowsアプリ版#本セッション: Scale AI 大学コンテンツ seed
-- 世界最大のAI訓練データ企業 — すべての主要モデルの基盤を支える

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

('scale_ai', 'overview',
'Scale AI: 現代AIの「縁の下の力持ち」',
$$# Scale AI

Scale AIは、AIモデル訓練に必要な**高品質なデータ収集・アノテーション**を提供する企業。
GPT-4/Claude/Gemini など主要モデルのトレーニングデータを手掛け、「AI業界のインフラ」と呼ばれる。

## 何をしている会社か

```
ユーザーがChatGPTに質問
     ↓
AIが回答
     ↓
その回答が「良い」「悪い」を人間がラベル付け (RLHF)
     ↓
このラベル付けデータを大量に作成しているのが Scale AI
```

## 主要製品・サービス

| 製品 | 説明 |
|------|------|
| **Data Engine** | 大規模AIデータアノテーション・収集プラットフォーム |
| **Scale EGP** (Enterprise Generative Platform) | 企業向けLLMカスタマイズ・RAG・ファインチューニング |
| **Scale Evaluation** | LLMの弱点・ベンチマーク評価プラットフォーム |
| **Scale Labs** | AI能力・後学習・リスク管理研究 (2026年3月設立) |
| **Donovan** | 国防・政府向けAIプラットフォーム |

## 主要顧客

- **OpenAI**: GPT-4シリーズのRLHFデータ
- **Meta**: LLaMAシリーズの訓練データ
- **Microsoft**: Copilot改善データ
- **米国国防総省**: Donovanプラットフォーム
- **一般企業**: EGP経由でLLMカスタマイズ

## なぜAI大学で学ぶ価値があるか

Scale AIなしでは、ChatGPT・Claude・Geminiは今の精度に達しなかった。
AIの「見えないインフラ」を理解することで、LLMの限界と改善方法を把握できる。
$$,
'https://scale.com/generative-ai-platform',
'2026-04-17', 1),

('scale_ai', 'models',
'Scale AI のプラットフォーム体系',
$$# Scale AI プラットフォーム

## Scale EGP (Enterprise Generative Platform)

LLM企業でなく、LLMを**活用する企業**向けのプラットフォーム。

```
企業の独自データ
      ↓
Scale EGP
  ├─ RAG (検索拡張生成)
  ├─ Fine-tuning (ファインチューニング)
  ├─ RLHF (人間フィードバック強化学習)
  └─ Evaluation (品質評価)
      ↓
カスタマイズされたLLM
```

## Scale Evaluation (2025年リリース)

LLMの弱点を発見し、追加学習データが必要な箇所を特定する評価プラットフォーム。

| 評価軸 | 説明 |
|--------|------|
| **精度** | ハルシネーション率・事実確認 |
| **推論** | 数学・論理問題のスコア |
| **安全性** | 有害出力・バイアス検出 |
| **ドメイン特化** | 法律・医療・コーディング等 |

## Scale Labs (2026年3月設立)

研究部門として独立:
- AI能力評価手法の研究
- エンタープライズデプロイメント研究
- リスク・安全性インフラの構築

## 競合との比較

| 比較軸 | Scale AI | Hugging Face | Labelbox |
|--------|----------|--------------|----------|
| データアノテ | ✅ 専業 | ❌ | ✅ |
| LLMホスティング | ❌ | ✅ | ❌ |
| Fine-tuning | ✅ EGP | ✅ | △ |
| 国防対応 | ✅ Donovan | ❌ | ❌ |
$$,
'https://scale.com/generative-ai-platform',
'2026-04-17', 2),

('scale_ai', 'api',
'Scale EGP API: 開発者向けガイド',
$$# Scale EGP API

## Python SDK

```python
pip install scale-egp

from scale_egp import ScaleClient

client = ScaleClient(api_key="your_scale_api_key")

# RAG パイプライン構築
pipeline = client.pipelines.create(
    name="my-rag-pipeline",
    data_sources=["s3://my-bucket/docs/"],
    embedding_model="text-embedding-3-large"
)

# クエリ実行
response = client.query(
    pipeline_id=pipeline.id,
    query="Supabase の Row Level Security の設定方法は？"
)
print(response.answer)
```

## Fine-tuning API

```python
# カスタムデータでLLMをファインチューニング
job = client.finetune.create(
    base_model="llama-3.1-70b",  # または gpt-4o-mini
    training_data="s3://my-bucket/training-data.jsonl",
    eval_data="s3://my-bucket/eval-data.jsonl"
)

# 学習完了まで待機
job.wait()
print(f"Fine-tuned model: {job.model_id}")
```

## Evaluation API

```python
# LLMの弱点評価
eval_run = client.evaluate.create(
    model="gpt-4o",
    benchmark="mmlu",  # または独自ベンチマーク
    test_cases=my_test_cases
)

report = eval_run.get_report()
print(report.weaknesses)  # 弱点箇所を特定
```

## 料金

- **Data Annotation**: タスク単価 (カスタム見積もり)
- **EGP**: エンタープライズ契約 (月額数千〜数万ドル)
- **Free Tier**: 評価ツール一部無料
- **Azure統合**: Microsoft Azure上でも利用可

## このプロジェクトとの関連

- Supabase EFで独自データを訓練 → Scale EGPパターンの簡易実装
- `ai-assistant` EFの品質評価 → Scale Evaluationコンセプトを参考に
- AI大学コンテンツの品質管理 → Scale的なアノテーション視点で評価
$$,
'https://scale-egp.readme.io/',
'2026-04-17', 3),

('scale_ai', 'news',
'Scale AI 最新ニュース (2026-04-17)',
$$# Scale AI 最新動向 (2026-04-17)

## 主要アップデート

### Scale Labs 設立 (2026年3月)
AI能力評価・後学習研究・リスク管理を専門とする研究部門が独立。
「AIの品質を科学的に測定する」ことに特化した研究機関として始動。

### Scale Evaluation 一般提供 (2025年4月)
LLMのベンチマーク評価・弱点特定プラットフォームが公開。
独自のテストケースでモデルを評価し、追加訓練データが必要な箇所を可視化できる。

### 政府・国防分野での拡大
Donovanプラットフォームが米国防総省・政府機関での採用を拡大。
機密データを扱うAI活用の標準インフラとしての地位を確立。

### Microsoft Azure統合強化
Scale EGPがMicrosoft Azure上でネイティブに動作する統合を強化。
Azure OpenAI Service + Scale EGPの組み合わせがエンタープライズ標準に近づいている。

## 業界での位置づけ (2026年)

```
AIモデル: OpenAI / Anthropic / Google (モデルを作る)
AIデータ: Scale AI (モデルを賢くするデータを作る)
AIインフラ: NVIDIA (モデルを動かすチップを作る)
```

Scale AIは「データ」レイヤーの覇者。
すべての主要モデルプロバイダーが顧客であり、競合でもある独特のポジション。

## このプロジェクトへの示唆

- 自分株式会社の「AI大学」機能 → ユーザーの学習データもScaleのRLHFコンセプトで品質向上
- `daily-judgment` EF → Scale Evaluationパターンで回答品質を自動スコアリング可能
- 長期: 独自ユーザーデータをファインチューニングに活用 (Scale EGP的アプローチ)
$$,
'https://scale.com/',
'2026-04-17', 4)

ON CONFLICT (provider, category) DO UPDATE
  SET content = EXCLUDED.content,
      source_url = EXCLUDED.source_url,
      published_at = EXCLUDED.published_at,
      updated_at = now();
