-- PS#3 S62: AI大学 218→219社化 — Canva AI 追加
-- Canva AI: 世界最大デザインプラットフォーム / AI機能群 / 月間MAU 1.5億+ / $26B評価

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'canva-ai',
  'overview',
  'Canva AI — 世界最大デザインプラットフォームのAI機能群 (MAU1.5億+ / $26B / Magic Studio)',
  $$## Canva AI — Magic Studio AI デザイン機能群

**カテゴリ**: AI Design / Generative AI / Creative Suite
**設立**: 2013年 / 本社: Sydney, Australia / 評価額: **$26B (2023年)** / MAU: **1.5億+**
**特徴**: グラフィックデザインを民主化したプラットフォームが AI 機能 (Magic Studio) を大量搭載
**ユーザー**: 非デザイナー / マーケター / SMB / 教育機関 / コンテンツクリエイター
**評価**: 9/9

### 概要
Canva は**「誰でもデザイナーになれる」**を実現したクラウドデザインツール。190カ国・1.5億人のユーザーを持ち、SNS投稿・プレゼン・動画・PDF・ホワイトボードなど100種類以上のテンプレートを提供する。2023年以降は **Magic Studio** として AI 機能を大量追加。テキストから画像生成・背景削除・画像拡張・プレゼン自動生成・動画編集・翻訳まで、デザインワークフローの全ステップに AI を統合した。競合の Adobe (Creative Cloud) より学習コストが低く、AI 機能でも急速に追いついている。

### Magic Studio — AI 機能一覧
| 機能 | 説明 |
|------|------|
| **Magic Media** | テキスト/画像から画像・動画を AI 生成 (Stable Diffusion + 独自モデル) |
| **Magic Write** | AI テキスト生成・言い換え・要約 (GPT-4 ベース) |
| **Magic Design** | ブランドカラー・フォントを学習し、テキストからデザイン全体を自動生成 |
| **Magic Resize** | SNS/印刷/Web 向けに1クリックで最適サイズに変換 |
| **Magic Edit** | 画像内の特定部分を選択してプロンプトで置換 (インペイント) |
| **Magic Eraser** | 写真から不要な物体・人物を AI で自動削除 |
| **Magic Expand** | 画像の外側を AI で自然に拡張 (アウトペイント) |
| **Background Remover** | 1クリックで背景を自動削除 |
| **Magic Animate** | 静止画に AI アニメーションを自動付与 |
| **AI Presentation** | トピックを入力するだけでスライド全体を自動生成 |
| **Magic Grab** | 写真内の被写体を切り抜いてレイヤーとして分離 |
| **Translate** | デザイン内のテキストを100+言語に AI 翻訳 |

### ビジネスモデル
- **Free**: 無料 / 250,000+ テンプレート / 5GBストレージ / 基本AI機能 (制限あり)
- **Canva Pro**: 月 $15/月 (年払い $120/年) / AI フル機能 / 無制限ストレージ / ブランドキット
- **Canva Teams**: 月 $10/ユーザー (3名以上) / 共同編集 / ブランドコントロール
- **Canva Enterprise**: カスタム / SSO / 高度な権限管理 / カスタムAIモデル

### 競合との差別化
Adobe Creative Cloud: プロ向け / 学習コスト高 / 高価格 / AI は Firefly
Figma: UI/UX デザイン特化 / 開発者向け / AI は限定的
Microsoft Designer: Microsoft 365 統合 / Bing AI 使用 / 機能は限定的
Canva の強みは **使いやすさ × AI × テンプレート数 × 価格 × MAU 規模 (ネットワーク効果)**$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'canva-ai',
  'api',
  'Canva Connect API — デザイン自動化・アセット管理・ブランド統合 REST API (Python)',
  $$## Canva Connect API

### 概要
Canva Connect API は企業向けのデザイン自動化 API。テンプレートへのデータ差し込み・アセット管理・ブランドキット統合が可能。2024年に GA。

### 認証セットアップ
```bash
# https://www.canva.com/developers/ でアプリ作成
# OAuth 2.0 / PKCE フロー
pip install requests requests-oauthlib
```

### OAuth アクセストークン取得
```python
import requests
import os

CLIENT_ID = os.environ["CANVA_CLIENT_ID"]
CLIENT_SECRET = os.environ["CANVA_CLIENT_SECRET"]
CANVA_API_BASE = "https://api.canva.com/rest/v1"

def get_access_token(auth_code: str, redirect_uri: str) -> str:
    resp = requests.post(
        "https://api.canva.com/rest/v1/oauth/token",
        data={
            "grant_type": "authorization_code",
            "code": auth_code,
            "redirect_uri": redirect_uri,
            "client_id": CLIENT_ID,
            "client_secret": CLIENT_SECRET,
        },
    )
    resp.raise_for_status()
    return resp.json()["access_token"]
```

### デザイン一覧取得
```python
def list_designs(access_token: str, query: str = "") -> list:
    headers = {"Authorization": f"Bearer {access_token}"}
    params = {}
    if query:
        params["query"] = query  # タイトル検索

    resp = requests.get(
        f"{CANVA_API_BASE}/designs",
        headers=headers,
        params=params,
    )
    resp.raise_for_status()
    return resp.json().get("items", [])

designs = list_designs(access_token, query="AI大学")
for d in designs:
    print(f"{d['title']} — {d['urls']['edit_url']}")
```

### テンプレートからデザイン自動生成
```python
def create_design_from_template(
    access_token: str,
    template_id: str,
    title: str,
) -> dict:
    """テンプレートを複製して新しいデザインを作成"""
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
    }
    payload = {
        "asset_id": template_id,
        "title": title,
    }
    resp = requests.post(
        f"{CANVA_API_BASE}/designs",
        json=payload,
        headers=headers,
    )
    resp.raise_for_status()
    return resp.json()["design"]

# 毎週の SNS 投稿テンプレートから自動生成
design = create_design_from_template(
    access_token,
    template_id="DAF...",
    title=f"週次AI大学ニュース {datetime.now().strftime('%Y-%m-%d')}",
)
print(f"編集URL: {design['urls']['edit_url']}")
```

### アセット(画像)アップロード
```python
def upload_asset(access_token: str, image_path: str, name: str) -> str:
    """Canva アセットライブラリに画像をアップロード"""
    headers = {"Authorization": f"Bearer {access_token}"}

    with open(image_path, "rb") as f:
        resp = requests.post(
            f"{CANVA_API_BASE}/assets/upload",
            headers={**headers, "Asset-Name": name},
            data=f,
        )
    resp.raise_for_status()
    job_id = resp.json()["job"]["id"]

    # アップロード完了待ち
    import time
    for _ in range(30):
        status_resp = requests.get(
            f"{CANVA_API_BASE}/assets/uploads/{job_id}",
            headers=headers,
        )
        job = status_resp.json()["job"]
        if job["status"] == "success":
            return job["asset"]["id"]
        time.sleep(2)
    raise TimeoutError("Asset upload timed out")
```

### デザインをPDFにエクスポート
```python
def export_design_as_pdf(access_token: str, design_id: str) -> str:
    """デザインを PDF としてエクスポート (ダウンロード URL 取得)"""
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
    }
    resp = requests.post(
        f"{CANVA_API_BASE}/exports",
        json={
            "design_id": design_id,
            "format": {"type": "pdf", "export_quality": "regular"},
        },
        headers=headers,
    )
    resp.raise_for_status()
    job_id = resp.json()["job"]["id"]

    # エクスポート完了待ち
    import time
    for _ in range(60):
        status = requests.get(
            f"{CANVA_API_BASE}/exports/{job_id}",
            headers={"Authorization": f"Bearer {access_token}"},
        ).json()["job"]
        if status["status"] == "success":
            return status["urls"][0]
        time.sleep(3)
    raise TimeoutError("Export timed out")
```

### GHA 自動デザイン生成 (週次SNS素材)
```yaml
# .github/workflows/weekly-canva-designs.yml
# 毎週月曜 08:00 JST → Canva API → デザイン生成 → PDF出力 → Slack通知
steps:
  - name: Generate weekly marketing designs
    env:
      CANVA_ACCESS_TOKEN: ${{ secrets.CANVA_ACCESS_TOKEN }}
    run: python scripts/generate_weekly_designs.py
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'canva-ai',
  'models',
  'Canva AI モデル — Magic Studio 技術基盤 + Leonardo AI買収 + Affinity統合',
  $$## Canva AI 技術詳細

### Magic Studio の技術基盤

| 機能 | 使用モデル / 技術 |
|------|-----------------|
| Magic Media (画像) | Stable Diffusion + Canva 独自 Fine-tune + **Leonardo AI** (2024年買収) |
| Magic Media (動画) | Runway Gen-2 ベース + 独自モデル |
| Magic Write | OpenAI GPT-4 API |
| Magic Design | 独自 Layout AI + テンプレート推薦モデル |
| Background Remover | Canva 独自 Segmentation モデル (オンデバイス処理) |
| Magic Expand | Stable Diffusion Inpainting |
| Translate | DeepL / Google Translate API |
| Magic Animate | 独自アニメーション推定モデル |

### Leonardo AI 買収 (2024年)
Canva は AI 画像生成スタートアップ Leonardo AI を **$153M** で買収。
- Leonardo の強み: フォトリアリスティック / ゲームアート / キャラクター生成
- Canva への統合: Magic Media の品質が大幅向上 / カスタムモデル学習機能追加
- Leonardo API は Canva 傘下で継続提供 (独立サービスとして維持)

### Affinity 統合 (2024年)
Adobe の競合であるプロ向けツール Affinity (Photo/Designer/Publisher) を **$380M** で買収。
- Canva + Affinity = プロ〜非プロまでの完全デザインスイート
- Adobe Creative Cloud への全面対抗体制

### AI 機能のコスト構造
- **無料枠**: 月 50 クレジット (画像生成 1回 = 1クレジット)
- **Pro**: 月 500 クレジット + Magic Write 無制限
- **Teams/Enterprise**: 無制限 AI 機能

### 自分株式会社での活用可能性
- **SNS 素材量産**: 毎週の X / Instagram 投稿画像を Canva Pro + Magic Media で生成
- **AI 大学サムネイル**: 各プロバイダー紹介カードを Canva テンプレート + Magic Design で統一スタイル生成
- **LP ビジュアル**: Magic Resize で SNS/Web/印刷を一括対応 → コスト削減
- **ブログアイキャッチ**: dev.to / Qiita 記事画像を T-1 dispatch 連携で自動生成
- **Canva API 活用**: GHA でテンプレートにデータ差し込み → 週次レポートを自動デザイン化

### 日本市場での強み
- 日本語 UI / 日本語テンプレート充実
- 教育機関向け無料プラン (Canva for Education)
- Japan オフィス開設済 (東京)
- LINE スタンプ / 名刺 / チラシなど日本特有のユースケースに対応$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 218→219社化: Canva AI 追加',
  'PS#3 S62。Canva AI / Magic Studio (世界最大デザインプラットフォーム/MAU1.5億+/$26B評価額/Leonardo AI買収/Affinity統合/Canva Connect API/Magic Media+Write+Design/9/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
