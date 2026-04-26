-- PS#3 S72: AI大学 238→239社化 — MLflow 追加
-- MLflow: Databricks製OSS MLOps基盤 / 実験追跡+モデルレジストリ+デプロイ / GitHub 18k+ / Apache 2.0

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'mlflow',
  'overview',
  'MLflow — Databricks製 OSS MLOpsプラットフォーム (実験追跡+モデルレジストリ+デプロイ / GitHub 18k+ / 業界標準)',
  $$## MLflow — MLOpsプラットフォーム (Databricks)

**カテゴリ**: MLOps / Experiment Tracking / Model Registry / Model Deployment
**開発元**: Databricks (創業者 Matei Zaharia 他) / コア開発: Databricks + OSS コミュニティ
**設立**: 2018年6月 (オープンソースリリース) / 本家: San Francisco, CA
**ライセンス**: Apache 2.0 (フル OSS)
**GitHub**: 18,000+ stars / 月間 pip download 1,500万+
**Databricks**: $43B 評価 / $4B 調達 / IPO準備中
**評価**: 9/9

### 概要
MLflow は **「ML実験の記録・モデルの管理・本番デプロイを統一インターフェースで行う」** OSS MLOpsプラットフォーム。2018年の登場以来、業界標準として定着し、sklearn / PyTorch / TensorFlow / XGBoost など主要 ML フレームワークと公式インテグレーション済み。

LLMブーム (2023年〜) 以降は **LLM トレーシング (MLflow Tracing)** と **LLM 評価 (mlflow.evaluate)** を追加し、従来の ML モデル管理から「生成AIアプリの実験管理」へと進化を続けている。

### 主な機能

**MLflow Tracking (実験追跡)**
- `mlflow.log_param()`: ハイパーパラメータを記録
- `mlflow.log_metric()`: 精度・損失などの指標を記録 (ステップごと)
- `mlflow.log_artifact()`: モデルファイル・グラフ・CSVを保存
- 比較 UI: 複数実験のパラメータ・メトリクスをテーブル/グラフで比較

**MLflow Models (モデル管理)**
- フレームワーク非依存な標準モデル形式 (`MLmodel` フォーマット)
- `mlflow.pyfunc`: scikit-learn / PyTorch / TF を同一 API で扱う
- フレーバー: `sklearn` / `pytorch` / `transformers` / `langchain` / `openai` など

**MLflow Model Registry (バージョン管理)**
- モデルを `staging → production → archived` のステージで管理
- バージョンごとのコメント・タグ付け
- CI/CD 連携: 本番昇格をプルリクエスト的に承認フローで管理

**MLflow Tracing (LLM対応)**
- `@mlflow.trace` デコレーターで LLM コールを自動追跡
- OpenAI / Anthropic / LangChain / LlamaIndex の自動計装
- 入力・出力・レイテンシ・トークン数を記録 → Langfuse 的な機能を内包

**MLflow Projects (再現性)**
- `MLproject` ファイルで環境 (Conda/Docker) + 実行コマンドを定義
- `mlflow run git@github.com:...` でリモートプロジェクトを再現実行

### フレームワーク対応
| フレームワーク | 自動ログ関数 |
|--------------|-------------|
| scikit-learn | `mlflow.sklearn.autolog()` |
| PyTorch | `mlflow.pytorch.autolog()` |
| TensorFlow/Keras | `mlflow.tensorflow.autolog()` |
| XGBoost | `mlflow.xgboost.autolog()` |
| Transformers (HuggingFace) | `mlflow.transformers.autolog()` |
| LangChain | `mlflow.langchain.autolog()` |
| OpenAI | `mlflow.openai.autolog()` |

### 導入形態
- **ローカル**: `mlflow ui` → localhost:5000 で即座に起動
- **リモートサーバー**: PostgreSQL + S3 でチーム共有
- **Databricks Managed MLflow**: エンタープライズ向け完全マネージド
- **Azure ML / AWS SageMaker**: 組み込み対応

### 自分株式会社での活用可能性
- **AI大学コンテンツ品質改善**: プロンプトのA/Bテスト結果を MLflow で比較
- **競合モニタリング精度追跡**: 競合スコアリングモデルのバージョン管理
- **LLMコスト実験**: モデル切替 (Sonnet ↔ Haiku) のコスト/品質トレードオフを可視化$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'mlflow',
  'api',
  'MLflow SDK — 実験追跡 / LLMトレーシング / モデルレジストリ (Python / Supabase連携)',
  $$## MLflow SDK / 実装

### セットアップ
```bash
pip install mlflow
# LLMサポートを含む場合
pip install mlflow[langchain]   # LangChain連携
pip install mlflow[openai]      # OpenAI連携
pip install mlflow[anthropic]   # Anthropic連携

# MLflow UI 起動 (localhost:5000)
mlflow ui
```

### 基本的な実験追跡
```python
import mlflow
import mlflow.sklearn
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score

# Tracking URI設定 (デフォルト: ./mlruns)
mlflow.set_tracking_uri("http://localhost:5000")
mlflow.set_experiment("ai-university-relevance-scoring")

with mlflow.start_run(run_name="rf-baseline"):
    # パラメータ記録
    mlflow.log_params({
        "n_estimators": 100,
        "max_depth": 10,
        "model_type": "random_forest",
    })

    # モデル訓練
    model = RandomForestClassifier(n_estimators=100, max_depth=10)
    model.fit(X_train, y_train)
    predictions = model.predict(X_test)

    # メトリクス記録
    accuracy = accuracy_score(y_test, predictions)
    mlflow.log_metrics({
        "accuracy": accuracy,
        "train_size": len(X_train),
        "test_size": len(X_test),
    })

    # モデルを Artifact として保存
    mlflow.sklearn.log_model(
        model,
        artifact_path="model",
        registered_model_name="ai-relevance-scorer",
    )

    print(f"Run ID: {mlflow.active_run().info.run_id}")
    print(f"Accuracy: {accuracy:.4f}")
```

### LLM トレーシング (Anthropic自動計装)
```python
import mlflow
import anthropic

# Anthropic SDK を自動トレース
mlflow.anthropic.autolog()

# 通常通り使うだけでトレースが記録される
client = anthropic.Anthropic()

with mlflow.start_run(run_name="cs-auto-reply-experiment"):
    mlflow.log_params({
        "model": "claude-sonnet-4-6",
        "max_tokens": 512,
        "prompt_version": "v3",
    })

    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=512,
        messages=[
            {"role": "user", "content": "パスワードリセットの方法は？"}
        ],
    )
    answer = response.content[0].text

    # メトリクス手動記録
    mlflow.log_metrics({
        "input_tokens": response.usage.input_tokens,
        "output_tokens": response.usage.output_tokens,
        "total_cost_usd": (
            response.usage.input_tokens * 3.0 / 1_000_000
            + response.usage.output_tokens * 15.0 / 1_000_000
        ),
    })
    mlflow.log_text(answer, "output.txt")
```

### プロンプトA/Bテスト (MLflow Experiments)
```python
import mlflow

PROMPTS = {
    "v1_simple": "以下の質問に答えてください: {question}",
    "v2_role": "あなたはAIサポート担当です。丁寧に答えてください: {question}",
    "v3_structured": (
        "あなたは自分株式会社のAIサポートです。\n"
        "回答は必ず日本語で、箇条書きで3点以内にまとめてください。\n"
        "質問: {question}"
    ),
}

def evaluate_prompt(prompt_name: str, prompt_template: str, questions: list) -> float:
    """プロンプトバリアントを評価してスコアを返す"""
    scores = []
    with mlflow.start_run(run_name=f"prompt-{prompt_name}"):
        mlflow.log_param("prompt_version", prompt_name)
        mlflow.log_text(prompt_template, "prompt.txt")

        for q in questions:
            formatted = prompt_template.format(question=q["text"])
            answer = call_claude(formatted)
            score = evaluate_answer_quality(answer, q["expected"])
            scores.append(score)

        avg_score = sum(scores) / len(scores)
        mlflow.log_metric("avg_quality_score", avg_score)
        return avg_score

# 3バリアントを比較
for name, template in PROMPTS.items():
    score = evaluate_prompt(name, template, test_questions)
    print(f"{name}: {score:.3f}")
# → MLflow UI で3実験を横並び比較して最良プロンプトを選択
```

### Model Registry でのステージ管理
```python
from mlflow import MlflowClient

client = MlflowClient()

# Staging → Production への昇格
client.transition_model_version_stage(
    name="ai-relevance-scorer",
    version="3",
    stage="Production",
    archive_existing_versions=True,  # 旧 Production を Archived に
)

# 本番モデルのロードと推論
import mlflow.sklearn

model = mlflow.sklearn.load_model(
    model_uri="models:/ai-relevance-scorer/Production"
)
prediction = model.predict([[...]])
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'mlflow',
  'models',
  'MLflow 技術詳細 — MLOps成熟度モデル / Databricks戦略 / LLMOps進化 / Weights&Biases比較',
  $$## MLflow 技術詳細

### MLOps 成熟度モデルと MLflow の役割

```
MLOps 成熟度レベル (Google/Microsoft 定義ベース)

Level 0: 手動ML (Notebook + スプレッドシート)
  問題: 再現性なし / バージョン管理なし / デプロイ手動
  → MLflow 導入で Level 1 に即座に到達可能

Level 1: MLパイプライン自動化
  ✅ 実験を mlflow.start_run() で追跡
  ✅ モデルを Model Registry で管理
  ✅ 再現可能な MLflow Projects
  → データサイエンティスト全員がここを目指すべきレベル

Level 2: CI/CD ML パイプライン
  ✅ GitHub Actions + MLflow でモデルの自動テスト
  ✅ A/B テスト → MLflow Experiments で比較
  ✅ Model Registry の Stage 管理 → 本番デプロイ承認フロー
  → 中規模ML チームの標準

Level 3: LLMOps (生成AI時代の Level 3)
  ✅ mlflow.anthropic.autolog() / openai.autolog()
  ✅ mlflow.evaluate() でLLM出力の自動品質評価
  ✅ プロンプトバージョン管理 → Langfuse と組み合わせ可
```

### Databricks の MLflow 戦略

```
Databricks → MLflow → Unity Catalog の統合戦略:

2018: MLflow OSS リリース (実験追跡のみ)
2019: Model Registry 追加
2021: Databricks Managed MLflow (フルマネージド)
2022: Unity Catalog 統合 (データ+モデルの統一ガバナンス)
2023: LLM Tracking / Prompt Engineering UI 追加
2024: MLflow 2.10+: LLMOps 本格対応
      mlflow.evaluate() が LLM 品質指標対応
      mlflow.deployments でベンダー横断デプロイ

Databricks の強み:
  Delta Lake (データ) + MLflow (モデル) + Unity Catalog (ガバナンス)
  = 「データから推論まで」の垂直統合プラットフォーム
  → Microsoft Azure / AWS と競合する独立 MLOps スタック
```

### Weights & Biases (W&B) との比較

| 項目 | **MLflow** | **Weights & Biases** |
|------|-----------|---------------------|
| ライセンス | ✅ Apache 2.0 (フル OSS) | ❌ 商用 (無料枠あり) |
| セルフホスト | ✅ 無料 | ✅ (Enterprise有償) |
| LLM対応 | ✅ v2.10+ | ✅ W&B Weave |
| 可視化品質 | ○ | ◎ (UI が綺麗) |
| Databricks統合 | ✅ ネイティブ | △ |
| 日本語ドキュメント | △ | △ |
| 無料枠 | 無制限 (OSS) | 制限あり |
| 企業採用 | ◎ (業界標準) | ○ (研究機関多い) |
| **推奨用途** | **本番ML システム** | **リサーチ・実験重視** |

### 自分株式会社でのMLOps パイプライン設計 (想定)

```
現状:
  GHA `ai-university-update.yml` → RSS取得 → LLMで要約 → Supabase INSERT
  問題: プロンプト品質の変化を追跡できない / どのプロンプトが最良か不明

MLflow 導入後の改善:

  [実験フェーズ]
  プロンプト複数バリアント
    → mlflow.start_run() で各バリアントを実験
    → mlflow.evaluate() で出力品質スコア算出
    → MLflow UI で最良プロンプト選択

  [本番フェーズ]
  選択プロンプト → Model Registry の Production ステージへ登録
  → GHA から mlflow.load_model("models:/prompt-manager/Production") で取得
  → プロンプト更新はコード変更なし (Registry 更新のみ)

  期待効果:
    AI大学コンテンツ品質 +20% (定量評価ベース)
    プロンプト変更サイクル: 数日 → 数時間
```$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 238→239社化: MLflow 追加',
  'PS#3 S72。MLflow (Databricks製OSS MLOps/実験追跡+モデルレジストリ+LLMトレーシング/Apache 2.0/GitHub 18k+/pip月1500万DL/Anthropic/OpenAI/LangChain autolog/9/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
