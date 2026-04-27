-- PS#3 S86: AI大学 266→267社化 — Azure Machine Learning (Microsoft クラウドMLプラットフォーム)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'azure-ml', 'overview',
  'Azure Machine Learning — Microsoft統合MLプラットフォーム・Responsible AI・GitHub Actions統合 (8/9)',
  $$## Azure Machine Learning とは

**Azure Machine Learning (Azure ML)** は Microsoft が提供する**エンタープライズ向け ML プラットフォーム**。モデル開発・訓練・デプロイ・監視を統合管理する。

Azure OpenAI Service・GitHub Actions・Microsoft 365 との深い統合が強み。2023年から **Responsible AI (責任ある AI)** ツールを業界最先端レベルで提供。

## 3大クラウドMLプラットフォーム比較

```
AWS SageMaker:
  強み: 最多機能 / HyperPod大規模訓練 / スポット90%割引
  弱み: AWS縛り / 設定複雑

Google Vertex AI:
  強み: Gemini直接統合 / Firebase連携 / グラウンディング
  弱み: GCP縛り / 日本語サポート

Azure ML:
  強み: Microsoft 365 統合 / GitHub Actions / Responsible AI
  弱み: Azure縛り / コスト高め

→ 既存インフラが Azure / Microsoft 365 中心なら Azure ML 一択
```

## Azure ML の主要機能

| 機能 | 説明 |
|------|------|
| **Azure ML Studio** | Web UI でモデル訓練・デプロイ管理 |
| **Designer** | ノーコードでML パイプライン構築 |
| **AutoML** | 自動モデル選択・ハイパーパラメータ最適化 |
| **Prompt Flow** | LLM アプリのオーケストレーション・評価 |
| **Responsible AI Dashboard** | 公平性・説明可能性・エラー分析を一元可視化 |

## Responsible AI Dashboard (業界最先端)

```
Azure ML の差別化ポイント = Responsible AI ツール群:

1. Fairness Assessment:
   → 性別・年齢・人種などでのモデルバイアス検出
   → 「このモデルは特定グループに不公平でないか?」

2. Error Analysis:
   → どのデータサブセットでモデルが失敗するかを視覚化
   → 「どんな状況で予測が外れるか?」

3. Explainability:
   → SHAP/LIME でどの特徴量が予測に影響したか説明
   → 「なぜこの予測をしたか?」

4. Causal Analysis:
   → 因果推論で「もし X を変えたら結果はどう変わるか?」

5. Counterfactual:
   → 「決定を変えるには何を変えればよいか?」
   → ローン否決された顧客への「何を改善すれば承認される?」
```

## Azure OpenAI Service 統合

```
Azure ML + Azure OpenAI の組み合わせ:

  ・GPT-4o / GPT-4 Turbo をエンタープライズで安全に利用
  ・仮想ネットワーク内 (VNet) で外部通信なし
  ・GDPR / HIPAA / ISO 27001 コンプライアンス対応
  ・Azure AD 認証 + RBAC

Prompt Flow:
  → LLM アプリを視覚的に構築
  → A/B テスト・評価フロー自動化
  → Azure DevOps / GitHub Actions と CI/CD 統合
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **Microsoft 365 連携** | Teams / Outlook データでモデル訓練 | 企業向け機能強化 |
| **Responsible AI** | バイアス検出で公平なAI実現 | 社会的責任の履行 |
| **Prompt Flow** | LLM アプリ CI/CD | GitHub Actions 統合効率化 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'azure-ml', 'api',
  'Azure ML 実践 — SDK v2/Job/Endpoint/Prompt Flow/Responsible AI Dashboard/GitHub Actions CI/CD',
  $$## インストール

```bash
pip install azure-ai-ml azure-identity

# Azure CLI
az login
az ml --help
```

## Azure ML SDK v2: Training Job

```python
from azure.ai.ml import MLClient, command, Input
from azure.ai.ml.entities import Environment, AmlCompute
from azure.identity import DefaultAzureCredential

# クライアント初期化 (Azure AD 認証)
credential = DefaultAzureCredential()
ml_client = MLClient(
    credential=credential,
    subscription_id="your-subscription-id",
    resource_group_name="jibun-kaisha-rg",
    workspace_name="jibun-kaisha-ml",
)

# GPU クラスター作成
compute = AmlCompute(
    name="gpu-cluster",
    size="Standard_NC24ads_A100_v4",  # A100 GPU
    min_instances=0,
    max_instances=4,
)
ml_client.compute.begin_create_or_update(compute).result()

# カスタム環境定義
env = Environment(
    name="jibun-kaisha-env",
    conda_file="conda.yaml",
    image="mcr.microsoft.com/azureml/openmpi4.1.0-cuda11.8-cudnn8-ubuntu22.04",
)

# Training Job 定義
job = command(
    code="./src",
    command="python train.py --epochs ${{inputs.epochs}} --lr ${{inputs.lr}}",
    inputs={
        "epochs": Input(type="integer", default=3),
        "lr": Input(type="number", default=2e-5),
        "train_data": Input(
            type="uri_folder",
            path="azureml://datastores/workspaceblobstore/paths/train/",
        ),
    },
    environment=env,
    compute="gpu-cluster",
    display_name="llm-finetune-run",
    experiment_name="jibun-kaisha-llm",
    tags={"model": "llama-3-8b", "task": "japanese-qa"},
)

returned_job = ml_client.jobs.create_or_update(job)
print(f"Job URL: {returned_job.studio_url}")
```

## オンラインエンドポイント (本番 API)

```python
from azure.ai.ml.entities import (
    ManagedOnlineEndpoint,
    ManagedOnlineDeployment,
    Model,
    CodeConfiguration,
)

# エンドポイント作成
endpoint = ManagedOnlineEndpoint(
    name="jibun-kaisha-llm-endpoint",
    description="LLM API for JibunKaisha",
    auth_mode="key",                         # APIキー認証
)
ml_client.online_endpoints.begin_create_or_update(endpoint).result()

# デプロイメント定義
deployment = ManagedOnlineDeployment(
    name="llama-3-8b-ja",
    endpoint_name="jibun-kaisha-llm-endpoint",
    model=Model(
        name="llama-3-8b-japanese",
        path="azureml://datastores/workspaceblobstore/paths/models/llama-ja/",
        type="custom_model",
    ),
    code_configuration=CodeConfiguration(
        code="./score/",
        scoring_script="score.py",           # 推論スクリプト
    ),
    environment=env,
    instance_type="Standard_NC6s_v3",        # V100 GPU
    instance_count=2,
)
ml_client.online_deployments.begin_create_or_update(deployment).result()

# トラフィック割り当て
endpoint.traffic = {"llama-3-8b-ja": 100}
ml_client.online_endpoints.begin_create_or_update(endpoint).result()

# 推論
response = ml_client.online_endpoints.invoke(
    endpoint_name="jibun-kaisha-llm-endpoint",
    request_file="./request.json",
)
```

## Prompt Flow: LLM アプリ CI/CD

```python
# Prompt Flow で RAG パイプライン定義 (YAML)
# flow.dag.yaml
inputs:
  question:
    type: string
outputs:
  answer:
    type: string
    reference: ${generate.output}

nodes:
  - name: embed_question
    type: python
    source:
      type: code
      path: embed.py
    inputs:
      text: ${inputs.question}

  - name: vector_search
    type: python
    source:
      type: code
      path: search.py
    inputs:
      embedding: ${embed_question.output}
      top_k: 5

  - name: generate
    type: llm
    source:
      type: code
      path: generate.jinja2
    inputs:
      question: ${inputs.question}
      contexts: ${vector_search.output}
    connection: azure-openai-connection
    api: chat
    model: gpt-4o
```

```python
# Prompt Flow 評価 (バッチ評価)
from promptflow.azure import PFClient

pf_client = PFClient(ml_client)

eval_run = pf_client.run(
    flow="./eval_flow",                      # 評価フロー
    data="./test_data.jsonl",               # テストデータ
    run=production_run,                      # 評価対象のラン
    column_mapping={
        "question": "${data.question}",
        "answer": "${run.outputs.answer}",
        "ground_truth": "${data.ground_truth}",
    },
    display_name="LLM Quality Evaluation",
)
```

## GitHub Actions との CI/CD 統合

```yaml
# .github/workflows/azure-ml-deploy.yml
name: Azure ML Deploy

on:
  push:
    branches: [main]
    paths:
      - "ml/**"

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Train Model
        run: |
          pip install azure-ai-ml azure-identity
          python scripts/submit_training_job.py \
            --workspace jibun-kaisha-ml \
            --resource-group jibun-kaisha-rg

      - name: Deploy to Endpoint
        run: |
          python scripts/deploy_model.py \
            --endpoint jibun-kaisha-llm-endpoint \
            --deployment llama-3-8b-ja
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'azure-ml', 'models',
  'Azure ML 技術詳解 — Responsible AI/AutoML/コスト最適化/エンタープライズセキュリティ/3大クラウドML選択基準',
  $$## Responsible AI Dashboard 詳解

```python
from raiwidgets import ResponsibleAIDashboard
from responsibleai import RAIInsights

# RAI Insights 作成
rai_insights = RAIInsights(
    model=trained_model,
    train=train_df,
    test=test_df,
    target_column="label",
    task_type="classification",
    categorical_features=["gender", "age_group", "region"],
)

# 各分析を追加
rai_insights.explainability.add()     # SHAP による説明可能性
rai_insights.error_analysis.add()    # エラー分析ツリー
rai_insights.fairness.add(           # 公平性評価
    target_attribute="gender",       # 性別でバイアス確認
    fairness_metric="demographic_parity_difference",
)
rai_insights.causal.add(             # 因果分析
    treatment_features=["study_hours", "coaching"],
)
rai_insights.counterfactual.add(     # 反事実分析
    total_CFs=10,
    desired_class="opposite",        # 判定を逆にするには?
)

# ダッシュボード表示 (Jupyter)
rai_insights.compute()
ResponsibleAIDashboard(rai_insights)
```

## AutoML: 自動モデル選択

```python
from azure.ai.ml import automl, Input

# AutoML 分類ジョブ
automl_job = automl.classification(
    compute="cpu-cluster",
    experiment_name="automl-sentiment",
    training_data=Input(
        type="mltable",
        path="azureml://datastores/workspaceblobstore/paths/train_data/",
    ),
    target_column_name="sentiment",
    primary_metric="accuracy",
    n_cross_validations=5,
    enable_model_explainability=True,
    featurization="auto",            # 特徴エンジニアリング自動化
)

# 制約設定
automl_job.set_limits(
    timeout_minutes=120,
    trial_timeout_minutes=20,
    max_trials=50,                   # 最大50モデルを試行
    enable_early_termination=True,
)

returned_job = ml_client.jobs.create_or_update(automl_job)
best_model = ml_client.jobs.get(returned_job.name).properties["best_child_run_id"]
```

## エンタープライズセキュリティ

```
Azure ML のセキュリティ機能:

ネットワーク:
  ✓ Private Link (VNet 内で外部通信なし)
  ✓ カスタム DNS / ファイアウォール対応
  ✓ マネージドオンラインエンドポイントは自動 HTTPS

認証・認可:
  ✓ Azure AD + RBAC (役割ベースアクセス制御)
  ✓ マネージドID (シークレット管理不要)
  ✓ Key Vault との統合

コンプライアンス:
  ✓ SOC 1/2/3, ISO 27001, FedRAMP
  ✓ GDPR / HIPAA 対応
  ✓ 日本データセンター (東日本 / 西日本) でデータ主権確保

監査:
  ✓ 全操作ログ → Azure Monitor / Log Analytics
  ✓ モデルリネージ (どのデータで訓練したか追跡)
```

## コスト最適化

```
Azure ML コスト戦略:

1. スポット VM (低優先度VM):
   → 最大 90% 割引
   → 中断されても自動再試行 (チェックポイント必須)

2. Azure Reserved VM Instances:
   → 1〜3年コミット → 最大 72% 割引

3. コンピュートクラスターのオートスケール:
   → min_instances=0 → アイドル時コスト 0
   → リクエストで自動起動

4. Serverless Compute:
   → GPU クラスター管理不要
   → 秒単位課金

概算コスト:
  訓練: Standard_NC6s_v3 (V100) → $3.60/h
  推論: Standard_NC6s_v3 × 2 → $7.20/h
  スポット利用で → $1.08/h〜$2.16/h
```$$,
  NULL, NULL, 3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 266→267社化: Azure Machine Learning 追加',
  'PS#3 S86。Azure Machine Learning (Microsoft エンタープライズML/Responsible AI Dashboard公平性+説明可能性+因果分析/Prompt Flow/AutoML/GitHub Actions CI/CD/Private Link/GDPR HIPAA/Azure OpenAI統合/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
