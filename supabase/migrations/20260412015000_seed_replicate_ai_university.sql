-- Replicate コンテンツシード
-- AI大学: Replicate プロバイダーの初期コンテンツ (overview / models / api)
-- 追加理由: 画像・動画・音声生成に特化したモデルホスティング / FLUX・Stable Diffusion・Whisper等を秒課金で利用 / オープンソースモデルのデプロイ基盤としても活用

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('replicate', 'overview', 'Replicate 概要',
$$Replicate は2019年創業のAIモデルホスティングプラットフォーム。**画像・動画・音声生成モデルを秒課金で手軽に利用**できるサービスを提供しています。FLUX・Stable Diffusion・Whisper・LLaMA など数千のオープンソースモデルをAPIで即利用可能で、自分のカスタムモデルをデプロイして公開することもできます。

## 特徴

- **数千のモデル**: FLUX・Stable Diffusion・ControlNet・Whisper・LLaMA など画像/動画/音声/テキストの幅広いモデルを提供
- **秒課金**: モデル実行時間に応じた完全従量課金。アイドル時のコストゼロ
- **カスタムモデルデプロイ**: 自分で学習したモデルを Replicate にデプロイして API として公開・共有可能
- **Cog コンテナ**: Docker ベースの `cog` ツールでモデルをコンテナ化し、Replicate にデプロイ
- **Webhooks**: 非同期処理で長時間実行モデルの結果を Webhook で受信

## 強み

| 領域 | 内容 |
| :--- | :--- |
| **画像生成** | FLUX.1・Stable Diffusion 3・SDXL・ControlNet など最新モデルを網羅 |
| **動画生成** | Stable Video Diffusion・Zeroscope・AnimateDiff 対応 |
| **音声** | Whisper 多言語音声認識・MusicGen 音楽生成・Bark 音声合成 |
| **モデル共有** | Hugging Face 的なモデル共有エコシステム。コミュニティモデル数千本 |
| **低障壁** | クレジットカード登録後すぐにAPIキー発行・即利用可能 |

## 主要ユーザー

プロトタイピング・クリエイティブツール開発・研究者が多く利用。特に画像生成AIを組み込んだWebアプリ開発で人気です。$$,
'https://replicate.com/', '2026-04-12', 1),

('replicate', 'models', 'Replicate — 利用可能モデル (2026)',
$$Replicate では数千のモデルが公開されています。人気モデルを紹介します。

## 画像生成モデル

| モデル | 特徴 | 実行時間目安 |
| :--- | :--- | :--- |
| **black-forest-labs/flux-1.1-pro** | FLUX 最新高品質版 | 約5秒 |
| **black-forest-labs/flux-dev** | FLUX [dev] — 高品質 | 約8秒 |
| **black-forest-labs/flux-schnell** | FLUX [schnell] — 超高速 | 約2秒 |
| **stability-ai/stable-diffusion-3** | SD3 — 高品質テキスト描画 | 約10秒 |
| **stability-ai/sdxl** | SDXL — 1024px高解像度 | 約15秒 |
| **lucataco/animate-diff-v2** | AnimateDiff — 動画生成 | 約30秒 |

## テキスト生成モデル

| モデル | コンテキスト | 特徴 |
| :--- | :--- | :--- |
| **meta/meta-llama-3.1-405b-instruct** | 128K | LLaMA 3.1 405B |
| **meta/meta-llama-3-70b-instruct** | 8K | LLaMA 3 70B |
| **mistralai/mixtral-8x7b-instruct-v0.1** | 32K | Mixtral MoE |

## 音声・音楽モデル

| モデル | 特徴 |
| :--- | :--- |
| **openai/whisper** | 多言語音声認識 (99言語対応) |
| **vaibhavs10/incredibly-fast-whisper** | Whisper 高速版 |
| **meta/musicgen** | テキストから音楽生成 |
| **suno-ai/bark** | 高品質音声合成 |

## ControlNet (画像制御生成)

```text
# ポーズ制御・輪郭制御・深度制御などの ControlNet モデルも多数公開
lllyasviel/controlnet-hed       — エッジ検出による制御
lllyasviel/controlnet-openpose  — 人物ポーズ制御
jagilley/controlnet-depth       — 深度マップによる制御
```$$,
'https://replicate.com/explore', '2026-04-12', 2),

('replicate', 'api', 'Replicate API 入門',
$$## セットアップ

```bash
pip install replicate
```

## Python SDK でテキスト生成

```python
import replicate

# 環境変数 REPLICATE_API_TOKEN を設定しておく
# export REPLICATE_API_TOKEN="<YOUR_TOKEN>"

# LLaMA 3 でテキスト生成
output = replicate.run(
    "meta/meta-llama-3-70b-instruct",
    input={
        "prompt": "Flutter Web でのパフォーマンス最適化のベストプラクティスを5つ教えてください。",
        "max_tokens": 512,
        "temperature": 0.7,
    }
)

# ストリーミング出力
for text in output:
    print(text, end="")
```

## 画像生成 (FLUX)

```python
import replicate

# FLUX.1 [schnell] で画像生成 (高速)
output = replicate.run(
    "black-forest-labs/flux-schnell",
    input={
        "prompt": "A serene Japanese zen garden with cherry blossoms, golden hour lighting, photorealistic",
        "num_outputs": 1,
        "width": 1024,
        "height": 1024,
        "num_inference_steps": 4,  # schnell は 4ステップで高速生成
    }
)

# 画像URLを取得してダウンロード
import urllib.request
image_url = str(output[0])
urllib.request.urlretrieve(image_url, "generated.webp")
print(f"画像生成完了: {image_url}")
```

## 非同期実行 (長時間モデル向け)

```python
import replicate

# 非同期で実行開始
prediction = replicate.predictions.create(
    model="stability-ai/stable-diffusion-3",
    input={
        "prompt": "Futuristic smart city in Japan, ultra-detailed, 8k resolution",
        "negative_prompt": "blurry, low quality",
        "num_inference_steps": 28,
        "guidance_scale": 7.0,
    }
)

print(f"Prediction ID: {prediction.id}")
print(f"Status: {prediction.status}")  # "starting"

# 完了まで待機
prediction.wait()
print(f"完了: {prediction.output}")
```

## Webhook で結果を受信

```python
import replicate

# Webhook URL を指定して非同期実行
prediction = replicate.predictions.create(
    model="black-forest-labs/flux-dev",
    input={"prompt": "A beautiful Japanese landscape"},
    webhook="https://your-server.com/webhook/replicate",
    webhook_events_filter=["completed"]
)
# Webhook エンドポイントで結果を受信
```

## カスタムモデルのデプロイ

```bash
# cog でモデルをコンテナ化
pip install cog
cog init          # predict.py のテンプレートを生成

# predict.py でモデル推論ロジックを記述後
cog build         # ローカルでビルドテスト
cog push r8.im/<username>/<model-name>  # Replicate にデプロイ
```

## 料金 (2026年4月時点, USD)

| モデル | 料金 |
| :--- | :--- |
| **FLUX.1 [schnell]** | $0.003/画像 |
| **FLUX.1 [dev]** | $0.025/画像 |
| **FLUX 1.1 Pro** | $0.04/画像 |
| **LLaMA 3 70B** | $0.65/1M tokens |
| **Whisper** | $0.0059/分 |

- **CPU インスタンス**: $0.000100/秒
- **GPU (A40)**: $0.001400/秒
- **GPU (A100)**: $0.002300/秒$$,
'https://replicate.com/docs/get-started/python', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 Replicate 追加 (24社目)',
  'Replicate を AI大学プロバイダーとして追加。画像生成(FLUX/SDXL/ControlNet)・動画生成・音声認識(Whisper)・音楽生成(MusicGen)・テキスト生成のマルチモーダルプラットフォームとして収録。非同期実行・Webhook・カスタムモデルデプロイ(cog)の実装例を掲載。AI大学プロバイダー数 23社→24社。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
