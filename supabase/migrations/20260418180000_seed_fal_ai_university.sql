-- fal.ai 初期コンテンツシード (2026-04-18)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('fal_ai', 'overview', 'fal.ai 概要',
$$**fal.ai** は米国発の **生成メディア統合 API プラットフォーム**。1,000+ 種類のオープン/プロプライエタリな画像・動画・音声・3D モデルを 1 つの API キーで呼び出せる。

開発者・スタートアップが個別の GPU を管理せずに最先端モデルにアクセスできるよう、低遅延 GPU 推論クラウドを提供する。Seedance 2.0、Nano Banana、FLUX 等のフロンティアモデルがホストされている。

## 主要サービス
- 統一 API: 1,000+ モデル (Image / Video / Audio / Music / 3D / Real-time streaming)
- Marketplace: モデル選択・価格表・利用統計を Web UI で確認
- Fine-tuning: LoRA 等のカスタムモデル訓練・即時デプロイ
- AI SDK / Cloudflare AI Gateway 統合

## 強み
- **低遅延** — 専用最適化エンジンで他社比 4倍高速
- **モダリティ統合** — 画像/動画/音声/3D を 1 アカウントで
- **Pay-per-use** — GPU 借りずトークン/秒課金$$,
'https://fal.ai/', '2026-04-18', 1),

('fal_ai', 'models', 'fal.ai 主要モデル (2026)',
$$## フロンティア生成モデル

| モデル | モダリティ | 特徴 | 用途 |
| :--- | :--- | :--- | :--- |
| **Seedance 2.0** | 動画生成 | 1080p 高品質・物理シミュ向上 | 広告/ショート動画 |
| **FLUX.1** | 画像生成 | Black Forest Labs SOTA | プロダクト画像/アート |
| **Nano Banana** | 画像生成 | Google Gemini 2.5 Flash Image | 高速イラスト |
| **SVD / SVD-XT** | 動画生成 | Stable Video Diffusion | 短尺アニメーション |
| **Stable Audio** | 音楽生成 | テキスト → 楽曲 | BGM/SE |
| **InstantID** | 画像生成 | 顔保持型カスタマイズ | アバター |
| **TripoSR** | 3D生成 | 単一画像 → 3Dメッシュ | ゲーム/AR |

## 特徴的な機能
- リアルタイムストリーミング (フレーム単位逐次返却)
- LoRA 即時デプロイ (HuggingFace から数分)
- WebSocket / REST 両対応$$,
'https://fal.ai/models', '2026-04-18', 2),

('fal_ai', 'api', 'fal.ai API 入門',
$$## fal.ai API の始め方

```python
import fal_client

# API key を環境変数 FAL_KEY に設定
result = fal_client.run(
    "fal-ai/flux/dev",
    arguments={
        "prompt": "a cat astronaut on the moon, photorealistic",
        "image_size": "square_hd"
    }
)
print(result["images"][0]["url"])
```

## 料金 (2026年4月時点)
- **FLUX.1 [dev]**: $0.025 / 画像
- **Seedance 2.0**: $0.10 / 秒 (動画)
- **Stable Audio**: $0.04 / 秒 (音楽)
- **TripoSR**: $0.05 / メッシュ
- 無料枠: $0.10 のクレジット (登録時)

詳細料金は https://fal.ai/pricing 参照$$,
'https://fal.ai/docs/documentation', '2026-04-18', 3)

ON CONFLICT DO NOTHING;
