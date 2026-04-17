-- Krea AI 初期コンテンツシード (2026-04-17)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('krea', 'overview', 'Krea AI 概要',
$$Krea AI は「リアルタイム画像・動画生成」に特化した AI クリエイティブスイート。2023年サンフランシスコで創業し、マウス操作や描画に応じて画像が 50ms 以下で生成される高速モデルを武器にクリエイターの主流ツールへ急成長した。

2026年1月には 14B パラメータの **Krea Realtime 14B** をオープンソース公開し、長時間のリアルタイム動画生成を実現。40以上のサードパーティ生成モデル (Flux / Stable Diffusion / Kling / Wan 2.1 等) を単一 API から呼び出せる **集約プラットフォーム** でもあり、モデル選定の手間を省ける点が開発者に支持されている。

## 主要サービス
- **Krea Realtime**: マウス・キーボード・Web カメラ入力に即応する画像生成 Web アプリ
- **Krea Video**: テキスト/画像から動画生成 (14B オープンソースモデル込み)
- **Krea API**: 画像・動画・アップスケール・40+モデルを単一 API 経由で呼び出し
- **Node Editor**: ノーコードで生成モデルを連結できるチェーン構築機能

## 強み
- 50ms 以下の **リアルタイム生成** (他社にない応答速度)
- **40+ モデル集約** で評価コストを削減 (Flux/Kling/Wan/SD3 等)
- **従量課金 (compute unit)** — 失敗ジョブ課金なし
- **オープンソース 14B 動画モデル** (自社ホスト可能)$$,
'https://www.krea.ai/', '2026-04-17', 1),

('krea', 'models', 'Krea AI モデル一覧 (2026)',
$$## Krea 独自モデル

| モデル | タイプ | 特徴 | 用途 |
| :--- | :--- | :--- | :--- |
| **Krea Realtime** | 画像 (50ms) | リアルタイム生成 | ライブペイント・UI プロトタイピング |
| **Krea Realtime 14B** | 動画 (オープンソース) | 長時間リアルタイム動画 | 動画ストリーミング・配信 |
| **Krea Enhancer** | アップスケール | 高倍率アップスケール | 印刷・ポスター制作 |

## 集約モデル (40+ 選択可能)

| カテゴリ | 代表モデル |
| :--- | :--- |
| 画像生成 | **Flux 1.1 Pro**, Stable Diffusion 3, Recraft V4, Midjourney 互換 |
| 動画生成 | **Kling 2.0**, Wan 2.1, Runway Gen-4, Minimax Hailuo |
| 画像編集 | Flux Fill, SD Inpaint, Adobe Firefly (一部) |
| アップスケール | Krea Enhancer, Topaz Photo, SUPIR |
| 3D | Tripo 3D, Meshy |

## 特徴的な機能
- **Realtime Canvas**: 描画中に AI が即生成 (Web カメラ入力も対応)
- **Node Editor**: 画像→動画→アップスケールの連鎖を GUI で構築
- **Batch Processing**: 分岐ロジック付きバッチジョブ
- **Model Routing**: プロンプトに応じて自動で最適モデル選択$$,
'https://www.krea.ai/app', '2026-04-17', 2),

('krea', 'api', 'Krea AI API 入門',
$$## Krea API の始め方

```python
import requests

url = "https://api.krea.ai/v1/generations"
headers = {
    "Authorization": "Bearer YOUR_API_KEY",
    "Content-Type": "application/json"
}
payload = {
    "model": "flux-1.1-pro",
    "prompt": "A cinematic photograph of a cyberpunk city at night",
    "aspect_ratio": "16:9",
    "num_images": 1
}

response = requests.post(url, headers=headers, json=payload)
print(response.json())
# => { "data": [{ "url": "https://...", "cost_units": 8 }] }
```

## 料金 (2026年4月時点)
- **Free プラン**: 毎日リセットされるクレジット
- **Basic**: $10/月 — 600 compute units/月
- **Pro**: $35/月 — 3,000 compute units/月 + 商用利用
- **API 従量**: 1 compute unit = $0.01〜 (モデルごとに消費量が異なる)

## 主要エンドポイント
- `POST /v1/generations` — 画像・動画生成 (model パラメータでモデル選択)
- `POST /v1/enhance` — アップスケール
- `POST /v1/chain` — Node Editor で構築したチェーンを実行
- `GET /v1/models` — 利用可能モデル一覧取得
- `GET /v1/jobs/{id}` — ジョブステータス確認

## 認証
Krea Studio の Settings → API Keys から発行。失敗ジョブは課金されないため、試行錯誤しやすい設計。$$,
'https://www.krea.ai/features/api', '2026-04-17', 3)

ON CONFLICT DO NOTHING;
