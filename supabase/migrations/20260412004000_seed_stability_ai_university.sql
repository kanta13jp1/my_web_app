-- Stability AI コンテンツシード
-- AI大学: Stability AI プロバイダーの初期コンテンツ (overview / models / api)
-- 追加理由: Stable Diffusion 開発元 / 画像・動画・音楽生成 API 公開済み / 日本で高知名度 / テキスト系と差別化

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('stability', 'overview', 'Stability AI 概要',
$$Stability AI は2020年にロンドンで創業された画像生成 AI のパイオニア企業です。**Stable Diffusion** の開発元として世界的に知られており、テキストから高品質な画像・動画・3D・音楽を生成するオープンな AI モデルを提供しています。

Stable Diffusion はオープンソースとして公開されたため、世界中の開発者・クリエイターが自由に活用・カスタマイズできます。日本でもイラスト生成・ゲーム開発・広告制作など幅広い分野で普及しており、AI 生成クリエイティブ市場をリードしてきました。

## 主要サービス
- **Stable Diffusion** — テキスト→画像生成のデファクトスタンダード (OSS)
- **Stability AI API** — クラウド上でモデルを API 経由で利用するプラットフォーム
- **Stable Video Diffusion** — テキスト・画像→動画生成
- **Stable Audio** — テキスト→音楽・効果音生成
- **Stable 3D** — テキスト・画像→3Dモデル生成

## 強み
- Stable Diffusion は OSS で商用利用可能 (一部ライセンス条件あり)
- テキスト・画像・動画・音楽・3D と**最も幅広いモダリティ**をカバー
- ローカル実行対応 — VRAM 8GB 以上の GPU があれば自前で動かせる
- ComfyUI / Automatic1111 などエコシステムが巨大 — カスタマイズ性が最高
- 日本語プロンプトでも高品質な日本風イラストを生成可能$$,
'https://stability.ai/', '2026-04-12', 1),

('stability', 'models', 'Stability AI モデル一覧 (2026)',
$$## 画像生成モデル

| モデル | 解像度 | 特徴 | 用途 |
| :--- | :--- | :--- | :--- |
| **Stable Diffusion 3.5 Large** | 最大2MP | 最高品質・多様なスタイル | プロ向け高品質生成 |
| **Stable Diffusion 3.5 Medium** | 最大2MP | バランス型・高速 | 汎用・コスト効率 |
| **SDXL 1.0** | 1024×1024 | 安定した高品質・広大なエコシステム | 定番・ファインチューン多数 |
| **Stable Diffusion 2.1** | 768×768 | 軽量・高速 | 低スペック環境 |
| **Stable Cascade** | 最大2MP | 4段階階層生成・高精度 | 研究・高品質 |

## 動画・音楽・3D モデル

| モデル | 特徴 | 用途 |
| :--- | :--- | :--- |
| **Stable Video Diffusion (SVD)** | 画像→高品質動画 (25フレーム) | 短尺動画・アニメーション |
| **Stable Audio 2.0** | テキスト→最大3分の音楽/効果音 | BGM・SE 自動生成 |
| **Stable 3D** | 画像→GLBモデル生成 | ゲーム素材・3D プロトタイプ |

## 特化機能
- **ControlNet** — 骨格・輪郭・深度マップで画像構図を精密制御
- **LoRA / DreamBooth** — 少数画像で特定スタイル・キャラクターを学習
- **img2img** — 既存画像をベースにテキスト指示で変換
- **Inpainting / Outpainting** — 画像の一部修正・枠外拡張$$,
'https://stability.ai/stable-image', '2026-04-12', 2),

('stability', 'api', 'Stability AI API 入門',
$$## Stability AI API の始め方

[Stability AI Platform](https://platform.stability.ai/) でAPIキーを取得後、REST API で利用できます。

```python
import requests
import base64

api_key = "your-stability-api-key"

# Stable Diffusion 3.5 でテキスト→画像生成
response = requests.post(
    "https://api.stability.ai/v2beta/stable-image/generate/sd3",
    headers={
        "Authorization": f"Bearer {api_key}",
        "Accept": "application/json"
    },
    files={"none": ""},
    data={
        "prompt": "beautiful Japanese anime girl, cherry blossoms, watercolor style",
        "negative_prompt": "blurry, low quality",
        "model": "sd3.5-large",
        "output_format": "png",
        "width": 1024,
        "height": 1024,
    }
)

# PNG バイナリを保存
result = response.json()
image_data = base64.b64decode(result["image"])
with open("output.png", "wb") as f:
    f.write(image_data)
print("画像を output.png に保存しました")
```

## SDXL API (軽量・高速)

```python
import requests, base64

response = requests.post(
    "https://api.stability.ai/v1/generation/stable-diffusion-xl-1024-v1-0/text-to-image",
    headers={
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    },
    json={
        "text_prompts": [
            {"text": "futuristic cityscape, neon lights, cyberpunk", "weight": 1},
            {"text": "blurry, low quality, watermark", "weight": -1}
        ],
        "cfg_scale": 7,
        "height": 1024,
        "width": 1024,
        "samples": 1,
        "steps": 30,
    }
)

data = response.json()
image_bytes = base64.b64decode(data["artifacts"][0]["base64"])
with open("sdxl_output.png", "wb") as f:
    f.write(image_bytes)
```

## ローカル実行 (diffusers)

```python
from diffusers import StableDiffusion3Pipeline
import torch

# GPU (VRAM 8GB+) で実行
pipe = StableDiffusion3Pipeline.from_pretrained(
    "stabilityai/stable-diffusion-3.5-medium",
    torch_dtype=torch.float16
)
pipe = pipe.to("cuda")

image = pipe(
    prompt="a majestic dragon over Mount Fuji, digital painting",
    negative_prompt="blurry, low quality",
    num_inference_steps=28,
    guidance_scale=3.5,
).images[0]

image.save("local_output.png")
```

## 料金 (2026年4月時点)

| モデル | 価格 |
| :--- | :--- |
| **SD 3.5 Large** | $0.065 / 画像 |
| **SD 3.5 Medium** | $0.035 / 画像 |
| **SDXL** | $0.002〜$0.01 / 画像 |
| **Stable Audio 2.0** | $0.005 / 秒 |
| **Stable Video Diffusion** | $0.20 / 動画 |

- **無料クレジット**: 新規アカウントに $25 相当の無料クレジット付与
- SDK: `pip install stability-sdk` / REST API は curl や requests で利用可能
- ローカル実行は完全無料 (ハードウェアコストのみ)$$,
'https://platform.stability.ai/docs/api-reference', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 Stability AI 追加 (13社目)',
  'Stability AI (Stable Diffusion 開発元) を AI大学プロバイダーとして追加。overview/models/api の3カテゴリ、日本語コンテンツ、SD3.5/SDXL/SVD/Stable Audio モデル一覧・API実装例・ローカル実行手順を収録。AI大学プロバイダー数 12社→13社。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
