-- Ideogram コンテンツシード
-- AI大学: Ideogram プロバイダーの初期コンテンツ (overview / models / api)
-- 追加理由: 画像内テキスト生成が業界最高精度 / Ideogram 2.0でフォトリアル品質 / 公式API提供 / マーケティング資材・ポスター生成に最適

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('ideogram', 'overview', 'Ideogram AI 概要',
$$Ideogram AI は2023年創業の**画像生成AI企業**。最大の特徴は「画像の中にテキストを正確に埋め込む能力」で、他の画像生成AIが苦手としていたポスター・バナー・ロゴなどの文字入り画像を高精度に生成できます。Ideogram 2.0ではフォトリアルな品質も実現し、DALL-E・Stable Diffusionと競合しています。

## 特徴

- **テキスト精度**: 画像内の文字が正確に読める (他AIは文字が歪む・読めない場合が多い)
- **Ideogram 2.0**: フォトリアル品質・高解像度・詳細なプロンプト追従
- **Magic Prompt**: 短いプロンプトを自動で詳細化してクオリティを引き上げる機能
- **スタイル選択**: リアル・デザイン・アニメ・3D・水彩など豊富なスタイルプリセット
- **日本語対応**: 日本語テキストを画像内に埋め込む生成も可能

## 他AIとの差別化

```text
「夏祭りポスター」「SALE 50% OFF バナー」を生成する場合:

DALL-E 3:       文字が歪む・スペルミスが多い
Stable Diffusion: 文字がほぼ読めない
Midjourney:      文字品質が不安定
Ideogram 2.0:   ★ 正確なテキスト + 高品質背景ビジュアル
```

## 主要ユースケース

| ユースケース | 内容 |
| :--- | :--- |
| **マーケティング** | SNSバナー・広告クリエイティブ・セール告知ポスター |
| **ブランディング** | ロゴ案・名刺デザイン・会社紹介資料のビジュアル |
| **コンテンツ制作** | Zenn/Qiita記事のサムネイル・YouTube サムネイル |
| **ECサイト** | 商品バナー・キャンペーンビジュアル・セールタグ |
| **教育・プレゼン** | インフォグラフィック・スライドビジュアル |$$,
'https://ideogram.ai/', '2026-04-12', 1),

('ideogram', 'models', 'Ideogram AI — モデルと機能 (2026)',
$$## モデルバージョン

| モデル | 特徴 | 解像度 | 速度 |
| :--- | :--- | :--- | :--- |
| **Ideogram 2.0** | 最高品質・フォトリアル・テキスト精度最高 | 最大2048×2048 | 普通 |
| **Ideogram 2.0 Turbo** | 高速・低コスト版 | 最大1024×1024 | 高速 |
| **Ideogram 1.0** | 安定・旧世代 | 最大1024×1024 | 普通 |

## スタイルプリセット

| スタイル | 用途 |
| :--- | :--- |
| `REALISTIC` | フォトリアルな写真品質 |
| `DESIGN` | グラフィックデザイン・ポスター・バナー (テキスト多用) |
| `ANIME` | アニメ・マンガ風イラスト |
| `3D_RENDER` | 3Dレンダリング風 |
| `WATERCOLOR` | 水彩画・絵本風 |
| `AUTO` | AIがプロンプトに合わせて自動選択 |

## アスペクト比

```text
ASPECT_1_1   → Instagram投稿 / プロフィール画像
ASPECT_16_9  → YouTube サムネイル / ウェブバナー
ASPECT_9_16  → TikTok / Instagram Stories / スマホ壁紙
ASPECT_4_3   → プレゼン資料 / ブログサムネイル
ASPECT_3_4   → Pinterest / ポートレートポスター
```

## Magic Prompt 機能

```text
入力: "夏祭りポスター"
↓ Magic Prompt が自動拡張
出力: "A vibrant Japanese summer festival poster with bold typography reading
       '夏祭り2026', featuring fireworks, yukata-wearing people, lanterns,
       traditional red and gold color scheme, high contrast, commercial design style"
→ 入力より大幅に詳細な高品質ポスター画像を生成
```$$,
'https://ideogram.ai/t/explore', '2026-04-12', 2),

('ideogram', 'api', 'Ideogram AI API 入門',
$$## セットアップ

```bash
pip install requests  # 専用SDKなし — REST APIを直接使用
```

APIキーは `https://ideogram.ai/manage-api` で取得。

## 基本的な画像生成

```python
import requests
import json
from pathlib import Path

IDEOGRAM_API_KEY = "<IDEOGRAM_API_KEY>"

def generate_image(prompt: str, style: str = "DESIGN") -> str:
    """テキストから画像を生成してURLを返す"""
    response = requests.post(
        "https://api.ideogram.ai/generate",
        headers={
            "Api-Key": IDEOGRAM_API_KEY,
            "Content-Type": "application/json",
        },
        json={
            "image_request": {
                "prompt": prompt,
                "model": "V_2",             # Ideogram 2.0
                "style_type": style,         # DESIGN / REALISTIC / ANIME / 3D_RENDER
                "aspect_ratio": "ASPECT_16_9",
                "magic_prompt_option": "ON", # 自動プロンプト拡張
            }
        },
    )
    result = response.json()
    image_url = result["data"][0]["url"]
    print(f"生成完了: {image_url}")
    return image_url

# 使用例: SNS バナー生成
url = generate_image(
    prompt="自分株式会社 AIライフマネジメントアプリ 紹介バナー。オレンジとインディゴのグラデーション背景。モダンなUIスクリーンショット。日本語テキスト。",
    style="DESIGN",
)
```

## テキスト入り画像の生成 (Ideogram の真骨頂)

```python
import requests

IDEOGRAM_API_KEY = "<IDEOGRAM_API_KEY>"

def generate_banner_with_text(
    main_text: str,
    sub_text: str,
    theme: str,
) -> str:
    """文字入りバナー画像を生成"""
    prompt = f"""
    Professional marketing banner.
    Large bold text: "{main_text}"
    Subtitle: "{sub_text}"
    Theme: {theme}
    Clean layout, high contrast text, commercial design.
    """

    response = requests.post(
        "https://api.ideogram.ai/generate",
        headers={"Api-Key": IDEOGRAM_API_KEY, "Content-Type": "application/json"},
        json={
            "image_request": {
                "prompt": prompt,
                "model": "V_2",
                "style_type": "DESIGN",
                "aspect_ratio": "ASPECT_16_9",
                "magic_prompt_option": "OFF",  # 正確なテキスト制御時はOFF推奨
                "negative_prompt": "blurry text, typos, distorted letters",
            }
        },
    )
    return response.json()["data"][0]["url"]

# セールバナー生成
banner_url = generate_banner_with_text(
    main_text="SUMMER SALE 50% OFF",
    sub_text="7月1日〜7月31日限定",
    theme="Summer, bright colors, energetic",
)
print(f"バナー生成: {banner_url}")
```

## Supabase Edge Function から利用 (Deno)

```typescript
// Ideogram API を Supabase Edge Function から使用
const IDEOGRAM_API_KEY = Deno.env.get("IDEOGRAM_API_KEY")!;

async function generateOGPImage(title: string, description: string): Promise<string> {
  const res = await fetch("https://api.ideogram.ai/generate", {
    method: "POST",
    headers: {
      "Api-Key": IDEOGRAM_API_KEY,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      image_request: {
        prompt: `OGP image for web article. Title: "${title}". Description: "${description}". Clean design, Japanese tech blog style, orange accent color, white background.`,
        model: "V_2_TURBO",          // 高速版
        style_type: "DESIGN",
        aspect_ratio: "ASPECT_16_9", // OGP標準比率
        magic_prompt_option: "ON",
      },
    }),
  });

  const data = await res.json();
  return data.data[0].url; // 生成された画像URL (24時間有効)
}

// 使用例: ブログ記事のOGP画像を自動生成
const ogpUrl = await generateOGPImage(
  "Flutter Web でリアルタイム同期を実現する方法",
  "Supabase Realtime × Flutter × Riverpod の実装例"
);
```

## 料金 (2026年4月時点)

| プラン | 月額 | 生成回数 | 特徴 |
| :--- | :--- | :--- | :--- |
| **Free** | $0 | 25回/日 | 透かしなし・商用可 |
| **Basic** | $7 | 400回/月 | API利用可・高優先度 |
| **Plus** | $16 | 1,000回/月 | 商用利用・高優先度 |
| **Pro** | $48 | 3,000回/月 | チーム機能・最高優先度 |

- **Ideogram 2.0**: 1クレジット/枚
- **Ideogram 2.0 Turbo**: 0.5クレジット/枚$$,
'https://developer.ideogram.ai/', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 Ideogram AI 追加 (33社目)',
  'Ideogram AIをAI大学プロバイダーとして追加。画像内テキスト生成業界最高精度・Magic Prompt自動拡張・Design/Realistic/Animeスタイル・OGP画像自動生成EF統合例・セールバナー生成コード収録。AI大学プロバイダー数 32社→33社。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
