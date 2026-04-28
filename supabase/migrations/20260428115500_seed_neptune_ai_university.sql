-- PS#3 S89: AI大学 273→274社化 — Neptune.ai (MLメタデータストア・実験管理・Jupyter統合)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'neptune-ai', 'overview',
  'Neptune.ai — MLメタデータストア・実験管理・Jupyter/Notebook統合・チーム共有 (GitHub 2k+ / 8/9)',
  $$## Neptune.ai とは

**Neptune.ai** はMLの**メタデータストア**に特化したプラットフォーム。実験管理・モデルレジストリ・データバージョニングを統合。ポーランド発スタートアップ (2017年創業)。

GitHub 2,000+ スター (SDK)。W&B / MLflow / Comet ML と競合する実験管理市場の主要プレーヤー。「柔軟なメタデータ構造」と「Jupyter 統合の良さ」で差別化。

## 設計哲学: メタデータストアとしての ML 管理

```
"実験はメタデータの集合体"

Neptune の考え方:
  すべての ML 実験は以下のメタデータで構成される:

  ┌─────────────────────────────────────────┐
  │  Run (実行単位)                          │
  │  ├── parameters/   (ハイパーパラメータ)  │
  │  ├── metrics/      (loss/accuracy等)    │
  │  ├── model/        (モデルファイル)      │
  │  ├── dataset/      (データセット情報)   │
  │  ├── environment/  (Python版/GPU等)     │
  │  ├── source_code/  (git コミット等)     │
  │  └── custom/       (任意カスタム)       │
  └─────────────────────────────────────────┘

→ これらを「辞書のような柔軟な構造」で記録・検索・比較
```

## W&B / MLflow との比較

| 観点 | Neptune.ai | W&B | MLflow |
|------|-----------|-----|--------|
| **柔軟性** | 非常に高い (ネスト構造) | 高い | 中程度 |
| **Jupyter 統合** | 最高 (JupyterLab 拡張) | 良好 | 普通 |
| **無料枠** | 200時間/月 | 個人無料 | OSS完全無料 |
| **セルフホスト** | Enterprise のみ | Enterprise | ✓ OSS |
| **LLMops** | 対応 (Prompt tracking) | Weave | MLflow AI |

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **Jupyter 実験** | ノートブックから直接ログ | 探索的研究の記録 |
| **チーム共有** | 実験ダッシュボードを URL 共有 | コラボレーション向上 |
| **モデル比較** | 複数実験のメトリクスを横並び | 最良モデルの特定 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'neptune-ai', 'api',
  'Neptune.ai 実践 — Run/log/assign/upload_file/Model Registry/比較/Jupyter拡張/既存フレームワーク統合',
  $$## インストール & セットアップ

```bash
pip install neptune
pip install neptune-sklearn    # sklearn 統合
pip install neptune-pytorch    # PyTorch 統合
pip install neptune[tensorflow] # TF 統合

# JupyterLab 拡張 (左サイドバーに実験一覧が表示)
pip install neptune-notebooks
jupyter lab  # JupyterLab 起動後に Neptune パネルが追加される
```

## 基本: Run でメタデータ記録

```python
import neptune

# Run 開始
run = neptune.init_run(
    project="kanta13jp1/jibun-kaisha-sentiment",
    api_token="your-api-token",
    tags=["bert", "japanese", "v3"],
    description="BERT日本語感情分析 v3 - 学習率チューニング",
)

# パラメータ記録 (辞書形式で柔軟なネスト可能)
run["parameters"] = {
    "model": "bert-base-japanese",
    "learning_rate": 2e-5,
    "batch_size": 32,
    "optimizer": "AdamW",
    "scheduler": {
        "type": "cosine",
        "warmup_ratio": 0.1,
    },
}

# 訓練ループ中にメトリクスを随時追加
for epoch in range(10):
    loss = train_one_epoch()
    val_acc = validate()

    run["train/loss"].append(loss)        # 時系列で追記
    run["val/accuracy"].append(val_acc)

# カスタムメタデータ (自由形式)
run["data/train_size"] = 50000
run["data/val_size"] = 5000
run["data/source"] = "jibun-kaisha-dataset-v2"

# ファイルアップロード
run["model/checkpoint"].upload("./model.pt")
run["results/confusion_matrix"].upload("./cm.png")

run.stop()
```

## 既存フレームワーク統合

```python
# === scikit-learn 統合 ===
from neptune.integrations.sklearn import (
    create_classifier_summary,
    create_regressor_summary,
)

run = neptune.init_run(project="kanta13jp1/jibun-kaisha-churn")

from sklearn.ensemble import GradientBoostingClassifier
clf = GradientBoostingClassifier(n_estimators=100)
clf.fit(X_train, y_train)

# 全評価指標 + 特徴量重要度 + 混同行列を自動記録
run["classification_report"] = create_classifier_summary(
    clf, X_train, X_val, y_train, y_val
)
```

```python
# === PyTorch Lightning 統合 ===
from neptune.integrations.pytorch_lightning import NeptuneLogger

neptune_logger = NeptuneLogger(
    api_key="your-api-token",
    project="kanta13jp1/jibun-kaisha-nlp",
    tags=["lightning", "bert"],
)

trainer = Trainer(
    max_epochs=5,
    logger=neptune_logger,  # これだけで全メトリクスが自動記録
)
trainer.fit(model, train_loader, val_loader)
```

## Model Registry: モデルのライフサイクル管理

```python
import neptune

# モデルを Registry に登録
model = neptune.init_model(
    name="Jibun Kaisha Sentiment",
    key="JKSA",  # 短縮識別子
    project="kanta13jp1/jibun-kaisha-sentiment",
    api_token="your-api-token",
)
model["architecture"] = "BERT-base-japanese"
model["framework"] = "HuggingFace Transformers"
model.stop()

# モデルバージョン登録
model_version = neptune.init_model_version(
    model="KANTA13-JKSA",  # project-key
    project="kanta13jp1/jibun-kaisha-sentiment",
    api_token="your-api-token",
)
model_version["model/weights"].upload("./model.pt")
model_version["val/accuracy"] = 0.934
model_version.change_stage("staging")   # staging に昇格
model_version.change_stage("production")  # 本番に昇格
model_version.stop()
```

## 実験の取得と比較

```python
# 過去の実験を取得・比較
from neptune import management

project = neptune.init_project(
    project="kanta13jp1/jibun-kaisha-sentiment",
    api_token="your-api-token",
    mode="read-only",
)

# 全 Run をデータフレームで取得
runs_df = project.fetch_runs_table(
    columns=["parameters/learning_rate", "val/accuracy", "sys/tags"]
).to_pandas()

# 最高精度の実験を特定
best_run = runs_df.sort_values("val/accuracy", ascending=False).iloc[0]
print(f"Best run: {best_run.name}, accuracy={best_run['val/accuracy']:.4f}")
print(f"Learning rate: {best_run['parameters/learning_rate']}")

project.stop()
```

## Jupyter から Run の内容を直接閲覧

```python
# ノートブック内で過去の実験データを参照
run = neptune.init_run(
    with_id="JKSA-42",  # 既存の Run ID を指定
    project="kanta13jp1/jibun-kaisha-sentiment",
    mode="read-only",
)

# 記録済みメトリクスを取得
accuracy_history = run["val/accuracy"].fetch_values()
print(accuracy_history)  # pandas DataFrame で返ってくる

# アップロード済みファイルをダウンロード
run["model/checkpoint"].download("./downloaded_model.pt")
run.stop()
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 273→274社化: Neptune.ai 追加',
  'PS#3 S89。Neptune.ai (MLメタデータストア/柔軟なネスト構造/Jupyter拡張/sklearn+PyTorch Lightning統合/Model Registry/ステージ管理/実験比較DataFrame/GitHub 2k+/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
