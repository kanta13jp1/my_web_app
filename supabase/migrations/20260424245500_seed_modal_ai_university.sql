-- Session PS#3-S34: AI大学 164社化 — Modal Labs 追加
-- Eric Abe + Akshat Bubna + Jonathon Leffler が 2021 年に創業したサーバーレス GPU クラウド。
-- $87M Series B (Lux Capital 主導) → 累計 $111M / 評価額 $1.1B。
-- `@modal.function` デコレータ1行で Python 関数をクラウド GPU にデプロイ。
-- YAML / Docker / Kubernetes 一切不要 — Python だけで ML インフラを記述。
-- 無料 $30/月クレジット / GPU 秒課金 (H100 $4.76/h / B200 $6.25/h)。
-- サブ秒コールドスタート / 数千 GPU 並列スケール / 長時間学習ジョブも対応。
-- 既存 162 社の「サーバーレス GPU インフラ」軸空白を埋める (CoreWeave はベアメタル / Modal は抽象化層)。
-- Step 0: 9/9 (Python-native デコレータ API / $1.1B 評価 / 無料枠 / H100/B200 対応 / sub-second cold start)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'modal',
  'overview',
  'Modal Labs — Python-Native サーバーレス GPU クラウド',
  $md$
# Modal — Run Python on Cloud GPUs

2021 年創業。**Eric Abe** らが「ML エンジニアが Docker・Kubernetes・YAML を
一切書かずに、Python コードだけでクラウド GPU を使える」世界を実現するために設立。

`@modal.function` デコレータを 1 行追加するだけで、ローカルの Python 関数が
**クラウド GPU にデプロイ**される。コンテナ定義・スケーリング設定・
インフラ管理をすべて Modal が自動処理。

**$87M Series B** (Lux Capital 主導 / 2024) で累計 **$111M** を調達し、
評価額 **$1.1B (ユニコーン)** に到達。

## 主要機能

- **@modal.function** — Python デコレータでサーバーレス GPU 関数を宣言
- **@modal.image** — Python コードで Docker イメージを定義 (コマンド不要)
- **@modal.volume** — 永続ストレージ (モデル重み / データセット)
- **@modal.web_endpoint** — FastAPI / Gradio を即座に公開 Web API 化
- **@modal.cron** — スケジュールバッチ処理 (定期推論 / データ収集)

## 強み

- **サブ秒コールドスタート** — 通常の Lambda/Cloud Functions より 10× 高速起動
- **Python-native** — YAML / Dockerfile 完全不要・Python だけで完結
- **大規模並列** — 数千 GPU の並列実行を 1 関数呼び出しで起動
- **長時間ジョブ対応** — 数時間の学習ジョブ + 短時間推論を同一プラットフォームで
- **$30/月 無料クレジット** — プロトタイプを無料で開始
$md$,
  'https://modal.com/',
  '2026-04-24',
  1
),

(
  'modal',
  'models',
  'Modal GPU プラン・料金一覧 (2026)',
  $md$
## GPU 料金 (秒単位課金)

| GPU | VRAM | 時間単価 | 用途 |
| :--- | :--- | :--- | :--- |
| **T4** | 16 GB | ~$0.59/h | 推論 (軽量モデル) |
| **A10G** | 24 GB | ~$1.10/h | 推論 (中規模) |
| **A100 (40GB)** | 40 GB | ~$2.78/h | 学習・大規模推論 |
| **A100 (80GB)** | 80 GB | ~$3.72/h | 学習 (大型モデル) |
| **H100** | 80 GB | ~$4.76/h | 最新モデル学習 |
| **B200** | 192 GB | ~$6.25/h | 最大規模・最新世代 |

> GPU 時間は **秒単位**で課金 — アイドル時はコストゼロ

## プラン

| プラン | 月額 | 無料クレジット |
| :--- | :--- | :--- |
| **Starter** | $0 | $30/月 無料クレジット |
| **Team** | $25/月〜 | 追加クレジット + チーム機能 |
| **Enterprise** | 要相談 | 専用クラスタ / SLA |

## 主要 Decorator API

| デコレータ | 機能 |
| :--- | :--- |
| `@modal.function(gpu="H100")` | GPU 関数をデプロイ |
| `@modal.image.debian_slim()` | コンテナ環境を Python で定義 |
| `@modal.volume()` | 永続ストレージをマウント |
| `@modal.web_endpoint()` | HTTPS エンドポイントを公開 |
| `@modal.cron("0 * * * *")` | 1 時間毎にスケジュール実行 |
| `@modal.batched(max_batch_size=64)` | バッチ推論 (スループット最大化) |
$md$,
  'https://modal.com/pricing',
  '2026-04-24',
  2
),

(
  'modal',
  'api',
  'Modal API 入門',
  $md$
## Modal の始め方

### インストール & セットアップ

```bash
pip install modal
modal setup        # ブラウザでアカウント作成・API キー設定
```

### 基本: GPU 関数のデプロイ

```python
# inference.py

import modal

# GPU 環境定義 (Python だけ — Docker 不要)
image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install("transformers", "torch", "accelerate")
)

app = modal.App("llm-inference", image=image)

@app.function(gpu="A10G", timeout=300)  # A10G GPU を使用・タイムアウト 5分
def generate_text(prompt: str) -> str:
    from transformers import pipeline

    pipe = pipeline("text-generation", model="mistralai/Mistral-7B-Instruct-v0.2")
    result = pipe(prompt, max_new_tokens=256)
    return result[0]["generated_text"]

# ローカルから呼び出し
@app.local_entrypoint()
def main():
    result = generate_text.remote("AI大学の最新プロバイダーは？")
    print(result)
```

```bash
# デプロイ & 実行
modal run inference.py
```

### Web Endpoint (API サーバー)

```python
from fastapi import FastAPI
import modal

web_app = FastAPI()
app = modal.App("llm-api")

image = modal.Image.debian_slim().pip_install("transformers", "torch")

@app.function(gpu="H100", image=image)
@modal.asgi_app()
def fastapi_app():
    @web_app.post("/generate")
    async def generate(prompt: str):
        # GPU 推論ロジック
        return {"text": f"Response to: {prompt}"}
    return web_app
```

```bash
modal deploy inference.py   # HTTPS URL が自動割当
# → https://username--llm-api-fastapi-app.modal.run
```

### 大規模並列バッチ処理

```python
@app.function(gpu="A100-80GB")
def process_batch(items: list[str]) -> list[str]:
    return [embed(item) for item in items]

# 1,000件を並列処理 (自動スケール)
results = list(process_batch.map(["text1", "text2", ...] * 1000))
```

## クイックスタート

1. `pip install modal` → `modal setup` でアカウント作成
2. `@app.function(gpu="T4")` デコレータを追加
3. `modal run script.py` でクラウド GPU 実行
4. `modal deploy script.py` で常時稼働 Web API 化
$md$,
  'https://modal.com/docs',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
