-- Black Forest Labs 初期コンテンツシード (2026-04-16)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('black_forest_labs', 'overview', 'Black Forest Labs 概要',
$$## Black Forest Labs とは

Black Forest Labs は2024年に設立されたドイツ発の AI 画像生成スタートアップです。Stability AI の元コアチームが独立して創業し、業界最高水準の画像生成モデル「FLUX」シリーズを開発しています。わずか数ヶ月で開発者コミュニティから絶大な支持を集め、DALL-E 3 や Midjourney に匹敵する（あるいは凌駕する）品質を実現しました。

設立直後に $31M の資金調達に成功し、2026年には API サービスも本格稼働。オープンウェイト版も提供しており、ローカル環境での利用も可能です。

## 主要サービス

- **FLUX.1 [pro]**: 最高品質の商用モデル。API 経由で利用可能
- **FLUX.1 [dev]**: 研究・非商用向けオープンウェイトモデル
- **FLUX.1 [schnell]**: 高速生成向け（Apache 2.0 ライセンス）
- **FLUX.1.1 [pro]**: 2024年10月リリース。従来版より3倍高速

## 強み

- テキスト理解の精度が業界トップクラス（特に多言語・複雑なプロンプト）
- 人物・手・テキスト描画の品質が競合を上回る
- オープンウェイトモデルの提供でローカル実行が可能
- fal.ai / Replicate / ComfyUI など主要プラットフォームで利用可能$$,
'https://blackforestlabs.ai', '2026-04-16', 1),

('black_forest_labs', 'models', 'Black Forest Labs モデル一覧 (2026)',
$$## FLUX.1 シリーズ

| モデル | 解像度 | ライセンス | 特徴 | 用途 |
| :--- | :--- | :--- | :--- | :--- |
| **FLUX.1 [pro]** | 最大2048x2048 | 商用 API | 最高品質・テキスト精度 | 商業デザイン・広告 |
| **FLUX.1.1 [pro]** | 最大2048x2048 | 商用 API | 3倍高速・品質向上 | 本番環境・リアルタイム |
| **FLUX.1 [dev]** | 最大2048x2048 | 非商用 | オープンウェイト | 研究・実験 |
| **FLUX.1 [schnell]** | 最大2048x2048 | Apache 2.0 | 最速生成 (4ステップ) | プロトタイプ・個人利用 |

## 特徴的な機能

- **テキスト埋め込み描画**: プロンプトのテキストをそのまま画像内に正確に描画
- **多言語プロンプト対応**: 日本語・中国語・韓国語などのプロンプトを直接理解
- **ControlNet 対応**: ポーズ・深度・エッジ検出などによる制御が可能
- **LoRA ファインチューニング**: カスタムスタイルの学習・適用が可能
- **インペインティング / アウトペインティング**: 画像の部分編集・拡張$$,
'https://docs.bfl.ml/', '2026-04-16', 2),

('black_forest_labs', 'api', 'Black Forest Labs API 入門',
$$## Black Forest Labs API の始め方

```python
import requests

API_KEY = "your-bfl-api-key"
BASE_URL = "https://api.bfl.ml"

# 画像生成リクエスト
response = requests.post(
    f"{BASE_URL}/v1/flux-pro-1.1",
    headers={"x-key": API_KEY, "Content-Type": "application/json"},
    json={
        "prompt": "A futuristic cityscape at sunset, ultra-realistic",
        "width": 1024,
        "height": 1024,
        "steps": 25,
        "guidance": 3.5,
        "safety_tolerance": 2,
        "output_format": "jpeg"
    }
)
request_id = response.json()["id"]

# 結果を取得
import time
while True:
    result = requests.get(
        f"{BASE_URL}/v1/get_result",
        headers={"x-key": API_KEY},
        params={"id": request_id}
    ).json()
    if result["status"] == "Ready":
        print("画像URL:", result["result"]["sample"])
        break
    time.sleep(1)
```

## 料金 (2026年4月時点)

- **FLUX.1 [pro]**: $0.05 / 枚
- **FLUX.1.1 [pro]**: $0.04 / 枚
- **FLUX.1 [dev]**: $0.025 / 枚（非商用）
- **FLUX.1 [schnell]**: $0.003 / 枚（Apache 2.0）

## 代替アクセス方法

- **fal.ai**: `fal-ai/flux/schnell` などのエンドポイントで利用可能
- **Replicate**: `black-forest-labs/flux-schnell` モデルで利用可能
- **ComfyUI**: ローカル環境での実行（[dev] / [schnell] のみ）$$,
'https://docs.bfl.ml/', '2026-04-16', 3)

ON CONFLICT DO NOTHING;
