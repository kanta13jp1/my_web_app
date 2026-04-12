-- Runway コンテンツシード
-- AI大学: Runway プロバイダーの初期コンテンツ (overview / models / api)
-- 追加理由: 動画生成AI最大手 / Gen-3 Alpha でテキスト→動画・画像→動画 / クリエイター・映像制作に革命

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('runway', 'overview', 'Runway 概要',
$$Runway は2018年創業の**動画生成AI企業**。Gen-3 Alpha・Gen-2 などのモデルでテキストや画像から高品質な動画を生成します。ハリウッド映画の視覚効果にも使われており、クリエイティブAIの中で最も革新的な企業の一つです。

## 特徴

- **テキスト→動画 (Text-to-Video)**: 文章で説明するだけでリアルな動画を生成
- **画像→動画 (Image-to-Video)**: 静止画に動きを付けてアニメーション化
- **動画→動画 (Video-to-Video)**: 既存の動画のスタイル・内容を変換
- **Gen-3 Alpha**: 2024年発表の最新世代。4K品質・一貫したキャラクター・物理シミュレーション対応
- **Act-One**: 俳優のパフォーマンスをキャラクターに転写するモーションキャプチャAI

## 生成可能なコンテンツ

```text
テキスト → Runway Gen-3 → 動画 (最大10秒・4K)
画像    → Runway Gen-3 → アニメーション
動画    → Runway Gen-3 → スタイル変換動画

その他機能:
- 背景除去 (Green Screen)
- フレーム補間 (スローモーション化)
- ビデオエクスパンション (動画の延長)
- テキスト読み上げ動画 (Talking Head)
```

## 主要ユースケース

| ユースケース | 内容 |
| :--- | :--- |
| **広告・マーケティング** | 製品動画・CMコンセプト映像を低コストで生成 |
| **映画・VFX** | 視覚効果・コンセプトビジュアル・絵コンテ動画化 |
| **SNSコンテンツ** | TikTok・Instagram Reel・YouTube Shorts 用ショート動画 |
| **プロトタイピング** | ゲームシネマティック・アプリデモ動画の素早い制作 |
| **教育コンテンツ** | 説明動画・インフォグラフィック動画の自動生成 |

## 業界での採用実績

- **映画「エブリシング・エブリウェア・オール・アット・ワンス」** — VFXにRunwayを採用
- **ミュージックビデオ** — 多数のアーティストがGen-2でMV制作
- **広告代理店** — WPP・Publicis グループが公式パートナー契約$$,
'https://runwayml.com/', '2026-04-12', 1),

('runway', 'models', 'Runway — 利用可能モデル・機能 (2026)',
$$## テキスト→動画モデル

| モデル | 解像度 | 長さ | 特徴 |
| :--- | :--- | :--- | :--- |
| **Gen-3 Alpha** | 最大4K | 最大10秒 | 最高品質・物理リアル・一貫性高 |
| **Gen-3 Alpha Turbo** | 最大1080p | 最大10秒 | Gen-3より高速・低コスト |
| **Gen-2** | 最大1080p | 最大16秒 | 安定・低コスト・API利用可 |

## 画像→動画 (Image-to-Video)

```text
入力: 静止画 (JPEG/PNG)
出力: 5〜10秒の動画 (その画像から動きが生まれる)

用途:
- 製品写真をアニメーション化
- ポートレートに動きを追加
- 風景写真をシネマティック動画に
```

## 動画編集機能 (Runway Studio)

| 機能 | 説明 |
| :--- | :--- |
| **Inpainting** | 動画の特定箇所だけを修正・置換 |
| **Background Removal** | AIでグリーンスクリーン不要の背景除去 |
| **Super Slow Motion** | フレーム補間で滑らかなスローモーション |
| **Expand Video** | 動画の前後を自然に延長生成 |
| **Act-One** | 俳優動画 → アニメキャラクターへの転写 |
| **Motion Brush** | 動画の特定エリアにだけ動きを付与 |

## 競合比較 (動画生成AI)

| サービス | 最大長 | 品質 | API | 特徴 |
| :--- | :--- | :--- | :--- | :--- |
| **Runway Gen-3** | 10秒 | 最高 | ✅ | 映画品質・商用利用可 |
| Pika 2.0 | 5秒 | 高 | ✅ | 低コスト・高速 |
| Sora (OpenAI) | 60秒 | 最高 | 限定 | 長尺・高精細 |
| Kling (快手) | 30秒 | 高 | ✅ | 中国製・高性能 |$$,
'https://runwayml.com/research', '2026-04-12', 2),

('runway', 'api', 'Runway API 入門',
$$## セットアップ

```bash
pip install runwayml
```

## テキスト→動画生成 (Gen-3 Alpha)

```python
import runwayml
import time

client = runwayml.RunwayML(api_key="<RUNWAY_API_KEY>")

# テキストから動画を生成
task = client.image_to_video.create(
    model="gen3a_turbo",
    prompt_image="https://example.com/my-image.jpg",  # 参照画像 (任意)
    prompt_text="A cinematic shot of a futuristic city at night, neon lights reflecting on wet streets",
    duration=5,         # 5秒 or 10秒
    ratio="1280:768",   # 横長 (他: "768:1280", "1104:832" など)
)

task_id = task.id
print(f"タスク開始: {task_id}")

# 生成完了を待機 (ポーリング)
while True:
    task = client.tasks.retrieve(task_id)
    print(f"状態: {task.status}")

    if task.status == "SUCCEEDED":
        video_url = task.output[0]
        print(f"動画URL: {video_url}")
        break
    elif task.status == "FAILED":
        print(f"失敗: {task.failure}")
        break

    time.sleep(5)  # 5秒待機してから再チェック
```

## 画像→動画 (静止画をアニメーション化)

```python
import runwayml
import base64
import time

client = runwayml.RunwayML(api_key="<RUNWAY_API_KEY>")

# ローカル画像をbase64で読み込み
with open("product_photo.jpg", "rb") as f:
    image_data = base64.b64encode(f.read()).decode("utf-8")
    image_data_uri = f"data:image/jpeg;base64,{image_data}"

# 製品写真をアニメーション動画に変換
task = client.image_to_video.create(
    model="gen3a_turbo",
    prompt_image=image_data_uri,
    prompt_text="The product slowly rotates, revealing all angles. Professional product shot.",
    duration=5,
    ratio="1280:768",
)

# 完了待機
while True:
    result = client.tasks.retrieve(task.id)
    if result.status == "SUCCEEDED":
        print(f"完成: {result.output[0]}")
        break
    elif result.status == "FAILED":
        print(f"エラー: {result.failure}")
        break
    time.sleep(5)
```

## Supabase Edge Function + Runway 動画生成

```typescript
// Supabase Edge Function: テキストから動画を生成してStorageに保存
const RUNWAY_API_KEY = Deno.env.get("RUNWAY_API_KEY")!;

async function generateVideo(prompt: string): Promise<string> {
  // Step 1: 動画生成タスクを作成
  const createRes = await fetch("https://api.dev.runwayml.com/v1/image_to_video", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${RUNWAY_API_KEY}`,
      "Content-Type": "application/json",
      "X-Runway-Version": "2024-11-06",
    },
    body: JSON.stringify({
      model: "gen3a_turbo",
      promptText: prompt,
      duration: 5,
      ratio: "1280:768",
    }),
  });

  const task = await createRes.json();
  const taskId = task.id;

  // Step 2: ポーリングで完了を待機
  for (let i = 0; i < 60; i++) {
    await new Promise((r) => setTimeout(r, 10000)); // 10秒待機

    const statusRes = await fetch(`https://api.dev.runwayml.com/v1/tasks/${taskId}`, {
      headers: { "Authorization": `Bearer ${RUNWAY_API_KEY}` },
    });
    const status = await statusRes.json();

    if (status.status === "SUCCEEDED") {
      return status.output[0]; // 動画URL
    } else if (status.status === "FAILED") {
      throw new Error(`Video generation failed: ${status.failure}`);
    }
  }

  throw new Error("Timeout waiting for video generation");
}
```

## 料金 (2026年4月時点)

| プラン | 月額 | クレジット | Gen-3 Turbo換算 |
| :--- | :--- | :--- | :--- |
| **Basic** | $15 | 625 credits | 約125本 (5秒) |
| **Standard** | $35 | 2,250 credits | 約450本 (5秒) |
| **Pro** | $95 | 7,500 credits | 約1,500本 (5秒) |
| **Unlimited** | $195 | 無制限 | 無制限 (速度制限あり) |

- Gen-3 Alpha Turbo (5秒): 5 credits
- Gen-3 Alpha (5秒): 10 credits
- Gen-3 Alpha (10秒): 20 credits$$,
'https://docs.runwayml.com/', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 Runway 追加 (31社目)',
  'RunwayをAI大学プロバイダーとして追加。動画生成AI最大手・Gen-3 Alpha (4K・10秒)・Text-to-Video/Image-to-Video・映画VFX採用実績・Supabase Edge Function統合例・競合比較表を収録。AI大学プロバイダー数 30社→31社。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
