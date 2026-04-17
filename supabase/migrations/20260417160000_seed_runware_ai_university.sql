-- Runware 初期コンテンツシード (2026-04-17)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('runware', 'overview', 'Runware 概要',
$$Runware は **「One API for all AI」** を掲げる AI 推論プラットフォーム。2025年12月に Dawn Capital・Comcast Ventures・Speedinvest から **$50M の Series A** を調達し、画像・動画・音声・テキスト・3D を単一 API で扱える統合基盤として急成長している。

中核技術 **Sonic Inference Engine®** は独自のハードウェア最適化と推論スケジューリングにより、オープンソースモデルで既存比 30〜40% 高速・5〜10倍低コストを実現。2026年末までに **200万以上の Hugging Face モデル** をデプロイ予定。

## 主要サービス
- **Image Inference API**: text-to-image / image-to-image / inpainting / outpainting
- **Video Inference API**: text-to-video / image-to-video / video-to-video
- **Audio Inference**: 音声生成
- **Model Upload API**: カスタムモデルをアップロードして推論可能
- **Sonic Inference Engine**: 400,000+ モデル対応の超高速推論エンジン

## 強み
- 単一エンドポイントで画像・動画・音声・テキスト・3D を統合
- 従量課金のみ (画像 $0.0006〜・動画 $0.14〜)・サブスク不要
- Kling / Veo / Hailuo / Seedance / PixVerse / Vidu / DALL-E 等主要モデル網羅
- バッチ処理コスト重視アプリ向けに最適化$$,
'https://runware.ai/', '2026-04-17', 1),

('runware', 'models', 'Runware 対応モデル一覧 (2026)',
$$Runware は画像・動画・音声領域の主要モデルを統合した「ハブ型」API。

## 画像生成モデル

| モデル | 提供元 | 特徴 | 用途 |
| :--- | :--- | :--- | :--- |
| **FLUX.1** | Black Forest Labs | 高品質生成・商用可 | プロダクション画像 |
| **DALL-E 3** | OpenAI | プロンプト忠実度高 | コンセプトアート |
| **Stable Diffusion XL** | Stability AI | カスタマイズ豊富 | LoRA活用 |
| **Ideogram** | Ideogram | テキスト表現強い | バナー・ロゴ |

## 動画生成モデル

| モデル | 提供元 | 特徴 | 用途 |
| :--- | :--- | :--- | :--- |
| **Kling AI** | Kuaishou | 高品質 T2V | シネマティック |
| **Google Veo** | Google | 最大8K出力 | プロ映像制作 |
| **MiniMax Hailuo** | MiniMax | 物理整合性強い | アクション |
| **Seedance** | ByteDance | キャラ一貫性 | 短尺動画 |
| **PixVerse** | PixVerse | エフェクト豊富 | ソーシャル |
| **Vidu** | ShengShu | 高速生成 | プロトタイプ |

## 特徴的な機能
- Sonic Inference Engine による秒単位の高速推論
- 400,000+ モデル対応 (2026年末 200万+ 予定)
- 画像アップスケール / 背景除去 / キャプション生成も統合
- カスタムモデルアップロードで独自モデルも同一 API で推論$$,
'https://runware.ai/docs/index', '2026-04-17', 2),

('runware', 'api', 'Runware API 入門',
$$## Runware API の始め方

Runware は画像・動画・音声をすべて **単一エンドポイント** で扱える統一 API。Python / JavaScript SDK 提供。

```python
# pip install runware
from runware import Runware, IImageInference

runware = Runware(api_key="YOUR_API_KEY")
await runware.connect()

request = IImageInference(
    positivePrompt="cyberpunk tokyo night street, neon lights",
    model="runware:100@1",  # FLUX.1 dev
    numberResults=1,
    height=1024,
    width=1024,
)

images = await runware.imageInference(requestImage=request)
for image in images:
    print(image.imageURL)
```

動画生成も同じ API 形式で呼び出せる:

```python
from runware import IVideoInference

video = IVideoInference(
    positivePrompt="a cat running on the beach",
    model="kling:v2.1@1",
    duration=5,
)
result = await runware.videoInference(requestVideo=video)
```

## 料金 (2026年4月時点・pay-per-use)
- **画像生成**: $0.0006〜 / 枚 (モデルにより変動)
- **動画生成**: $0.14〜 / 動画 (解像度・長さで変動)
- **既存大手比**: 画像 62% 安・オープンソースモデルで 5〜10倍コスト削減
- サブスク・最低料金なし

## 主要リンク
- 公式: https://runware.ai/
- API リファレンス: https://runware.ai/docs/index
- Python SDK: https://github.com/Runware/sdk-python$$,
'https://runware.ai/docs/index', '2026-04-17', 3)

ON CONFLICT DO NOTHING;
