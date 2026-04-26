-- PS#3 S60: AI大学 212→213社化 — Adobe Firefly 追加
-- Adobe Firefly: エンタープライズAI画像生成 / Creative Cloud統合 / 商用安全 / Photoshop内生成

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'adobe-firefly',
  'overview',
  'Adobe Firefly — エンタープライズAI画像生成 (Creative Cloud統合 / 商用安全 / Photoshop内生成)',
  $$## Adobe Firefly — エンタープライズAI画像生成

**カテゴリ**: AI Image Generation / Creative Tools / Enterprise AI
**設立**: 2023年3月公開 / 本社: San Jose, CA (Adobe Inc. 製品)
**特徴**: Adobe Creative Cloud に完全統合された商用利用安全な AI 画像生成
**ユーザー**: デザイナー / マーケター / 映像クリエイター / 企業の広告制作チーム
**評価**: 9/9

### 概要
Adobe Firefly は Adobe が開発した **商用利用安全 (Commercially Safe)** な AI 画像生成モデル群。Adobe Stock のライセンス済みコンテンツと著作権が切れた公開ドメイン画像のみで学習しており、生成画像の商用利用において法的リスクがない点が最大の差別化。Photoshop の「生成塗りつぶし」「生成拡張」、Illustrator の「テキストからベクター生成」、Adobe Express のテンプレート生成など、Adobe アプリ全体に統合されている。

### 主な特長
- **商用安全 (Commercially Safe)**: Adobe Stock + 著作権切れコンテンツのみで学習 → 企業広告・製品ロゴに安全利用可
- **Creative Cloud 統合**: Photoshop / Illustrator / Adobe Express / Premiere Pro に内蔵 → 既存ワークフロー変更不要
- **生成塗りつぶし (Generative Fill)**: 選択範囲をプロンプトで置換・拡張 (例: 「背景を東京夜景に変更」)
- **生成拡張 (Generative Expand)**: 画像の外側をプロンプトで自然に拡張 (縦横比変更も可)
- **テキストからベクター生成**: Illustrator でテキストプロンプト → SVG ベクター直接生成
- **コンテンツ認証情報 (C2PA)**: 生成画像に AI 生成メタデータを自動付与 (透明性)
- **スタイルマッチ**: 参照画像のスタイルを学習して一貫したビジュアル生成
- **Firefly API**: 企業向け REST API で大量生成・バッチ処理・DAM 統合が可能

### Creative Cloud 統合ポイント
| アプリ | Firefly 機能 |
|--------|-------------|
| Photoshop | 生成塗りつぶし / 生成拡張 / 背景削除 AI 強化 |
| Illustrator | テキストからベクター / Retype (フォント認識) |
| Adobe Express | AIテンプレート生成 / テキスト効果 / 画像生成 |
| Premiere Pro | 生成B-roll提案 / オブジェクト削除 (Firefly Video) |
| Adobe Stock | AI 生成素材の販売・購入 |

### 競合との差別化
Midjourney: 高品質アート / 商用利用は有料プランで可 / API なし
DALL-E 3: OpenAI 統合 / ChatGPT から利用 / Creative Cloud 統合なし
Stable Diffusion: OSS / カスタマイズ自由 / 商用安全性は自己責任
Adobe Firefly の強みは **既存 Adobe ユーザーがゼロ学習コストで AI を活用 + 企業法務に安全**。

### 導入コスト
- **Adobe Creative Cloud**: 月 6,480円〜 (Firefly 標準搭載)
- **Firefly 生成クレジット**: CC プランに月 25〜1,000 クレジット付属
- **Firefly API (Enterprise)**: 要問い合わせ (大量生成・カスタムモデル・SLA 保証)
- **Adobe Firefly 単体**: 月 680円 (Firefly のみ利用 / Creative Cloud 不要)$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'adobe-firefly',
  'api',
  'Adobe Firefly API — 商用安全AI画像生成 REST API + Creative Cloud 自動化 (Python)',
  $$## Adobe Firefly API

### 事前準備
```bash
# Adobe Developer Console でアプリ作成 → API Key + Client Secret 取得
# https://developer.adobe.com/firefly-api/
pip install requests
```

### アクセストークン取得
```python
import requests

def get_adobe_token(client_id: str, client_secret: str) -> str:
    resp = requests.post(
        "https://ims-na1.adobelogin.com/ims/token/v3",
        data={
            "grant_type": "client_credentials",
            "client_id": client_id,
            "client_secret": client_secret,
            "scope": "openid,AdobeID,firefly_api",
        },
    )
    resp.raise_for_status()
    return resp.json()["access_token"]
```

### テキストから画像生成
```python
def generate_image(prompt: str, client_id: str, token: str) -> list[str]:
    headers = {
        "Authorization": f"Bearer {token}",
        "x-api-key": client_id,
        "Content-Type": "application/json",
    }
    payload = {
        "prompt": prompt,
        "n": 4,                          # 生成枚数 (最大 4)
        "size": {"width": 1344, "height": 768},  # 16:9
        "style": {
            "presets": ["photo"],        # photo / art / graphic / bw など
        },
        "contentClass": "photo",        # photo / art
    }
    resp = requests.post(
        "https://firefly-api.adobe.io/v3/images/generate",
        json=payload,
        headers=headers,
    )
    resp.raise_for_status()
    return [img["url"] for img in resp.json()["outputs"]]

# 使用例
token = get_adobe_token("YOUR_CLIENT_ID", "YOUR_CLIENT_SECRET")
urls = generate_image("東京スカイツリーと桜の夜景、映画的な光", "YOUR_CLIENT_ID", token)
for url in urls:
    print(url)
```

### 生成塗りつぶし (Generative Fill) API
```python
import base64

def generative_fill(image_path: str, mask_path: str, prompt: str, client_id: str, token: str) -> str:
    with open(image_path, "rb") as f:
        image_b64 = base64.b64encode(f.read()).decode()
    with open(mask_path, "rb") as f:
        mask_b64 = base64.b64encode(f.read()).decode()

    headers = {
        "Authorization": f"Bearer {token}",
        "x-api-key": client_id,
        "Content-Type": "application/json",
    }
    payload = {
        "prompt": prompt,
        "image": {"source": {"uploadId": upload_image(image_b64, client_id, token)}},
        "mask": {"source": {"uploadId": upload_image(mask_b64, client_id, token)}},
    }
    resp = requests.post(
        "https://firefly-api.adobe.io/v3/images/fill",
        json=payload,
        headers=headers,
    )
    resp.raise_for_status()
    return resp.json()["outputs"][0]["url"]
```

### バッチ生成 (大量マーケティング素材)
```python
prompts = [
    "プロフェッショナルなビジネスミーティング、明るいオフィス",
    "スタートアップのチームワーク、コラボレーション",
    "AIテクノロジーとデータビジュアライゼーション",
]
results = []
for p in prompts:
    urls = generate_image(p, client_id, token)
    results.append({"prompt": p, "images": urls})
    # レート制限: 1秒間隔推奨
    import time; time.sleep(1)
```

### Content Credentials (C2PA) 確認
```python
# 生成画像には AI 生成メタデータが自動付与
# Adobe Content Authenticity でメタデータ検証可能
verify_url = "https://firefly-api.adobe.io/v3/content-credentials/verify"
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'adobe-firefly',
  'models',
  'Adobe Firefly モデル — Firefly Image 3 + Video + Vector + Design モデル群',
  $$## Adobe Firefly モデル一覧

| モデル | 用途 | 特徴 |
|--------|------|------|
| **Firefly Image 3** | テキスト→画像 / 生成塗りつぶし / 生成拡張 | 現行最高品質 / フォトリアル強化 / スタイル制御 |
| **Firefly Video** (Beta) | テキスト→動画 / 画像→動画 / 生成B-roll | Premiere Pro 統合 / 最大10秒 / 映画的品質 |
| **Firefly Vector** | テキスト→SVGベクター / Illustrator 統合 | スケーラブル / ロゴ / アイコン生成 |
| **Firefly Design** | テンプレート生成 / Adobe Express 統合 | SNS / バナー / プレゼン素材 |
| **Firefly Custom Models** | 企業独自スタイル学習 / ブランドガイドライン適用 | Enterprise のみ / 数百枚で Fine-tune |

### Firefly Image 3 の技術的特徴
- **構造参照 (Structure Reference)**: 参照画像の構図・レイアウトを維持しながらスタイル変更
- **スタイル参照 (Style Reference)**: 参照画像の色調・テクスチャ・雰囲気を転写
- **キャラクター参照 (Character Reference)**: 同一キャラクターを複数シーンで一貫生成
- **解像度**: 最大 2048×2048 (Square) / 2688×1536 (Landscape) / 1344×2688 (Portrait)
- **商用安全**: 著作権クレームリスク軽減保証 (Adobe IP Indemnity)

### Firefly Custom Models (Enterprise)
```
1. Adobe Firefly Enterprise 契約
2. ブランド素材 100〜500 枚をアップロード
3. Firefly がブランドスタイルを学習 (数時間)
4. 「自社ブランドの雰囲気で○○を生成」が可能に
5. 全生成物に企業固有のウォーターマーク / C2PA メタデータ付与
```

### 自分株式会社での活用可能性
- **AI 大学 LP ビジュアル**: 各 AI プロバイダーの紹介画像を Firefly で一括生成 (商用安全)
- **マーケティング素材**: X / Instagram 投稿画像を週次バッチ生成 (Firefly API → GHA 自動化)
- **OGP 画像**: ogp-image-refresh.yml に Firefly API を追加 (FAL の代替/バックアップ)
- **ブログアイキャッチ**: dev.to / Qiita 記事用画像を Firefly で自動生成 (T-1 dispatch 連携)
- **競合比較ページ**: 21社のサービスビジュアルを統一スタイルで生成

### 競合比較
| サービス | 商用安全 | CC統合 | API | カスタムモデル |
|---------|---------|--------|-----|---------------|
| Adobe Firefly | ✅ 保証 | ✅ フル | ✅ | ✅ Enterprise |
| Midjourney | ⚠️ 要確認 | ❌ | ❌ | ❌ |
| DALL-E 3 | ✅ | OpenAI統合 | ✅ | ❌ |
| Stable Diffusion | ⚠️ 自己責任 | ❌ | ✅ OSS | ✅ LoRA |
| Ideogram | ✅ | ❌ | ✅ | ❌ |$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 212→213社化: Adobe Firefly 追加',
  'PS#3 S60。Adobe Firefly (エンタープライズAI画像生成 / Creative Cloud統合 / 商用安全IP補償 / Firefly Image 3+Video+Vector / カスタムモデル / Firefly API / 9/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
