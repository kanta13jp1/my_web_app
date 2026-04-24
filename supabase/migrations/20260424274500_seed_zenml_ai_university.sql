-- Session PS#3-S42: AI大学 180社化 — ZenML 追加
-- ベルリン/SF 発 OSS MLOps パイプラインフレームワーク (2021年創業)。
-- @step / @pipeline デコレータで Python コードをそのまま ML パイプライン化。
-- Stack 概念でローカル開発 → Vertex AI / SageMaker / AzureML へ透明に移行。
-- 50+ インテグレーション (Kubeflow / Airflow / MLflow / W&B / HuggingFace)。
-- ZenML Pro: マネージドクラウド + チームコラボ + モデルレジストリ。
-- Step 0: 7/9 (OSS MLOps / Stack抽象化 / 50+ integrations / ZenML Pro / LLM pipeline対応)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'zenml',
  'overview',
  'ZenML — OSS MLOps パイプラインフレームワーク (Stack 抽象化 / 50+ インテグレーション)',
  $md$
# ZenML — Build Portable, Production-Ready ML Pipelines

**ZenML** はベルリン/サンフランシスコ発の OSS MLOps パイプラインフレームワーク。
Python コードに `@step` / `@pipeline` デコレータを付けるだけで、
ローカルで開発した ML パイプラインをそのまま本番クラウドに移行できる。

「**Stack** (インフラ構成セット)」という概念で、
オーケストレーター・アーティファクトストア・コンテナレジストリを抽象化し、
コードを変えずに実行環境を切り替えられるのが最大の特徴。

## Stack — インフラ抽象化の核心

```
Stack = Orchestrator + Artifact Store + (Container Registry) + Extensions
例:
  Local Stack    → Python process + LocalArtifactStore
  GCP Stack      → Vertex AI + GCS + Google Artifact Registry
  AWS Stack      → SageMaker + S3 + ECR
  Kubernetes     → Kubeflow Pipelines + MinIO + DockerHub
```

同じパイプラインコードを `zenml stack set <stack-name>` で環境切替。

## 対応インテグレーション (50+)

| カテゴリ | ツール |
| :--- | :--- |
| **オーケストレーター** | Kubeflow / Airflow / Vertex AI / SageMaker / AzureML |
| **実験トラッカー** | MLflow / W&B / Comet ML / Neptune |
| **モデルレジストリ** | MLflow / HuggingFace / BentoML |
| **アーティファクトストア** | GCS / S3 / Azure Blob / MinIO |
| **特徴量ストア** | Feast |
| **データバリデーション** | Great Expectations / Deepchecks / Evidently |

## ZenML Pro (マネージド)

- チームコラボレーション: RBAC + ダッシュボード
- リモートスタック管理 (SaaS でインフラ設定)
- モデルレジストリ + デプロイメント追跡
- パイプライン実行履歴・比較 UI
$md$,
  'https://zenml.io/',
  '2026-04-24',
  1
),

(
  'zenml',
  'models',
  'ZenML パイプライン設計 & LLM パイプライン対応 (2026)',
  $md$
## ZenML コアコンセプト

### Step — パイプラインの最小単位

```python
from zenml import step
from zenml.config import DockerSettings

@step
def load_data() -> list[str]:
    """データをロードして返す"""
    return ["AI大学データ1", "AI大学データ2"]

@step
def preprocess(data: list[str]) -> list[str]:
    """データを前処理"""
    return [d.strip().lower() for d in data]

@step
def train_model(data: list[str]) -> dict:
    """モデル学習"""
    return {"accuracy": 0.95, "samples": len(data)}
```

### Pipeline — Steps を接続

```python
from zenml import pipeline

@pipeline
def ai_university_pipeline():
    raw_data = load_data()
    processed = preprocess(data=raw_data)
    result = train_model(data=processed)
```

### アーティファクト & バージョン管理

- 各 step の入出力が自動でアーティファクトとして保存
- バージョン管理 + 系譜追跡 (Lineage Tracking)
- 型チェック + シリアライザー自動選択 (Pydantic / numpy / pandas / PyTorch)

## LLM パイプライン対応 (2024-2025 拡張)

### LLM Fine-tuning パイプライン

```python
@step
def prepare_training_data(raw_docs: list[str]) -> Dataset:
    """HuggingFace Dataset に変換"""
    ...

@step
def fine_tune_llm(dataset: Dataset) -> str:
    """Claude / GPT / Llama をファインチューニング"""
    ...

@step
def evaluate_llm(model_path: str) -> dict:
    """LLM 評価 (Ragas / Patronus 連携)"""
    ...

@pipeline
def llm_finetuning_pipeline():
    data = prepare_training_data(raw_docs=load_raw_data())
    model_path = fine_tune_llm(dataset=data)
    metrics = evaluate_llm(model_path=model_path)
```

### RAG インデックスパイプライン

- ドキュメント ingestion → embedding → ベクターストア保存 を自動化
- Haystack / LangChain / LlamaIndex との連携実績あり

## スタック設定 (CLI)

```bash
# ローカル開発
zenml stack set default

# GCP 本番移行
zenml stack register gcp-stack \
  --orchestrator vertex \
  --artifact-store gcs \
  --container-registry gcr

zenml stack set gcp-stack
python run_pipeline.py  # 同じコードで Vertex AI 上で実行
```
$md$,
  'https://docs.zenml.io/',
  '2026-04-24',
  2
),

(
  'zenml',
  'api',
  'ZenML API 入門 — MLOps パイプライン構築 & LLM 評価自動化',
  $md$
## ZenML の始め方

### インストール

```bash
pip install zenml
zenml init  # プロジェクト初期化
zenml up    # ZenML Server をローカル起動 (Dashboard UI)
```

### シンプルなパイプライン (5分で動かす)

```python
from zenml import step, pipeline
from zenml.client import Client

@step
def fetch_ai_providers() -> list[dict]:
    """AI大学プロバイダーを取得"""
    import httpx
    # Supabase から取得
    response = httpx.get(
        "https://xxx.supabase.co/rest/v1/ai_university_content",
        headers={"apikey": "..."},
    )
    return response.json()

@step
def analyze_providers(providers: list[dict]) -> dict:
    """Claude でプロバイダーを分析"""
    from anthropic import Anthropic
    client = Anthropic()

    summary = client.messages.create(
        model="claude-opus-4-7",
        max_tokens=1024,
        messages=[{
            "role": "user",
            "content": f"以下の {len(providers)} プロバイダーを分析してください: {providers[:5]}",
        }],
    )
    return {
        "count": len(providers),
        "analysis": summary.content[0].text,
    }

@step
def save_report(analysis: dict) -> None:
    """分析レポートを保存"""
    import json
    with open("ai_university_report.json", "w") as f:
        json.dump(analysis, f, ensure_ascii=False, indent=2)
    print(f"✅ {analysis['count']} プロバイダーの分析完了")

@pipeline
def ai_university_analysis_pipeline():
    providers = fetch_ai_providers()
    analysis = analyze_providers(providers=providers)
    save_report(analysis=analysis)

if __name__ == "__main__":
    ai_university_analysis_pipeline()
```

### 実験追跡 (MLflow 連携)

```bash
pip install "zenml[mlflow]"
zenml integration install mlflow
```

```python
from zenml.integrations.mlflow.flavors.mlflow_experiment_tracker_flavor import MLFlowExperimentTrackerSettings

@step(
    experiment_tracker="mlflow_tracker",
    settings={"experiment_tracker.mlflow": MLFlowExperimentTrackerSettings(
        experiment_name="ai_university_eval",
    )},
)
def evaluate_with_tracking(model_output: str) -> float:
    import mlflow
    score = compute_score(model_output)
    mlflow.log_metric("quality_score", score)
    return score
```

### ZenML Pro (チーム向け)

```bash
# ZenML Pro に接続
zenml connect --url https://your-org.zenml.io

# チームスタックを共有
zenml stack share gcp-stack

# ダッシュボードでパイプライン実行履歴を閲覧
zenml up --docker  # Web UI: http://localhost:8237
```

## クイックスタート

1. `pip install zenml && zenml init` でセットアップ
2. `@step` デコレータで関数をパイプラインの部品化
3. `@pipeline` で steps を接続してフローを定義
4. `zenml stack set <stack>` でインフラを切替 (コード変更不要)
5. `zenml up` でダッシュボード起動 → 実行履歴・アーティファクト管理
$md$,
  'https://docs.zenml.io/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
