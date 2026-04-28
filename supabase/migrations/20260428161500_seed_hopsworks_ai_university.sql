-- PS#3 S95: AI大学 285→286社化 — Hopsworks (OSS統合MLプラットフォーム/Feature Store/Model Registry)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'hopsworks', 'overview',
  'Hopsworks — OSS統合MLプラットフォーム・Feature Store・Model Registry・Model Serving (GitHub 1k+ / 8/9)',
  $$## Hopsworks とは

**Hopsworks** は **Feature Store / Model Registry / Model Serving を1つに統合したオープンソース ML プラットフォーム**。スウェーデン KTH 王立工科大学発のスタートアップが開発。「End-to-End ML パイプラインを単一プラットフォームで管理する」思想。

Hopsworks AI (SaaS) + Hopsworks Community (OSS)。AWS / GCP / Azure + オンプレミスに対応。バッチ学習 + リアルタイム推論の両方をサポート。特徴量の再利用・共有で ML チームの生産性を向上。

## 3層構造: Feature Store → Model Registry → Serving

```
Hopsworks のアーキテクチャ:

┌─────────────────────────────────────────────────┐
│              Feature Store                       │
│  ┌──────────────┐  ┌────────────────────────┐   │
│  │ Feature Group│  │ Feature View           │   │
│  │ (データ保存) │  │ (学習/推論用クエリ定義)│   │
│  └──────────────┘  └────────────────────────┘   │
│  ・バッチ特徴量 (Hive/Parquet)                    │
│  ・オンライン特徴量 (RonDB — MySQL互換 低遅延)    │
├─────────────────────────────────────────────────┤
│              Model Registry                      │
│  ・モデルバージョン管理                            │
│  ・メタデータ (精度/パラメータ/特徴量リスト)       │
│  ・A/Bテスト用モデル切り替え                       │
├─────────────────────────────────────────────────┤
│              Model Serving                       │
│  ・KServe / Flask ベースのデプロイ                │
│  ・バッチ推論 + リアルタイム API                  │
│  ・モニタリング (データドリフト / 精度劣化)        │
└─────────────────────────────────────────────────┘
```

## Training-Serving Skew の解消

```
ML の大問題: 学習と推論で「違う特徴量」が使われる

  学習時: pandas で手計算した特徴量
  推論時: 本番 API で再実装した特徴量 → バグ・ずれが発生

Hopsworks の解決策:
  Feature View = 学習/推論で「同じクエリ」を使う

  学習: feature_view.training_data() → 学習用 DataFrame
  推論: feature_view.get_feature_vector({"user_id": 123}) → リアルタイム特徴量

  → 同じ Feature View から取得するため絶対にずれない
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬予想特徴量** | 馬・騎手・コース特徴量を Feature Store で一元管理 | 再利用可能な特徴量ライブラリ構築 |
| **ユーザー行動特徴量** | チャーン予測・レコメンド用特徴量を共有 | 複数モデルが同じ特徴量を再利用 |
| **モデル管理** | 精度・バージョン・デプロイ状態を一元追跡 | MLflow より統合度の高い管理 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'hopsworks', 'api',
  'Hopsworks 実践 — Feature Group/Feature View/Python SDK/学習データ生成/オンライン推論/Model Registry/KServe',
  $$## インストール & セットアップ

```bash
pip install hopsworks

# Hopsworks Serverless (SaaS) に接続
# → app.hopsworks.ai でアカウント作成 → API Key 取得
```

## 接続 & プロジェクト初期化

```python
import hopsworks

# Hopsworks に接続 (SaaS / セルフホスト両対応)
project = hopsworks.login(
    project="jibun-kaisha",
    api_key_value="your-api-key",  # または環境変数 HOPSWORKS_API_KEY
)

# Feature Store ハンドル取得
fs = project.get_feature_store()

print(f"Connected to project: {project.name}")
```

## Feature Group: 特徴量の定義と保存

```python
import pandas as pd
import hopsworks

project = hopsworks.login(project="jibun-kaisha")
fs = project.get_feature_store()

# 学習用特徴量データを準備
user_features_df = pd.DataFrame({
    "user_id": [1, 2, 3, 4, 5],
    "days_since_last_active": [5, 30, 60, 2, 90],
    "avg_daily_events": [8.5, 3.2, 1.0, 12.0, 0.5],
    "total_active_days": [180, 60, 30, 200, 10],
    "churn_risk_score": [20.0, 50.0, 75.0, 10.0, 90.0],
    "event_time": pd.to_datetime(["2026-04-28"] * 5),  # タイムスタンプ必須
})

# Feature Group 作成 (初回のみ)
user_fg = fs.create_feature_group(
    name="user_churn_features",
    version=1,
    description="ユーザーチャーン予測用特徴量",
    primary_key=["user_id"],
    event_time="event_time",
    online_enabled=True,   # オンライン推論用 RonDB にも保存
)

# データを Feature Store に書き込み
user_fg.insert(user_features_df)
print("Feature Group に特徴量を保存しました")
```

## Feature View: 学習データ & 推論データ生成

```python
# Feature View = 学習/推論で使うクエリを定義
feature_view = fs.create_feature_view(
    name="churn_prediction_fv",
    version=1,
    query=user_fg.select([
        "days_since_last_active",
        "avg_daily_events",
        "total_active_days",
        "churn_risk_score",
    ]),
    labels=["churn_risk_score"],   # ラベルカラムを指定
)

# ① 学習データ生成 (バッチ)
X_train, X_test, y_train, y_test = feature_view.train_test_split(
    description="2026-04 チャーン予測学習データ",
    test_size=0.2,
)
print(f"学習データ: {X_train.shape}, テストデータ: {X_test.shape}")

# ② リアルタイム推論用特徴量取得 (オンライン)
feature_vector = feature_view.get_feature_vector(
    entry={"user_id": 123},  # primary key で検索
)
print(f"リアルタイム特徴量: {feature_vector}")
# → [5, 8.5, 180] (days_since_last_active, avg_daily_events, total_active_days)
```

## モデル学習 & Model Registry への登録

```python
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.metrics import accuracy_score, roc_auc_score
import joblib
import os

# モデル学習
clf = GradientBoostingClassifier(n_estimators=100, max_depth=4, random_state=42)
clf.fit(X_train, (y_train >= 70).astype(int))  # スコア70以上 = チャーン

# 精度評価
y_pred = clf.predict(X_test)
accuracy = accuracy_score((y_test >= 70).astype(int), y_pred)
auc = roc_auc_score((y_test >= 70).astype(int), clf.predict_proba(X_test)[:, 1])
print(f"Accuracy: {accuracy:.3f}, AUC-ROC: {auc:.3f}")

# モデルを保存
os.makedirs("churn_model", exist_ok=True)
joblib.dump(clf, "churn_model/model.pkl")

# Model Registry に登録
mr = project.get_model_registry()
churn_model = mr.sklearn.create_model(
    name="churn_predictor",
    version=1,
    metrics={"accuracy": accuracy, "auc_roc": auc},
    description="ユーザーチャーン予測モデル v1",
    feature_view=feature_view,         # 使用した Feature View を紐付け
    training_dataset_version=1,
)
churn_model.save("churn_model/")
print(f"Model Registry に登録: {churn_model.name} v{churn_model.version}")
```

## KServe でのデプロイ & 推論 API

```python
# デプロイ (KServe / Hopsworks Serving)
deployment = churn_model.deploy(
    name="churn-predictor-v1",
    serving_tool="kserve",          # KServe / Flask 対応
    script_file="predict.py",       # カスタム推論スクリプト (任意)
    resources={"num_instances": 1},
)

# デプロイ完了まで待機
deployment.start(await_running=180)

# 推論リクエスト
prediction = deployment.predict(inputs={"instances": [[5, 8.5, 180]]})
print(f"チャーン予測: {prediction}")
# → {"predictions": [0.12]}  (チャーン確率 12%)
```

```python
# predict.py — カスタム推論スクリプト
import joblib
import hopsworks

class Predict(object):
    def __init__(self):
        self.model = joblib.load("model.pkl")

        # Feature Store に接続 (推論時に最新特徴量を取得)
        project = hopsworks.login()
        fs = project.get_feature_store()
        self.fv = fs.get_feature_view("churn_prediction_fv", version=1)

    def predict(self, inputs):
        user_id = inputs["user_id"]
        # オンライン Feature Store から最新特徴量を取得
        features = self.fv.get_feature_vector({"user_id": user_id})
        prob = self.model.predict_proba([features])[0][1]
        return {"churn_probability": prob, "is_high_risk": prob >= 0.7}
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 285→286社化: Hopsworks 追加',
  'PS#3 S95。Hopsworks (OSS統合MLプラットフォーム/Feature Group/Feature View/Training-Serving Skew解消/オンライン推論RonDB/Model Registry/KServe/Python SDK/KTH発/SaaS+OSS/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
