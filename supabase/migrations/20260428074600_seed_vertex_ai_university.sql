-- PS#3 S85: AI大学 265→266社化 — Google Vertex AI (Google Cloud AI/ML プラットフォーム)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'vertex-ai', 'overview',
  'Google Vertex AI — Google Cloud統合MLプラットフォーム・Gemini API・Model Garden・Agent Builder (9/9)',
  $$## Google Vertex AI とは

**Vertex AI** は Google Cloud の**統合 AI/ML プラットフォーム**。AutoML から大規模 LLM 訓練・デプロイ・エージェント構築まで、Google の AI 技術を一元的に利用できる。

2021年 Google I/O で発表 (旧 AI Platform を刷新)。Gemini / Imagen / PaLM 等 Google 製モデルへの最速アクセスを提供。

## Vertex AI の全体像

```
Vertex AI エコシステム:

基盤モデル (Model Garden):
  Gemini 1.5 Pro/Flash/Ultra    → Google 最新 LLM
  Imagen 3                       → 画像生成
  Codey (code-bison)             → コード生成
  Embeddings (text-embedding-004) → テキスト埋め込み
  Claude 3.5 (Anthropic)         → Vertex AI 経由で利用可
  Llama 3 / Mistral              → OSS モデルもホスト

開発ツール:
  Vertex AI Studio     → ノーコードでモデル試験
  Colab Enterprise     → マネージド Jupyter (企業向け)
  Workbench            → フルマネージド JupyterLab

ML ライフサイクル:
  Pipelines (Kubeflow) → ML ワークフロー自動化
  Experiments          → 実験管理
  Feature Store        → 特徴量管理 (オンライン/オフライン)
  Model Registry       → モデルバージョン管理

LLM/Agent 特化:
  Vertex AI Agent Builder → RAG + Agent ノーコード構築
  Grounding              → Google Search 接地 (ハルシネーション削減)
  Evaluation             → LLM 品質評価フレームワーク
```

## Gemini API (Google の最強カード)

```
Vertex AI 経由の Gemini の強み:

Gemini 1.5 Pro:
  ・2M コンテキスト (業界最大級)
  ・マルチモーダル (テキスト/画像/音声/動画/PDF)
  ・コード生成・複雑な推論

Gemini 1.5 Flash:
  ・Pro の 1/10 コスト
  ・低レイテンシ
  ・大量処理に最適

Gemini グラウンディング:
  ・Google Search リアルタイム参照
  ・「今日のニュース」「最新価格」に回答可能
  ・RAG なしで最新情報にアクセス
```

## Agent Builder (ノーコードエージェント)

```
Agent Builder で作れるもの:
  ・Search App: 自社ドキュメントに特化した検索
  ・Conversational Agent: RAG ベースのチャットbot
  ・Recommendations: パーソナライズ推薦

接続できるデータソース:
  ・Google Drive / Cloud Storage / BigQuery
  ・ウェブサイト URL (自動クロール)
  ・Structured Data (CSV / JSON)
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **Gemini API** | マルチモーダル分析 (画像+テキスト) | Claude の補完モデル |
| **グラウンディング** | 最新競合情報をリアルタイム取得 | 競合モニタリング強化 |
| **Firebase 統合** | Vertex AI + Firebase で迅速展開 | Flutter/Firebase との親和性 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'vertex-ai', 'api',
  'Vertex AI 実践 — Gemini API/グラウンディング/Agent Builder/Custom Training/Pipelines/Firebase統合',
  $$## インストール

```bash
pip install google-cloud-aiplatform
pip install google-generativeai  # Gemini API (簡易版)

# 認証
gcloud auth application-default login
# または サービスアカウント
export GOOGLE_APPLICATION_CREDENTIALS="path/to/service-account.json"
```

## Gemini API (テキスト生成)

```python
import vertexai
from vertexai.generative_models import GenerativeModel, Part

# 初期化
vertexai.init(project="jibun-kaisha-project", location="asia-northeast1")

# Gemini 1.5 Pro でテキスト生成
model = GenerativeModel("gemini-1.5-pro-002")

response = model.generate_content(
    "自分株式会社のAI機能の優位性を3点挙げてください",
    generation_config={
        "max_output_tokens": 1024,
        "temperature": 0.7,
        "top_p": 0.95,
    }
)
print(response.text)

# チャット (マルチターン)
chat = model.start_chat()
response1 = chat.send_message("競合21社について教えて")
response2 = chat.send_message("その中でNotion対策は？")  # コンテキスト維持
```

## マルチモーダル (画像 + テキスト)

```python
from vertexai.generative_models import GenerativeModel, Part, Image

model = GenerativeModel("gemini-1.5-pro-002")

# 画像 + テキストで分析
image_part = Part.from_uri(
    "gs://jibun-kaisha-storage/ui-screenshot.png",
    mime_type="image/png",
)

response = model.generate_content([
    image_part,
    "このUIのデザイン品質を評価し、改善点を3つ提案してください",
])

# PDF 分析 (2M コンテキストで長文対応)
pdf_part = Part.from_uri(
    "gs://jibun-kaisha-storage/competitor-report.pdf",
    mime_type="application/pdf",
)
response = model.generate_content([
    pdf_part,
    "この競合レポートの要点を日本語でまとめてください",
])
```

## グラウンディング (Google Search 統合)

```python
from vertexai.generative_models import (
    GenerativeModel,
    Tool,
    grounding,
)

# Google Search グラウンディングを有効化
google_search_tool = Tool.from_google_search_retrieval(
    grounding.GoogleSearchRetrieval()
)

model = GenerativeModel(
    "gemini-1.5-pro-002",
    tools=[google_search_tool],
)

# 最新情報を Google Search で取得して回答
response = model.generate_content(
    "2024年最新のAI業界の競合動向を教えて",  # リアルタイムで検索して回答
)

# グラウンディング根拠の確認
for candidate in response.candidates:
    for grounding_chunk in candidate.grounding_metadata.grounding_chunks:
        print(f"Source: {grounding_chunk.web.uri}")
        print(f"Title: {grounding_chunk.web.title}")
```

## カスタムモデル訓練

```python
from google.cloud import aiplatform

aiplatform.init(project="jibun-kaisha-project", location="asia-northeast1")

# Custom Training Job
job = aiplatform.CustomTrainingJob(
    display_name="llama-japanese-finetune",
    script_path="train.py",
    container_uri="us-docker.pkg.dev/vertex-ai/training/pytorch-gpu.2-1.py310:latest",
    requirements=["transformers==4.40.0", "peft==0.10.0"],
    model_serving_container_image_uri="us-docker.pkg.dev/vertex-ai/prediction/pytorch-gpu.2-1:latest",
)

model = job.run(
    dataset=None,
    model_display_name="llama-japanese-v1",
    args=[
        "--model_name_or_path=meta-llama/Llama-3-8B-Instruct",
        "--num_train_epochs=3",
        "--output_dir=/gcs/jibun-kaisha-ml/output/",
    ],
    replica_count=4,
    machine_type="a2-highgpu-1g",  # A100 GPU
    accelerator_type="NVIDIA_TESLA_A100",
    accelerator_count=1,
)

# エンドポイントデプロイ
endpoint = model.deploy(
    machine_type="n1-standard-4",
    accelerator_type="NVIDIA_TESLA_T4",
    accelerator_count=1,
    min_replica_count=1,
    max_replica_count=5,          # 自動スケール
)

# 推論
response = endpoint.predict(instances=[{"inputs": "こんにちは"}])
```

## Firebase + Vertex AI 統合 (Flutter)

```dart
// Flutter から Vertex AI を直接呼び出す (Firebase AI Logic)
import 'package:firebase_vertexai/firebase_vertexai.dart';

// Vertex AI 初期化 (Firebase 経由)
final model = FirebaseVertexAI.instance.generativeModel(
  model: 'gemini-1.5-flash',
);

// チャット機能 (Flutter 内で直接 Gemini)
final chat = model.startChat();

Future<String> askGemini(String message) async {
  final response = await chat.sendMessage(
    Content.text(message),
  );
  return response.text ?? '';
}
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'vertex-ai', 'models',
  'Vertex AI 技術詳解 — Model Garden/Evaluation/Feature Store/Pipelines/SageMaker比較/コスト最適化',
  $$## Model Garden (300+ モデル)

```
Vertex AI Model Garden カテゴリ:

Google 製:
  ├── Gemini 1.5 Pro/Flash/Ultra (テキスト/マルチモーダル)
  ├── Imagen 3 (画像生成)
  ├── Chirp 2 (音声認識)
  ├── text-embedding-004 (埋め込み)
  └── Codey (コード生成)

パートナー (Anthropic):
  └── Claude 3.5 Sonnet / Haiku (Vertex AI 経由)

OSS モデル:
  ├── Llama 3 / 3.1 / 3.2 (Meta)
  ├── Mistral 7B / Large (Mistral AI)
  ├── Falcon (TII)
  └── Gemma 2 (Google OSS)

特殊用途:
  ├── MedPaLM 2 (医療特化)
  └── SecPaLM (セキュリティ特化)
```

## Vertex AI Evaluation (LLM品質評価)

```python
from vertexai.evaluation import EvalTask, MetricPromptTemplateExamples

# 評価タスク定義
eval_task = EvalTask(
    dataset=eval_dataset,           # 評価用データセット (Pandas DataFrame)
    metrics=[
        "rouge_l_sum",              # テキスト一致度
        "bleu",                     # 翻訳品質
        MetricPromptTemplateExamples.Pointwise.FLUENCY,    # 流暢さ
        MetricPromptTemplateExamples.Pointwise.COHERENCE,  # 一貫性
        MetricPromptTemplateExamples.Pointwise.GROUNDEDNESS, # 根拠性
    ],
    experiment="jibun-kaisha-llm-eval",
)

# 評価実行 (Gemini を judge として使用)
eval_result = eval_task.evaluate(
    model=GenerativeModel("gemini-1.5-pro-002"),
    prompt_template="{instruction}\n\n{context}",
)

print(eval_result.summary_metrics)
```

## Feature Store (特徴量管理)

```python
from google.cloud import aiplatform

# Online Feature Store: リアルタイム特徴量取得
client = aiplatform.gapic.FeatureOnlineStoreServiceClient()

# ユーザー特徴量をリアルタイム取得 (低レイテンシ)
response = client.fetch_feature_values(
    feature_view="projects/jibun-kaisha/locations/asia-northeast1/featureOnlineStores/user_store/featureViews/user_features",
    data_key={"key": "user_001"},
)
# → 推薦・パーソナライズで活用
```

## Vertex AI vs Amazon SageMaker 比較

| 比較軸 | Vertex AI | SageMaker |
|--------|-----------|-----------|
| **強み** | Gemini直接統合 / Firebase / Google Search Grounding | AWS エコシステム / 最多機能 / HyperPod |
| **LLM** | Gemini 1.5 (2M ctx) / Imagen 3 | JumpStart 300+ OSS モデル |
| **Firebase統合** | ◎ ネイティブ統合 | △ Amplify 経由 |
| **料金** | Gemini Flash 最安値クラス | Spot Instance 90% 割引 |
| **日本語** | Gemini 日本語精度高い | 要モデル選択 |
| **OSS連携** | Kubeflow Pipelines 標準搭載 | Kubeflow 追加設定 |

**選択基準**:
- Google/Firebase/Flutter 中心 → Vertex AI
- AWS 中心 / OSS モデル訓練 → SageMaker

## コスト最適化

```
Vertex AI コスト最適化:

1. Gemini Flash 優先使用:
   → Pro の 1/10 コスト
   → 単純タスクは Flash で十分

2. バッチ予測 (Batch Prediction):
   → リアルタイム不要な処理をバッチに
   → オンデマンド比 最大 50% 割引

3. コミットメント割引:
   → 1年コミット → 最大 57% 割引
   → 安定したワークロードに有効

4. プロビジョニング済みスループット:
   → 一定量を事前確保 → 過課金防止
   → レイテンシも安定
```$$,
  NULL, NULL, 3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 265→266社化: Google Vertex AI 追加',
  'PS#3 S85。Google Vertex AI (Google Cloud統合AI/ML/Gemini 1.5 Pro 2Mコンテキスト/グラウンディング/Model Garden 300+/Agent Builder/Firebase統合/Flutter直接呼び出し/Kubeflow Pipelines/Evaluation/9/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
