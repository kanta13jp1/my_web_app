-- PS#3 S87: AI大学 269→270社化 — Seldon Core (OSS Kubernetes MLOps / モデルサービング)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'seldon-core', 'overview',
  'Seldon Core — OSS Kubernetes MLOps・マルチフレームワークモデルサービング・説明可能AI統合 (GitHub 4k+ / 8/9)',
  $$## Seldon Core とは

**Seldon Core** は Kubernetes 上でMLモデルを**本番サービング**するための OSS フレームワーク。英国スタートアップ Seldon Technologies が開発。2017年 OSS 化。

GitHub 4,000+ スター。Apache 2.0 ライセンス。PyTorch / TensorFlow / SKLearn / XGBoost / HuggingFace など**あらゆるフレームワークを統一 API** でサービングできる。

## Seldon Core の特徴

```
"どんなMLフレームワークでも Kubernetes で本番化"

対応フレームワーク (プリビルドサーバー):
  ✓ SKLearn (sklearn)
  ✓ XGBoost (xgboost)
  ✓ TensorFlow (tensorflow)
  ✓ PyTorch (torchserve)
  ✓ HuggingFace (huggingface)
  ✓ ONNX (triton)
  ✓ カスタム Python コード
```

## Seldon Core v2 (2024年最新)

```
Seldon Core v1 → v2 の進化:

v1:
  ・SeldonDeployment CRD
  ・独自プロトコル
  ・モノリシック設計

v2:
  ・KServe との統合強化 (共通 CRD)
  ・Open Inference Protocol (v2 推論プロトコル)
  ・Kafka 統合 (非同期推論)
  ・MLServer バックエンド (高速 Python サーバー)
  ・説明可能 AI (Alibi Explain) ネイティブ統合
```

## 説明可能 AI (Alibi Explain) 統合

```
Seldon の最大差別化ポイント:
  → 推論と同時に「なぜ?」を返せる

説明手法:
  ・Anchor (ルールベース説明): 「この予測はこの条件が成立する時だけ」
  ・SHAP: 各特徴量の寄与度
  ・LIME: 局所的な近似モデルで説明
  ・Counterfactual: 「何が変われば判定が変わるか?」
  ・Integrated Gradients: ニューラルネット向け

ユースケース:
  ・ローン審査 → 「なぜ否決されたか」をユーザーに説明
  ・医療診断 → 「どの検査値が異常を示しているか」
  ・不正検知 → 「なぜ不正と判定したか」
```

## A/B テスト・カナリアリリース

```yaml
# canary-deployment.yaml (段階的ロールアウト)
apiVersion: machinelearning.seldon.io/v1
kind: SeldonDeployment
metadata:
  name: jibun-kaisha-ab-test
spec:
  predictors:
    - name: production        # 現行モデル (90%のトラフィック)
      replicas: 3
      traffic: 90
      graph:
        name: bert-japanese-v1
        type: MODEL
        implementation: HUGGINGFACE_SERVER
        modelUri: gs://jibun-kaisha-ml/models/bert-ja-v1/

    - name: canary            # 新モデル (10%のトラフィック)
      replicas: 1
      traffic: 10
      graph:
        name: bert-japanese-v2
        type: MODEL
        implementation: HUGGINGFACE_SERVER
        modelUri: gs://jibun-kaisha-ml/models/bert-ja-v2/
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **段階リリース** | カナリアで新モデルを安全に展開 | 品質リスク最小化 |
| **説明可能AI** | Alibi でユーザーへの判定根拠提示 | 信頼性・透明性向上 |
| **マルチモデル** | 複数フレームワークを統一 API で | 開発自由度最大化 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'seldon-core', 'api',
  'Seldon Core 実践 — SeldonDeployment/MLServer/Python カスタムモデル/Alibi説明可能AI/Kafka非同期推論',
  $$## インストール

```bash
# Helm でインストール
helm install seldon-core seldon-core-operator \
  --repo https://storage.googleapis.com/seldon-charts \
  --set usageMetrics.enabled=true \
  --namespace seldon-system \
  --create-namespace

# MLServer (Python 高速サーバー)
pip install mlserver mlserver-huggingface mlserver-sklearn
```

## HuggingFace モデルのサービング (最小設定)

```yaml
# hf-deployment.yaml
apiVersion: machinelearning.seldon.io/v1
kind: SeldonDeployment
metadata:
  name: jibun-kaisha-bert
  namespace: seldon
spec:
  predictors:
    - name: default
      replicas: 2
      graph:
        name: classifier
        type: MODEL
        implementation: HUGGINGFACE_SERVER
        modelUri: gs://jibun-kaisha-ml/models/bert-japanese-sentiment/
        envSecretRefName: seldon-gcs-credentials
      componentSpecs:
        - spec:
            containers:
              - name: classifier
                resources:
                  limits:
                    memory: 4Gi
                    nvidia.com/gpu: "1"
```

```bash
# デプロイ適用
kubectl apply -f hf-deployment.yaml

# エンドポイント確認
kubectl get seldondeployments -n seldon

# 推論テスト (V2 推論プロトコル)
curl -X POST http://localhost:9000/v2/models/classifier/infer \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": [{
      "name": "input-0",
      "shape": [1],
      "datatype": "BYTES",
      "data": ["このサービスは素晴らしいです"]
    }]
  }'
```

## カスタム Python モデル (MLServer)

```python
# model.py (カスタムモデルサーバー)
from mlserver import MLModel
from mlserver.types import InferenceRequest, InferenceResponse, ResponseOutput
from mlserver.codecs import NumpyCodec
import numpy as np
from transformers import pipeline

class JibunKaishaClassifier(MLModel):
    async def load(self) -> bool:
        """モデルロード (起動時1回だけ)"""
        self.pipeline = pipeline(
            "text-classification",
            model="koheiduck/bert-japanese-finetuned-sentiment",
            device=0,  # GPU
        )
        return True

    async def predict(self, payload: InferenceRequest) -> InferenceResponse:
        """推論"""
        texts = NumpyCodec.decode_input(payload.inputs[0]).tolist()

        results = self.pipeline(texts, batch_size=16)

        labels = np.array([r["label"] for r in results])
        scores = np.array([r["score"] for r in results])

        return InferenceResponse(
            model_name=self.name,
            outputs=[
                ResponseOutput(
                    name="label",
                    shape=labels.shape,
                    datatype="BYTES",
                    data=labels.tolist(),
                ),
                ResponseOutput(
                    name="score",
                    shape=scores.shape,
                    datatype="FP32",
                    data=scores.tolist(),
                ),
            ],
        )
```

```bash
# MLServer でローカル起動 (テスト)
mlserver start .

# Docker でコンテナ化 (Seldon にデプロイ)
mlserver build . -t jibun-kaisha/sentiment-server:v1
docker push jibun-kaisha/sentiment-server:v1
```

## Alibi Explain: 説明可能 AI

```python
# explain.py
from alibi.explainers import AnchorText
import spacy

# テキスト分類モデルの説明
nlp = spacy.load("ja_core_news_sm")

def predict_fn(texts):
    """Seldon エンドポイントを呼び出す関数"""
    import requests
    response = requests.post(
        "http://jibun-kaisha-bert/v2/models/classifier/infer",
        json={"inputs": [{"name": "input-0", "data": list(texts)}]}
    )
    return response.json()["outputs"][0]["data"]

# Anchor テキスト説明器
explainer = AnchorText(
    predictor=predict_fn,
    sampling_strategy="unknown",
    nlp=nlp,
)

# 説明生成
text = "この商品は品質が悪くてがっかりしました"
explanation = explainer.explain(text, threshold=0.95)

print(f"Prediction: {explanation.data['prediction']}")  # negative
print(f"Anchor: {explanation.data['anchor']}")           # ['品質が悪く']
print(f"Precision: {explanation.data['precision']:.2f}") # 0.98
print(f"Coverage: {explanation.data['coverage']:.2f}")   # 0.45
# → 「品質が悪く」という単語があれば 98% の確率で negative と予測
```

## Kafka 非同期推論 (大量バッチ処理)

```yaml
# kafka-deployment.yaml
apiVersion: machinelearning.seldon.io/v1
kind: SeldonDeployment
metadata:
  name: jibun-kaisha-async
spec:
  serverType: kafka
  predictors:
    - name: default
      graph:
        name: classifier
        type: MODEL
        implementation: HUGGINGFACE_SERVER
        modelUri: gs://jibun-kaisha-ml/models/bert-ja/
      kafka:
        inputTopic: jibun-kaisha-input    # 入力 Kafka トピック
        outputTopic: jibun-kaisha-output  # 出力 Kafka トピック
        bootstrapServers: kafka:9092
```

```python
# Kafka 非同期推論 (プロデューサー)
from kafka import KafkaProducer
import json

producer = KafkaProducer(
    bootstrap_servers=["kafka:9092"],
    value_serializer=lambda v: json.dumps(v).encode("utf-8"),
)

# 大量テキストを Kafka に投入
texts = ["テキスト1", "テキスト2", ..., "テキスト10000"]
for text in texts:
    producer.send("jibun-kaisha-input", {"text": text})

# 結果は jibun-kaisha-output トピックに非同期で届く
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 269→270社化: Seldon Core 追加',
  'PS#3 S87。Seldon Core (OSS Kubernetes MLOps/SeldonDeployment CRD/MLServer Python サーバー/Alibi Explain説明可能AI/カナリアA/Bテスト/Kafka非同期推論/マルチフレームワーク統一API/GitHub 4k+/Apache 2.0/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
