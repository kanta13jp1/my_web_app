-- PS#3 S99: AI大学 292→293社化 — Seldon Deploy (Kubernetes MLサービング/カナリアデプロイ/A/Bテスト)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'seldon-deploy', 'overview',
  'Seldon Deploy — Kubernetes MLサービング・カナリアデプロイ・A/Bテスト・モデル説明性 (GitHub 4k+ / 8/9)',
  $$## Seldon Deploy とは

**Seldon Deploy** は **Kubernetes 上で ML モデルを本番サービングするオープンソースフレームワーク**。英国 Seldon Technologies 社が開発。Seldon Core (OSS) + Seldon Deploy (エンタープライズ管理UI) の2層構成。

GitHub 4,000+ スター (Seldon Core)。Apache 2.0 ライセンス。KServe / BentoML / Triton Server と比較されることが多い。Alibaba / Vodafone / Skyscanner などで採用。

## Seldon の強み: 安全なデプロイ戦略

```
本番 ML の課題: モデル更新リスクをどう管理するか

  Seldon が提供するデプロイ戦略:
  ┌──────────────────────────────────────────────┐
  │  1. カナリアデプロイ                           │
  │     新モデル 10% / 旧モデル 90% でトラフィック分割
  │     問題なければ段階的に移行                    │
  │                                              │
  │  2. A/B テスト                                │
  │     複数モデルを並行運用 → 精度を実測比較       │
  │                                              │
  │  3. シャドウデプロイ                           │
  │     新モデルに本番トラフィックをコピー送信      │
  │     結果はサービングしない (観察のみ)           │
  │                                              │
  │  4. マルチアーム・バンディット                  │
  │     精度の高いモデルに自動的にトラフィックを増加 │
  └──────────────────────────────────────────────┘
```

## モデル説明性 (Alibi)

```
Seldon の独自強み: Alibi ライブラリとの統合

  Alibi Explain:
    - SHAP / LIME / Anchors / Counterfactuals
    - 「なぜこの予測をしたか」を説明する API
    - 本番モデルにサイドカーとして追加するだけで有効化

  Alibi Detect:
    - データドリフト / 外れ値 / 敵対的サンプル検出
    - Evidently / NannyML と相補的な位置づけ

  → 金融・医療など説明責任が求められる領域で特に重要
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬予想 v2** | 新モデルをカナリア 10% でテスト | 本番的中率を下げずに安全にモデル更新 |
| **チャーン予測** | A/B テストで複数モデルを実測比較 | オフライン評価より信頼できる本番精度 |
| **説明性 API** | 「なぜチャーンリスクが高いか」を自動生成 | ユーザー向け改善提案に活用 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'seldon-deploy', 'api',
  'Seldon Deploy 実践 — SeldonDeployment/カナリア/A-Bテスト/Alibi Explain/Python SDK/Kubernetes/YAML',
  $$## インストール & セットアップ

```bash
# Seldon Core を Kubernetes にインストール (Helm)
helm repo add seldonio https://storage.googleapis.com/seldon-charts
helm repo update

helm install seldon-core seldonio/seldon-core-operator \
  --namespace seldon-system \
  --create-namespace \
  --set usageMetrics.enabled=true

# Python SDK
pip install seldon-core
```

## 基本: SeldonDeployment (Kubernetes YAML)

```yaml
# churn_model_deployment.yaml
apiVersion: machinelearning.seldon.io/v1
kind: SeldonDeployment
metadata:
  name: churn-predictor
  namespace: seldon
spec:
  name: churn-predictor
  predictors:
    - name: default
      graph:
        name: churn-model
        type: MODEL
        implementation: SKLEARN_SERVER
        modelUri: gs://jibun-kaisha-ml/models/churn_v3/
      replicas: 2
      traffic: 100    # このバージョンに100%のトラフィック
```

```bash
kubectl apply -f churn_model_deployment.yaml

# デプロイ状態確認
kubectl get seldondeployment -n seldon
```

## カナリアデプロイ

```yaml
# canary_deployment.yaml — 新旧モデルを同時にデプロイ
apiVersion: machinelearning.seldon.io/v1
kind: SeldonDeployment
metadata:
  name: churn-predictor
  namespace: seldon
spec:
  name: churn-predictor
  predictors:
    - name: main         # 旧モデル (90%)
      graph:
        name: churn-model-v3
        type: MODEL
        implementation: SKLEARN_SERVER
        modelUri: gs://jibun-kaisha-ml/models/churn_v3/
      replicas: 3
      traffic: 90

    - name: canary       # 新モデル (10%)
      graph:
        name: churn-model-v4
        type: MODEL
        implementation: SKLEARN_SERVER
        modelUri: gs://jibun-kaisha-ml/models/churn_v4/
      replicas: 1
      traffic: 10
```

```bash
kubectl apply -f canary_deployment.yaml

# 新モデルの精度が良ければトラフィックを増加
# traffic: 10 → 50 → 100 に段階移行
```

## A/B テスト

```yaml
# ab_test_deployment.yaml
apiVersion: machinelearning.seldon.io/v1
kind: SeldonDeployment
metadata:
  name: churn-ab-test
  namespace: seldon
spec:
  name: churn-ab-test
  predictors:
    - name: model-a
      graph:
        name: gradient-boosting
        type: MODEL
        implementation: SKLEARN_SERVER
        modelUri: gs://jibun-kaisha-ml/models/gb_churn/
      traffic: 50

    - name: model-b
      graph:
        name: neural-network
        type: MODEL
        implementation: TRITON_SERVER  # NVIDIA Triton
        modelUri: gs://jibun-kaisha-ml/models/nn_churn/
      traffic: 50
```

## Python カスタムサーバー

```python
# MyModel.py — カスタム推論ロジック
import numpy as np
import joblib
from typing import List

class MyModel:
    def __init__(self):
        self.model = None

    def load(self):
        """モデルのロード (初回のみ)"""
        self.model = joblib.load("/mnt/models/churn_model.pkl")
        self.scaler = joblib.load("/mnt/models/scaler.pkl")

    def predict(self, X: np.ndarray, features_names: List[str] = None) -> np.ndarray:
        """推論"""
        X_scaled = self.scaler.transform(X)
        probas = self.model.predict_proba(X_scaled)
        return probas[:, 1]   # チャーン確率のみ返す

    def metrics(self):
        """カスタムメトリクス (Prometheus に公開)"""
        return [
            {"type": "COUNTER", "key": "prediction_count", "value": 1},
        ]
```

```bash
# Docker コンテナとしてパッケージ化
docker build -t my-registry/churn-model:v4 .
docker push my-registry/churn-model:v4
```

## Alibi Explain との統合 (モデル説明性)

```yaml
# explain_deployment.yaml — 説明性サイドカー
apiVersion: machinelearning.seldon.io/v1
kind: SeldonDeployment
metadata:
  name: churn-with-explanation
  namespace: seldon
spec:
  name: churn-with-explanation
  predictors:
    - name: default
      graph:
        name: churn-model
        type: MODEL
        implementation: SKLEARN_SERVER
        modelUri: gs://jibun-kaisha-ml/models/churn_v3/
        # 説明性サイドカーをアタッチ
        children:
          - name: explainer
            type: MODEL
            implementation: ALIBI_EXPLAIN_SERVER
            modelUri: gs://jibun-kaisha-ml/explainers/churn_shap/
            envSecretRefName: seldon-init-container-secret
      traffic: 100
```

```python
# 推論 + 説明を同時取得
import requests

payload = {"data": {"ndarray": [[5, 8.5, 180]]}}

# 通常の予測
pred = requests.post("http://seldon/seldon/churn-with-explanation/api/v1.0/predictions", json=payload)
print(f"Churn probability: {pred.json()['data']['ndarray'][0][0]:.3f}")

# 説明の取得
explain = requests.post(
    "http://seldon/seldon/churn-with-explanation/api/v1.0/explain",
    json=payload,
)
shap_values = explain.json()["data"]["shap_values"]
print("重要特徴量 (SHAP):")
feature_names = ["days_since_last_active", "avg_daily_events", "total_active_days"]
for name, val in zip(feature_names, shap_values[0]):
    print(f"  {name}: {val:+.3f}")
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 292→293社化: Seldon Deploy 追加',
  'PS#3 S99。Seldon Deploy (Kubernetes MLサービング/カナリアデプロイ/A-Bテスト/シャドウデプロイ/マルチアームバンディット/Alibi Explain SHAP統合/Python カスタムサーバー/GitHub 4k+/Apache 2.0/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
