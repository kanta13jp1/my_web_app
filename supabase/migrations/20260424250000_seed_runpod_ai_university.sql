-- Session PS#3-S35: AI大学 165社化 — RunPod 追加
-- 2022 年創業の GPU クラウドマーケットプレイス。世界中のデータセンターの GPU 在庫を集約。
-- Community Cloud (スポット): RTX 3090 $0.19/h〜 / A100 80GB $0.89/h〜 (業界最安水準)
-- Secure Cloud (オンデマンド): 本番推論向け高信頼性インスタンス
-- Serverless: 秒課金 / コールドスタート 48% が 200ms 以下 / 30+ GPU SKU / 8+ リージョン
-- 独自の Serverless API + Webhook / カスタムイメージ対応 / RunPod Worker で任意ロジック実行
-- 既存 164 社の「格安 GPU マーケットプレイス」軸を埋める (Modal はサーバーレス抽象化 / RunPod は生 GPU アクセス)
-- Step 0: 7.5/9 (RTX 3090 $0.19 業界最安 / 30+ GPU SKU / Serverless 200ms / Developer API / 独立系)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'runpod',
  'overview',
  'RunPod — 世界最安水準の GPU クラウドマーケットプレイス',
  $md$
# RunPod — GPU Cloud for AI/ML Developers

2022 年創業。世界中のデータセンターから GPU 在庫を集約し、
**業界最安水準の価格** で AI・ML ワークロードに提供するクラウドマーケットプレイス。

**RTX 3090 が $0.19/時間**から利用可能で、コスト重視の研究者・スタートアップ・
個人開発者に広く使われている。AWS/GCP に比べて **60〜80% 安価** な GPU を
シンプルな Web コンソールと REST API で提供。

## 3 種類のコンピュートモード

| モード | 特徴 | 用途 |
| :--- | :--- | :--- |
| **Community Cloud (スポット)** | 最安価・空き在庫を活用 | 学習・研究・試作 |
| **Secure Cloud (オンデマンド)** | 高信頼性・本番用 | 推論 API・本番ワークロード |
| **Serverless** | 秒課金・自動スケール | API エンドポイント・バッチ |

## 強み

- **格安 GPU** — RTX 3090 $0.19/h / A100 80GB $0.89/h (AWS の 1/4 程度)
- **30+ GPU SKU** — RTX 3060 〜 H100 SXM まで幅広いラインナップ
- **Serverless** — 48% のコールドスタートが 200ms 未満・秒単位課金
- **自由度の高いカスタムイメージ** — 任意の Docker イメージを GPU で実行
- **RunPod Worker** — 独自ロジックを Serverless エンドポイントとして公開
- **グローバル 8+ リージョン** — EU / US / APAC のデータ主権要件に対応
$md$,
  'https://www.runpod.io/',
  '2026-04-24',
  1
),

(
  'runpod',
  'models',
  'RunPod GPU 価格・プラン一覧 (2026)',
  $md$
## Community Cloud (スポット) 価格

| GPU | VRAM | 時間単価 | 特徴 |
| :--- | :--- | :--- | :--- |
| **RTX 3090** | 24 GB | ~$0.19/h | 最安クラス・推論向け |
| **RTX 4090** | 24 GB | ~$0.34/h | 高速推論・コスパ最高 |
| **A100 (40GB)** | 40 GB | ~$0.69/h | 大規模学習 |
| **A100 (80GB)** | 80 GB | ~$0.89/h | 大型モデル学習 |
| **H100 SXM** | 80 GB | ~$3.49/h | 最新世代・高スループット |

> Community Cloud は空き在庫依存。可用性が下がる場合あり

## Serverless 価格

| GPU | 1秒あたり | 100K リクエスト目安 |
| :--- | :--- | :--- |
| RTX 4090 | $0.000079/s | ~$2.8 |
| A100 80GB | $0.00025/s | ~$9 |
| H100 | $0.00048/s | ~$17 |

## RunPod vs 主要競合

| プロバイダー | A100 80GB | 特徴 |
| :--- | :--- | :--- |
| **RunPod** | ~$0.89/h | 最安・マーケットプレイス |
| Modal | ~$3.72/h | Python-native 抽象化 |
| AWS (p4d) | ~$32/h | 高信頼性・Enterprise |
| Lambda Labs | ~$1.25/h | シンプル On-demand |
$md$,
  'https://www.runpod.io/pricing',
  '2026-04-24',
  2
),

(
  'runpod',
  'api',
  'RunPod Serverless API 入門',
  $md$
## RunPod Serverless の始め方

### Step 1: RunPod Worker の定義 (handler.py)

```python
# handler.py — GPU で実行されるロジックを記述

import runpod

def handler(job):
    """RunPod Worker のメインハンドラ"""
    job_input = job["input"]
    prompt = job_input.get("prompt", "Hello")

    # ここに任意のモデル推論ロジックを記述
    from transformers import pipeline
    pipe = pipeline("text-generation", model="mistralai/Mistral-7B-Instruct-v0.2")
    result = pipe(prompt, max_new_tokens=256)

    return {"generated_text": result[0]["generated_text"]}

runpod.serverless.start({"handler": handler})
```

### Step 2: Dockerfile

```dockerfile
FROM runpod/pytorch:2.1.0-py3.10-cuda11.8.0-devel-ubuntu22.04

# 依存関係インストール
RUN pip install transformers runpod

# Worker スクリプトをコピー
COPY handler.py /app/handler.py

CMD ["python", "/app/handler.py"]
```

### Step 3: REST API でエンドポイントを呼び出す

```python
import requests
import time

ENDPOINT_ID = "your-endpoint-id"
API_KEY = "your-runpod-api-key"

# ジョブをサブミット
response = requests.post(
    f"https://api.runpod.ai/v2/{ENDPOINT_ID}/runsync",
    headers={"Authorization": f"Bearer {API_KEY}"},
    json={"input": {"prompt": "AI大学で学べることは？"}}
)

result = response.json()
print(result["output"]["generated_text"])
```

### 既存モデルをワンクリックデプロイ

RunPod は Llama 3 / Stable Diffusion / Whisper などを
**テンプレートから 1 クリック**でデプロイ可能。
コンソール → Templates → モデル選択 → Deploy でエンドポイント作成。

## クイックスタート

1. [runpod.io](https://www.runpod.io) でアカウント作成 (クレジットカード不要で閲覧可)
2. GPU Pod または Serverless Endpoint を作成
3. `pip install runpod` でローカル SDK をインストール
4. `handler.py` を実装 → Docker イメージをビルド → RunPod にデプロイ
5. REST API で `runsync` / `run` エンドポイントを呼び出し
$md$,
  'https://docs.runpod.io/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
