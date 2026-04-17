-- Moondream 初期コンテンツシード (2026-04-18)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('moondream', 'overview', 'Moondream 概要',
$$Moondream は **小型・高性能な Vision-Language Model (VLM) 専業**のスタートアップ。創業者 Vik Korrapati が個人プロジェクトとして始め、1.8B パラメータの `moondream2` を GitHub / HuggingFace で公開 (累計数百万ダウンロード) して一躍注目を集めた。

2025 年 10 月、**Moondream 3 Preview (9B 総パラメータ・2B アクティブの MoE VLM)** を発表。物体検出の高精度バウンディングボックス・OCR・画像推論を、**Gemini 2.5 Flash / GPT-4o Mini と同等の料金** で提供する。Moondream Cloud (自社ホスティング) と OSS (Apache 2.0) の両方を選べる。

## 主要サービス

- **Moondream 3 Preview** — 最新 MoE VLM (9B 総 / 2B active)
- **Moondream 2** — 1.8B 軽量版 (OSS / ローカル実行向け)
- **Moondream Cloud** — pay-as-you-go ホスティング API
- **Detect エンドポイント** — 精密バウンディングボックスで物体検出
- **Fal / WaveSpeedAI 連携** — 他インフラ経由でも利用可

## 強み

- **Frontier-level 視覚推論** を 9B サイズで実現 (blazing fast)
- **Apache 2.0 OSS**: ローカル / エッジ / 組込みで自由に利用可能
- **物体検出精度**: precise bounding boxes (商用利用可)
- **価格**: Gemini 2.5 Flash / GPT-4o Mini と同水準で VLM 特化
- **OCR + 画像質問応答** をシンプル API で提供$$,
'https://moondream.ai/', '2026-04-18', 1),

('moondream', 'models', 'Moondream モデル一覧 (2026)',
$$## Moondream VLM 系列

| モデル | パラメータ | 特徴 | 用途 |
| :--- | :--- | :--- | :--- |
| **Moondream 3 Preview** | 9B (2B active MoE) | フロンティア級視覚推論 | 画像質問応答・OCR・複雑推論 |
| **Moondream 2** | 1.8B | 軽量 OSS / ローカル実行可 | エッジデバイス・組込み |
| **Moondream 3 Detect** | 9B | バウンディングボックス特化 | 物体検出・画像アノテーション |

## 特徴的な機能

- **画像質問応答 (VQA)**: 日本語プロンプト対応
- **OCR**: 手書き・印刷・多言語テキスト抽出
- **物体検出**: 精密なバウンディングボックス出力
- **画像キャプショニング**: 自動タイトル・説明文生成
- **Apache 2.0 OSS**: GitHub / HuggingFace で全ウェイト公開
- **エッジ最適化**: moondream2 は Raspberry Pi でも動作

## トークン体系

- **画像**: 1枚 = 729 tokens (固定)
- **テキスト**: superword tokenizer (効率的)
- 長い画像は自動分割でトークン数を最小化$$,
'https://moondream.ai/blog/moondream-3-preview', '2026-04-18', 2),

('moondream', 'api', 'Moondream API 入門',
$$## Moondream Cloud API の始め方

```python
# Moondream Cloud (REST) — 画像質問応答
import moondream as md
from PIL import Image

model = md.vl(api_key="YOUR_MOONDREAM_API_KEY")

image = Image.open("photo.jpg")

# 1. 画像質問応答 (VQA)
answer = model.query(image, "この画像には何人いますか?")["answer"]
print(answer)  # "3人います。"

# 2. 画像キャプション生成
caption = model.caption(image)["caption"]
print(caption)  # "公園で遊ぶ家族の写真。"

# 3. 物体検出 (bounding boxes)
detection = model.detect(image, "people")
for box in detection["objects"]:
    print(box)  # {"x_min": 0.1, "y_min": 0.2, "x_max": 0.4, "y_max": 0.8}
```

## 料金 (2026年4月時点)

- **Moondream 3 Preview**: $0.30 / 1M input · $2.50 / 1M output
- **画像**: 1枚 = 729 tokens 固定
- **Free Tier**: 月間 $5 クレジット (約 20,000 画像分)
- **Pay-as-you-go**: 使った分だけ課金・サブスク不要
- **OSS ローカル**: Apache 2.0 で完全無料 (自己ホスト)

## 参考リンク

- 公式サイト: <https://moondream.ai/>
- ドキュメント: <https://docs.moondream.ai/>
- 料金ページ: <https://moondream.ai/pricing>
- GitHub: <https://github.com/vikhyat/moondream>
- HuggingFace: <https://huggingface.co/moondream/moondream3-preview>
- Fal 連携: <https://fal.ai/models/fal-ai/moondream3-preview/query/api>$$,
'https://docs.moondream.ai/', '2026-04-18', 3)

ON CONFLICT DO NOTHING;
