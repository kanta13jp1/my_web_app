-- PS#3 S60: AI大学 213→214社化 — Ideogram 追加
-- Ideogram: テキストレンダリング特化AI画像生成 / ロゴ・タイポグラフィ / 商用安全 / API提供

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'ideogram',
  'overview',
  'Ideogram — テキストレンダリング特化AI画像生成 (ロゴ・タイポグラフィ / 商用安全 / API)',
  $$## Ideogram — テキストレンダリング特化AI画像生成

**カテゴリ**: AI Image Generation / Typography / Design Tools
**設立**: 2023年 / 本社: San Francisco, CA / 元 Google Brain 研究者チーム創業
**特徴**: AI 画像内への正確なテキストレンダリングに特化 / ロゴ・ポスター・バナー生成
**ユーザー**: グラフィックデザイナー / マーケター / SNSクリエイター / ブランドチーム
**評価**: 8/9

### 概要
Ideogram は**AI 画像生成内でのテキスト描画精度**を最大の強みとするサービス。従来の Midjourney や Stable Diffusion では「OPEN AI」が「OPEMAI」など文字が崩れる問題が多発したが、Ideogram はこの課題を克服し、画像内に自然で読みやすいテキストを正確に描画できる。ポスター・ロゴ・バナー・名刺など「文字入りビジュアル」に特化しており、フォントスタイルの指定も可能。元 Google Brain・Character.AI・CMU 出身のエンジニアが創業。

### 主な特長
- **正確なテキストレンダリング**: プロンプト内の引用符 `"テキスト"` がほぼ正確に画像内に描画される
- **タイポグラフィ制御**: フォントスタイル (serif / sans-serif / handwritten / monospace) を指定可
- **Magic Prompt**: 短いプロンプトを AI が自動拡張して高品質生成 (オプション on/off)
- **スタイルプリセット**: Realistic / Design / 3D / Anime / Abstract などワンクリック切替
- **アスペクト比**: 1:1 / 16:9 / 9:16 / 4:3 など多数サポート (SNS 最適化)
- **リミックス**: 生成画像をベースにプロンプトを変えて派生生成
- **Canvas (Beta)**: インペイント / アウトペイント / レイヤー編集
- **商用利用**: 有料プランは生成画像の商用利用 OK

### テキストレンダリング精度比較
| サービス | "Hello World"精度 | ロゴ生成 | 日本語テキスト |
|---------|-----------------|---------|--------------|
| **Ideogram 2.0** | ★★★★★ | 優秀 | △ (改善中) |
| Midjourney v6 | ★★★ | △ | ✗ |
| DALL-E 3 | ★★★★ | ○ | △ |
| Stable Diffusion 3 | ★★★ | △ | ✗ |
| Adobe Firefly | ★★★★ | ○ | △ |

### 競合との差別化
Midjourney: アート品質最高 / テキスト描画弱 / API なし
DALL-E 3: ChatGPT 統合 / テキスト中程度 / 商用 OK
Stable Diffusion: OSS / カスタム自由 / テキスト弱
Adobe Firefly: 商用安全 / CC 統合 / テキスト中程度
Ideogram の強みは**テキスト入りデザイン素材に特化 + API 提供 + コスパ**。

### 導入コスト
- **Basic (無料)**: 月 10 スロー生成 (商用利用不可)
- **Starter**: 月 $7 / 400 Priority Generations / 商用 OK
- **Plus**: 月 $16 / 無制限スロー + 1,000 Priority / 商用 OK
- **Pro**: 月 $48 / 無制限 Priority + 無制限スロー / API アクセス / 商用 OK$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'ideogram',
  'api',
  'Ideogram API — テキスト付きAI画像生成 REST API (Python / バッチ処理)',
  $$## Ideogram API

### セットアップ
```bash
# https://ideogram.ai/manage-api でAPIキー取得 (Pro プラン以上)
pip install requests
export IDEOGRAM_API_KEY="your_api_key_here"
```

### テキスト入り画像生成
```python
import requests
import os

IDEOGRAM_API_KEY = os.environ["IDEOGRAM_API_KEY"]

def generate_with_text(prompt: str, aspect_ratio: str = "ASPECT_16_9") -> dict:
    """テキストレンダリングを含む画像生成"""
    headers = {
        "Api-Key": IDEOGRAM_API_KEY,
        "Content-Type": "application/json",
    }
    payload = {
        "image_request": {
            "prompt": prompt,
            "aspect_ratio": aspect_ratio,
            # ASPECT_1_1 / ASPECT_16_9 / ASPECT_9_16 / ASPECT_4_3 / ASPECT_3_4
            "model": "V_2",              # V_1 / V_1_TURBO / V_2 / V_2_TURBO
            "magic_prompt_option": "AUTO",  # ON / OFF / AUTO
            "style_type": "DESIGN",      # AUTO / GENERAL / REALISTIC / DESIGN / 3D / ANIME
            "negative_prompt": "blurry, low quality, text errors",
            "num_images": 4,             # 最大 8
            "seed": 12345,               # 再現性のある生成 (省略可)
        }
    }
    resp = requests.post(
        "https://api.ideogram.ai/generate",
        json=payload,
        headers=headers,
    )
    resp.raise_for_status()
    return resp.json()

# ロゴ生成例 (テキスト描画)
result = generate_with_text(
    'A minimalist logo design with the text "自分株式会社" in clean sans-serif font, '
    "dark indigo and orange color scheme, white background, professional"
)
for img in result["data"]:
    print(img["url"])
    print(f"  Prompt (expanded): {img.get('prompt', 'N/A')[:100]}")
```

### バナー・ポスター一括生成
```python
import time

templates = [
    {
        "prompt": 'Social media banner with text "AIで仕事を10倍加速" in bold Japanese, '
                  "gradient background from indigo to orange, modern design",
        "aspect_ratio": "ASPECT_16_9",
    },
    {
        "prompt": 'App store screenshot with text "自分株式会社 AIライフマネジメント", '
                  "smartphone mockup, clean UI, dark theme",
        "aspect_ratio": "ASPECT_9_16",
    },
    {
        "prompt": 'Blog thumbnail with text "2026年 最新AI大学ガイド", '
                  "colorful abstract background, professional typography",
        "aspect_ratio": "ASPECT_16_9",
    },
]

results = []
for t in templates:
    r = generate_with_text(t["prompt"], t["aspect_ratio"])
    results.append({"template": t["prompt"][:50], "images": [d["url"] for d in r["data"]]})
    time.sleep(2)  # レート制限対応

for r in results:
    print(f"\n[{r['template']}]")
    for url in r["images"]:
        print(f"  {url}")
```

### 画像編集 (インペイント)
```python
import base64

def edit_image(image_path: str, mask_path: str, prompt: str) -> dict:
    """マスク領域をプロンプトで置換"""
    with open(image_path, "rb") as f:
        image_data = base64.b64encode(f.read()).decode()
    with open(mask_path, "rb") as f:
        mask_data = base64.b64encode(f.read()).decode()

    # マルチパートフォームデータで送信
    resp = requests.post(
        "https://api.ideogram.ai/edit",
        headers={"Api-Key": IDEOGRAM_API_KEY},
        data={"prompt": prompt, "model": "V_2"},
        files={
            "image": ("image.png", base64.b64decode(image_data), "image/png"),
            "mask": ("mask.png", base64.b64decode(mask_data), "image/png"),
        },
    )
    resp.raise_for_status()
    return resp.json()
```

### GHA バッチ生成 (週次マーケティング素材)
```yaml
# .github/workflows/weekly-marketing-images.yml に統合
# 毎週月曜 09:00 JST → Ideogram API → S3/Firebase Storage に保存 → OGP 更新
steps:
  - name: Generate weekly banners
    env:
      IDEOGRAM_API_KEY: ${{ secrets.IDEOGRAM_API_KEY }}
    run: |
      python scripts/generate_weekly_banners.py
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'ideogram',
  'models',
  'Ideogram モデル — V2 / V2 Turbo + テキストレンダリング技術の詳細',
  $$## Ideogram モデル詳細

### モデルラインナップ
| モデル | 品質 | 速度 | テキスト精度 | 特徴 |
|--------|------|------|------------|------|
| **V_2** | ★★★★★ | 遅い (10-15s) | ★★★★★ | 最高品質 / テキスト最精度 / 商用最適 |
| **V_2_TURBO** | ★★★★ | 速い (3-5s) | ★★★★ | 速度優先 / バッチ処理向け |
| **V_1** | ★★★ | 中 | ★★★★ | レガシー / 旧アカウント互換 |
| **V_1_TURBO** | ★★★ | 速い | ★★★ | レガシー高速版 |

### テキストレンダリング技術
Ideogram がテキスト描画を他のモデルより高精度にできる背景:
- **専用 Typography Module**: 画像生成とは独立した文字描画モジュールを内蔵
- **Character-level Attention**: 各文字に独立したアテンションヘッドを割り当て
- **Font Latent Space**: フォントスタイルを連続的な潜在空間で表現 (補間が自然)
- **Multi-pass Rendering**: 下書き生成 → テキスト品質スコア評価 → 自動再生成

### スタイルプリセット詳細
| スタイル | 適用場面 |
|---------|---------|
| AUTO | モデルが最適スタイルを自動選択 |
| GENERAL | 汎用 / 写真 + イラスト中間 |
| REALISTIC | フォトリアリスティック / 人物・風景 |
| DESIGN | **ロゴ・バナー・ポスター (テキスト入り最適)** |
| 3D | 3DCG / プロダクトビジュアル |
| ANIME | アニメ・イラスト風 |

### 自分株式会社での活用可能性
- **AI 大学プロバイダーカード**: 各 AI サービスのロゴ風ビジュアルを Ideogram で生成
- **dev.to/Qiita アイキャッチ**: 記事タイトルを画像内に描画 → T-1 dispatch 自動連携
- **X 投稿画像**: 「今日の AI ニュース」バナーにテキストを正確に埋め込み
- **LP セクション画像**: 競合比較表やキャッチコピーを画像として視覚化
- **週次レポートサムネイル**: 数値・KPI を画像内テキストで表示

### コスト最適化
- バッチ処理は V_2_TURBO で速度重視 (単価低)
- 最終公開用のみ V_2 で高品質生成
- Magic Prompt AUTO で短いプロンプトでも高品質維持 (プロンプトエンジニアリング削減)
- seed 固定で同じビジュアルの再生成 → 差分確認・A/Bテストが容易$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 213→214社化: Ideogram 追加',
  'PS#3 S60。Ideogram (テキストレンダリング特化AI画像生成 / 元Google Brain創業 / V2モデル / ロゴ・ポスター・バナー / Ideogram API / Pro$48/月 / 8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
