-- Lightricks 初期コンテンツシード (2026-04-17)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('lightricks', 'overview', 'Lightricks 概要',
$$Lightricks は 2013 年にイスラエル・エルサレムで設立されたクリエイティブ AI 企業で、モバイル写真編集アプリ **Facetune** / **Photoleap** / **Videoleap** で世界 1 億ダウンロードを達成した実績を持つ。2023 年以降は生成 AI ビデオ分野に本格参入し、自社モデル **LTXV** ・ **LTX-2** を開発している。

2026 年 1 月、**LTX-2** を **4K 解像度 + ネイティブ同期オーディオ** 生成可能なプロダクション級ビデオモデルとして完全オープンソース化 (OpenRAIL-M ライセンス)。22B パラメータで、従来比 **30 倍高速** な推論を民生 GPU で実現した。同時に LTX-2 用セルフサーブ API をローンチし、Fal / Replicate / ComfyUI / OpenArt 経由でも利用可能。

## 主要サービス

- **LTX-2 API** — テキスト→動画 / 画像→動画 / 動画拡張を単一エンドポイントで提供
- **LTX Studio** — Web ベースの AI 映像制作プラットフォーム (絵コンテから本編まで)
- **LTX-2 OSS** — GitHub / HuggingFace で全ウェイト公開 (22B MoE)
- **Facetune / Videoleap / Photoleap** — モバイル写真・動画編集アプリ

## 強み

- 業界唯一: **音声 + 映像を同時ネイティブ生成**する OSS モデル
- **4K 解像度** で 10 秒以上の長尺動画を生成可能
- 民生 GPU (RTX 4090 等) で動作 — AWS/GCP 不要
- Apache 2.0 相当の寛容ライセンス (ARR $10M 未満の企業は商用無料)
- Fal / Replicate / ComfyUI など主要インフラと統合済み$$,
'https://www.lightricks.com/', '2026-04-17', 1),

('lightricks', 'models', 'Lightricks モデル一覧 (2026)',
$$## LTX ビデオ生成モデル系列

| モデル | パラメータ | 解像度 | 特徴 | 用途 |
| :--- | :--- | :--- | :--- | :--- |
| **LTX-2 (Pro)** | 22B | 4K | 音声+映像同期生成 | プロダクション映像 |
| **LTX-2 (Fast)** | 22B | 1080p | 30倍高速推論 | プロトタイピング |
| **LTX-2.3** | 22B | 4K | 長尺対応 (60s+) | 長編コンテンツ |
| **LTXV** | 11B | 1080p | 初代オープンソース版 | ComfyUI ワークフロー |

## 特徴的な機能

- **同期オーディオ生成**: 映像と一体でダイアログ・BGM・環境音を生成
- **60秒超の長尺生成**: 一貫性を保ったまま 1 分以上の動画を生成可能
- **画像→動画変換**: 既存画像をシームレスにアニメーション化
- **ComfyUI ノード公式対応**: ノードベース AI パイプラインと統合
- **LoRA ファインチューニング**: 公式トレーナー同梱で独自スタイル作成可能
- **オープンウェイト**: HuggingFace で全モデル公開 (`Lightricks/LTX-2`)$$,
'https://ltx.io/model/ltx-2', '2026-04-17', 2),

('lightricks', 'api', 'Lightricks API 入門',
$$## LTX-2 API の始め方

```python
# LTX-2 API (REST) — テキスト→動画生成
import requests

response = requests.post(
    "https://api.ltx.video/v1/generations",
    headers={
        "Authorization": "Bearer YOUR_LTX_API_KEY",
        "Content-Type": "application/json",
    },
    json={
        "model": "ltx-2-pro",
        "prompt": "晴れた海辺を歩く犬。波の音と海鳥の鳴き声。",
        "resolution": "4K",
        "duration_seconds": 10,
        "audio": True,
    },
)

result = response.json()
print(result["video_url"])  # 生成された動画の URL
print(result["audio_url"])  # 同期オーディオトラック
```

## 料金 (2026年4月時点・compute-second 課金)

- **Free Tier**: 800 クレジット (初回のみ・一度きり)
- **Lite**: $10/月・8,000 クレジット (1080p 相当)
- **Standard**: $30/月・28,000 クレジット
- **Pro**: $100/月・110,000 クレジット (4K + 音声)
- **Enterprise**: Contact Sales (無制限クレジット・SLA 保証)
- **Fal / Replicate 経由**: 秒単位従量課金 (詳細は各プラットフォーム参照)

## 参考リンク

- 公式サイト: <https://www.lightricks.com/>
- LTX-2 モデル: <https://ltx.io/model/ltx-2>
- API ドキュメント: <https://docs.ltx.video/welcome>
- 料金ページ: <https://ltx.io/model/api/pricing>
- OSS リポジトリ: <https://github.com/Lightricks/LTX-2>
- HuggingFace: <https://huggingface.co/Lightricks/LTX-2>$$,
'https://docs.ltx.video/welcome', '2026-04-17', 3)

ON CONFLICT DO NOTHING;
