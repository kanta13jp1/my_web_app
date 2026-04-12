-- Reka AI コンテンツシード
-- AI大学: Reka プロバイダーの初期コンテンツ (overview / models / api)
-- 追加理由: Reka Coreはマルチモーダル特化・動画理解対応の先駆け / Flash/EdgeでオンデバイスAI展開 / 欧米スタートアップとして急成長中

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('reka', 'overview', 'Reka AI 概要',
$$Reka は2022年創業のAIスタートアップ。DeepMind・Google Brain・Meta AI などのトップ研究者が設立し、**マルチモーダルAI**を中心に独自の大規模モデルを開発しています。テキスト・画像・動画・音声を統合的に処理できる点が大きな差別化要因です。

## 特徴

- **Reka Core**: 最大・最高精度のフラッグシップモデル。動画・画像・テキストを横断した長文推論が可能
- **Reka Flash**: バランス型モデル。高速かつコスト効率に優れ、本番ワークロードに最適
- **Reka Edge**: 軽量モデル。オンデバイス・エッジデプロイ向けに最適化
- **動画理解**: 動画ファイルを直接入力できる数少ないモデル。映像の内容を理解・要約・質問応答が可能

## 強み

| 領域 | 内容 |
| :--- | :--- |
| **マルチモーダル** | テキスト・画像・動画・音声を統一モデルで処理 |
| **動画理解** | 動画ファイルを直接入力して内容分析・要約 |
| **エッジAI** | Reka Edge で軽量デプロイ対応 |
| **研究品質** | DeepMind/Google Brain 出身チームによる高品質推論 |
| **多言語対応** | 日本語を含む多言語に対応 |

## 主要ユーザー

企業向けマルチモーダルAI統合・動画コンテンツ分析・カスタマーサポートの自動化などに採用されています。$$,
'https://www.reka.ai/', '2026-04-12', 1),

('reka', 'models', 'Reka AI — 利用可能モデル (2026)',
$$Reka は用途別に3系統のモデルを提供しています。全モデルがマルチモーダル対応です。

## モデル一覧

| モデル | コンテキスト | 入力モダリティ | 特徴 |
| :--- | :--- | :--- | :--- |
| **reka-core** | 128K | テキスト・画像・動画・音声 | 最大・最高精度。複雑な推論・動画理解 |
| **reka-flash** | 128K | テキスト・画像・動画 | バランス型。本番ワークロード向け |
| **reka-edge** | 32K | テキスト・画像 | 軽量・高速。エッジデプロイ向け |

## 対応入力形式

| モダリティ | 対応フォーマット |
| :--- | :--- |
| **テキスト** | 自然言語・コード・JSON・Markdown |
| **画像** | JPEG・PNG・WebP・GIF |
| **動画** | MP4・AVI・MOV (最大数分) |
| **音声** | WAV・MP3・M4A |

## Reka Core の動画理解例

```python
import reka

client = reka.Client(api_key="<REKA_API_KEY>")

# 動画ファイルを直接アップロードして分析
with open("product_demo.mp4", "rb") as video_file:
    response = client.chat.create(
        model="reka-core",
        messages=[{
            "role": "user",
            "content": [
                {
                    "type": "video_url",
                    "video_url": {"url": "data:video/mp4;base64,..."}  # base64エンコード
                },
                {
                    "type": "text",
                    "text": "この動画の内容を日本語で要約してください。主要なポイントを箇条書きにしてください。"
                }
            ]
        }]
    )

print(response.responses[0].message.content)
```

## ベンチマーク (参考)

Reka Core は GPT-4V・Gemini Ultra と同水準のマルチモーダルベンチマーク結果を達成。
特に動画理解 (Video-MME) では競合を上回るスコアを記録しています。$$,
'https://docs.reka.ai/models', '2026-04-12', 2),

('reka', 'api', 'Reka AI API 入門',
$$## セットアップ

Reka API は OpenAI SDK と互換性があるため、最小限の変更で利用できます。

```bash
pip install reka-api
# または OpenAI SDK 経由
pip install openai
```

## Python (reka-api SDK)

```python
import reka

client = reka.Client(api_key="<REKA_API_KEY>")

# テキスト生成
response = client.chat.create(
    model="reka-flash",
    messages=[
        {
            "role": "user",
            "content": "Reka Flash と Reka Core の違いを教えてください。"
        }
    ]
)
print(response.responses[0].message.content)
```

## OpenAI 互換 API (既存コードをそのまま使用)

```python
from openai import OpenAI

# Reka の OpenAI互換エンドポイントを使用
client = OpenAI(
    api_key="<REKA_API_KEY>",
    base_url="https://api.reka.ai/v1"
)

response = client.chat.completions.create(
    model="reka-flash",
    messages=[
        {"role": "user", "content": "日本語で自己紹介してください。"}
    ]
)
print(response.choices[0].message.content)
```

## 画像入力 (OpenAI 互換形式)

```python
from openai import OpenAI
import base64

client = OpenAI(api_key="<REKA_API_KEY>", base_url="https://api.reka.ai/v1")

# 画像を base64 エンコード
with open("chart.png", "rb") as f:
    image_data = base64.b64encode(f.read()).decode("utf-8")

response = client.chat.completions.create(
    model="reka-core",
    messages=[{
        "role": "user",
        "content": [
            {
                "type": "image_url",
                "image_url": {"url": f"data:image/png;base64,{image_data}"}
            },
            {
                "type": "text",
                "text": "このグラフから読み取れる主要なトレンドを日本語で説明してください。"
            }
        ]
    }]
)
print(response.choices[0].message.content)
```

## ストリーミング

```python
import reka

client = reka.Client(api_key="<REKA_API_KEY>")

# ストリーミング出力
for chunk in client.chat.create_stream(
    model="reka-flash",
    messages=[{"role": "user", "content": "日本のAI産業の現状と将来展望を詳しく教えてください。"}]
):
    print(chunk.responses[0].chunk.content, end="", flush=True)
```

## 料金 (2026年4月時点, USD)

| モデル | 入力 (1M tokens) | 出力 (1M tokens) | 画像 (1枚) |
| :--- | :--- | :--- | :--- |
| **Reka Core** | $10.00 | $25.00 | $0.001 |
| **Reka Flash** | $0.80 | $2.00 | $0.0001 |
| **Reka Edge** | $0.40 | $1.00 | $0.00005 |

- **動画入力**: 1秒あたり約 $0.01 (Core) / $0.001 (Flash)
- **無料トライアル**: API申請時に一定クレジットが付与$$,
'https://docs.reka.ai/quick-start', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 Reka AI 追加 (20社目)',
  'Reka AI を AI大学プロバイダーとして追加。overview/models/api の3カテゴリ、動画理解対応マルチモーダルモデル (Core/Flash/Edge)、OpenAI互換API、動画・画像入力サンプルを収録。AI大学プロバイダー数 19社→20社。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
