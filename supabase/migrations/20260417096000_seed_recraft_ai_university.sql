-- Recraft AI 初期コンテンツシード (2026-04-17)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('recraft', 'overview', 'Recraft AI 概要',
$$Recraft AI はロンドン発の画像・ベクター生成に特化した生成AIスタートアップ。2022年創業、2026年2月リリースの **Recraft V4** は「世界唯一のプロダクショングレードベクター生成」を実現し、Midjourney・DALL·E を画像生成ベンチマークで抜いたと評される。

デザイナー・マーケター・EC 事業者向けに「ブランドスタイルを学習したうえで一貫性のあるクリエイティブを量産できる」点が最大の差別化。テキスト表現 (Accurate Text Rendering) とプロンプト追従性が特に強く、印刷レベルの高精細出力 (Recraft V4 Pro = 4MP) にも対応する。

## 主要サービス
- **Recraft Studio**: Web ベースの AI デザインツール (Free プランあり)
- **Recraft API**: 画像・ベクター生成・アップスケール・編集を REST で呼び出せる公開 API
- **Brand Style**: 自社ブランドの色・トーンを学習して一貫した生成を維持
- **Design Library**: 商用利用可のアイコン・イラストレーションライブラリ

## 強み
- 世界唯一レベルの **SVG ベクター生成** (編集可能なパス出力)
- 高精度な画像内テキスト描画 (フォント指定・多言語対応)
- Free プランから API アクセス可能 (従量課金)
- ベクター・ラスター・アップスケーラーを同一 API で完結$$,
'https://www.recraft.ai/', '2026-04-17', 1),

('recraft', 'models', 'Recraft AI モデル一覧 (2026)',
$$## Recraft V4 シリーズ (2026年2月リリース)

| モデル | 解像度 | 特徴 | 用途 |
| :--- | :--- | :--- | :--- |
| **V4 (Standard)** | 1MP | 高速・日常利用 | SNS・ブログ画像・モックアップ |
| **V4 Pro** | 4MP | 印刷品質・高細部 | ポスター・広告・印刷物 |
| **V4 Vector** | SVG | 編集可能ベクター | ロゴ・アイコン・イラスト |
| **V4 Vector Pro** | SVG (高精度) | プロダクション SVG | ブランドアセット・UI |

## 特徴的な機能
- **Accurate Text Rendering**: 画像内のテキストを指定フォント・言語で正確描画
- **Brand Style Transfer**: アップロードしたブランドガイドラインを学習し一貫生成
- **Infinite Canvas**: 無限拡張可能なワーキングボード
- **Style Generation**: 独自の「Style」を作成して一貫性を担保
- **Image to Vector**: ラスター画像を編集可能な SVG に変換$$,
'https://www.recraft.ai/docs/api-reference/getting-started', '2026-04-17', 2),

('recraft', 'api', 'Recraft AI API 入門',
$$## Recraft API の始め方

```python
import requests

url = "https://external.api.recraft.ai/v1/images/generations"
headers = {
    "Authorization": "Bearer YOUR_API_KEY",
    "Content-Type": "application/json"
}
payload = {
    "prompt": "A minimal logo of a flying bird, flat vector style",
    "style": "vector_illustration",
    "model": "recraftv4",
    "size": "1024x1024"
}

response = requests.post(url, headers=headers, json=payload)
print(response.json())
# => { "data": [{ "url": "https://...", "image_id": "..." }] }
```

## 料金 (2026年4月時点)
- **Free プラン**: 50 クレジット/日 (API テスト可能)
- **Basic**: $12/月 — 100 クレジット/日
- **Pro**: $33/月 — 300 クレジット/日 + API 優先
- **従量課金 API**: $0.04〜/画像 (ベクター $0.08/画像)

## 主要エンドポイント
- `POST /v1/images/generations` — 画像・ベクター生成
- `POST /v1/images/vectorize` — ラスター→SVG 変換
- `POST /v1/images/imageToImage` — 画像→画像変換 (style reference)
- `POST /v1/images/inpaint` — 部分編集 (mask ベース)
- `POST /v1/styles` — カスタムスタイル作成

## 認証
API Key は Recraft Studio の Settings → API から発行。HTTP ヘッダー `Authorization: Bearer <KEY>` に含めて呼び出す。$$,
'https://www.recraft.ai/docs/api-reference/getting-started', '2026-04-17', 3)

ON CONFLICT DO NOTHING;
