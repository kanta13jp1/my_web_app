-- PS#3 S69: AI大学 232→233社化 — Kling AI 追加
-- Kling AI: 快手(Kuaishou)の動画生成AI / text-to-video / image-to-video / 2分1080p / Sora対抗

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'kling-ai',
  'overview',
  'Kling AI — 快手の動画生成AI (text/image to video / 2分1080p30fps / Sora対抗 / グローバル展開)',
  $$## Kling AI — 快手(Kuaishou)の動画生成AI

**カテゴリ**: Video Generation AI / Text-to-Video / Image-to-Video
**開発元**: 快手科技 (Kuaishou Technology) / 本社: 北京 / グローバルサービス: kling.kuaishou.com
**リリース**: 2024年6月 (中国)、2024年11月 (グローバル)
**モデル系列**: Kling 1.0 → 1.5 → 2.0 (2025年)
**資金**: Kuaishou Technology 上場企業 (HKEX: 1024) / 時価総額 ~$10B+
**評価**: 9/9

### 概要
Kling AI は **快手科技** が開発した動画生成AIで、テキストや画像から最大2分・1080p・30fps の高品質動画を生成できる。2024年6月に中国でリリースされ、同年11月にグローバル展開。Sora・Runway・Pika と肩を並べる主要動画生成ツールとして急速に普及した。

特に **人体の自然な動き再現** と **物理法則に基づく映像品質** で高評価を受けており、独自の「3D時空間注意機構 (3D Space-Time Joint Attention)」により、複雑な動作シーンでも破綻なく生成できる。

### 主な機能

**Text-to-Video (テキスト→動画)**
- 日本語/英語/中国語プロンプト対応
- 5秒〜最大2分の動画生成 (業界最長クラス)
- 720p / 1080p 選択可能
- 16:9 / 9:16 / 1:1 アスペクト比対応
- ネガティブプロンプト対応 (避けたい要素を指定)

**Image-to-Video (画像→動画)**
- 静止画を動画に変換 (写真が動き出す)
- キャラクターアニメーション: 人物写真に自然な動作を付加
- カメラモーション制御: パン/ズーム/チルト/ロールなど
- 「動かしたい部分」を指定するモーションブラシ機能

**Video Extension (動画延長)**
- 既存動画の末尾に新たなフレームを連続生成
- 最大4回延長 → 合計2分超の動画も可能

**Elements 機能**
- キャラクターの一貫性を保持して複数シーン生成
- 同一人物・同一スタイルで連続したストーリー動画を作成

### 技術的特徴
| 項目 | Kling AI | Sora (OpenAI) | Runway Gen-3 | Pika 2.0 |
|------|----------|---------------|--------------|---------|
| 最大尺 | **2分** | 20秒 (制限中) | 10秒 | 10秒 |
| 解像度 | **1080p** | 1080p | 1080p | 1080p |
| 人体動作 | ◎ 自然 | ◎ | △〜○ | △ |
| 物理シミュレーション | ○ | ◎ | △ | △ |
| API提供 | ✅ | ✅ (限定) | ✅ | ✅ |
| 無料枠 | **36クレジット/日** | ❌ | ❌ | ✅ (制限) |
| 月額コスト最安 | ~$8 | $20 | $12 | $8 |

### 導入コスト
- **Free**: 36クレジット/日 (5秒動画 ≈ 10クレジット / 1080p = 20クレジット)
- **Standard**: 月$66 / 660クレジット / 商用利用OK
- **Pro**: 月$137 / 3000クレジット / 優先生成
- **API**: クレジット単価方式 (従量課金) / Enterprise プラン応相談

### 自分株式会社での活用可能性
- **AI大学動画コンテンツ制作**: NotebookLM動画パイプラインとKling AIを組み合わせ → ブログ記事を動画化
- **プロダクトデモ動画**: アプリのUI操作をスクリーンショットから動画に変換 (Image-to-Video)
- **SNSコンテンツ**: Xや各SNS向けのショート動画を低コストで量産$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'kling-ai',
  'api',
  'Kling AI API — 動画生成REST API (Python/TypeScript / text-to-video / image-to-video)',
  $$## Kling AI API / 統合

### 概要
Kling AI は **klingai.com** でREST APIを提供。テキスト→動画・画像→動画をプログラムから生成できる。認証は APIキー方式。

### セットアップ
```bash
export KLING_API_KEY="your_api_key_here"
export KLING_BASE_URL="https://api.klingai.com"
```

### Text-to-Video生成 (Python)
```python
import os
import time
import requests

KLING_API_KEY = os.environ["KLING_API_KEY"]
KLING_BASE_URL = os.environ.get("KLING_BASE_URL", "https://api.klingai.com")

HEADERS = {
    "Authorization": f"Bearer {KLING_API_KEY}",
    "Content-Type": "application/json",
}

def create_text_to_video(
    prompt: str,
    negative_prompt: str = "",
    duration: int = 5,        # 5 or 10 seconds
    aspect_ratio: str = "16:9",
    model: str = "kling-v1",
) -> str:
    """テキストから動画生成タスクを開始し、タスクIDを返す"""
    resp = requests.post(
        f"{KLING_BASE_URL}/v1/videos/text2video",
        headers=HEADERS,
        json={
            "model_name": model,
            "prompt": prompt,
            "negative_prompt": negative_prompt,
            "cfg_scale": 0.5,
            "mode": "std",          # std (標準) / pro (高品質)
            "duration": str(duration),
            "aspect_ratio": aspect_ratio,
        },
    )
    resp.raise_for_status()
    return resp.json()["data"]["task_id"]

def wait_for_video(task_id: str, timeout: int = 300) -> str:
    """タスク完了まで待機し、動画URLを返す"""
    deadline = time.time() + timeout
    while time.time() < deadline:
        resp = requests.get(
            f"{KLING_BASE_URL}/v1/videos/text2video/{task_id}",
            headers=HEADERS,
        )
        resp.raise_for_status()
        data = resp.json()["data"]
        status = data.get("task_status")
        if status == "succeed":
            return data["task_result"]["videos"][0]["url"]
        elif status == "failed":
            raise RuntimeError(f"Task failed: {data.get('task_status_msg')}")
        time.sleep(10)
    raise TimeoutError(f"Task {task_id} did not complete within {timeout}s")

# 使用例: AI大学のプロモーション動画を生成
task_id = create_text_to_video(
    prompt=(
        "A professional Japanese developer typing on a laptop, "
        "surrounded by glowing AI visualizations and code, "
        "modern office background, cinematic quality"
    ),
    duration=5,
    aspect_ratio="16:9",
)
print(f"Task created: {task_id}")
video_url = wait_for_video(task_id)
print(f"Video ready: {video_url}")
```

### Image-to-Video (画像→動画) Python
```python
import base64

def create_image_to_video(
    image_path: str,
    prompt: str = "",
    duration: int = 5,
) -> str:
    """画像ファイルから動画生成タスクを開始"""
    with open(image_path, "rb") as f:
        image_b64 = base64.b64encode(f.read()).decode()

    resp = requests.post(
        f"{KLING_BASE_URL}/v1/videos/image2video",
        headers=HEADERS,
        json={
            "model_name": "kling-v1",
            "image": image_b64,
            "prompt": prompt,
            "duration": str(duration),
            "mode": "std",
        },
    )
    resp.raise_for_status()
    return resp.json()["data"]["task_id"]

# アプリのスクリーンショットを動画に変換
task_id = create_image_to_video(
    image_path="screenshot.png",
    prompt="The app UI smoothly transitions between screens, showing features",
)
video_url = wait_for_video(task_id)
print(f"Demo video: {video_url}")
```

### Deno Edge Function統合
```typescript
// supabase/functions/kling-video-gen/index.ts
const KLING_API_KEY = Deno.env.get("KLING_API_KEY")!;

Deno.serve(async (req: Request) => {
  const { prompt, duration = 5 } = await req.json();

  const taskResp = await fetch("https://api.klingai.com/v1/videos/text2video", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${KLING_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model_name: "kling-v1",
      prompt,
      duration: String(duration),
      aspect_ratio: "16:9",
      mode: "std",
    }),
  });

  if (!taskResp.ok) {
    return new Response(
      JSON.stringify({ error: "Kling API error", status: taskResp.status }),
      { status: taskResp.status, headers: { "Content-Type": "application/json" } },
    );
  }

  const { data } = await taskResp.json();
  return new Response(JSON.stringify({ task_id: data.task_id }), {
    headers: { "Content-Type": "application/json" },
  });
});
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'kling-ai',
  'models',
  'Kling AI 技術詳細 — 3D時空間注意機構 / Kling 1.5→2.0進化 / 動画生成AIアーキテクチャ比較',
  $$## Kling AI 技術詳細

### コアアーキテクチャ: 3D Space-Time Joint Attention

Kling AIの最大の技術的特徴は **「3D時空間注意機構」** と呼ばれる独自のアーキテクチャ設計にある。

```
[従来のVideo Diffusion Model]
Frame 1 → Frame 2 → Frame 3 ... (時系列に独立処理)
   ↓ 問題点
 フレーム間の整合性が崩れやすい
 人体の関節・物理的連続性が不自然になる

[Kling AI: 3D Space-Time Joint Attention]
Frame 1  Frame 2  Frame 3
   ↑        ↑        ↑
   └────────┼────────┘  ← 全フレームを同時に注意演算
            ↓
 時間軸と空間軸を統合した3Dテンソルで処理
 → フレーム間の物理整合性が高い
 → 人体の自然な動き、重力・慣性の再現度が高い
```

### モデル進化史

| バージョン | リリース | 主な改善 |
|-----------|---------|---------|
| **Kling 1.0** | 2024年6月 | 初代モデル / text-to-video 5s基本機能 |
| **Kling 1.5** | 2024年10月 | 10秒対応 / image-to-video強化 / Elements機能 |
| **Kling 2.0** | 2025年5月 | 2分対応 / 1080p / カメラ制御 / API拡充 |

### 動画生成AIアーキテクチャ比較
```
Sora (OpenAI):
  ベース: Video Transformer (Diffusion Transformer)
  強み: 物理シミュレーション最高品質 / 60秒生成 (Pro)
  弱み: API制限が厳しい / 高コスト ($20/月から)

Runway Gen-3 Alpha:
  ベース: Diffusion Model + Motion Brush
  強み: モーション制御が細かい / 映像効果豊富
  弱み: 最大10秒 / $12/月〜

Pika 2.0:
  ベース: Latent Diffusion + Scene Composer
  強み: シーン追加・削除のインペインティング
  弱み: 最大10秒 / 物理が不安定なことがある

Kling AI 2.0:
  ベース: 3D Space-Time Joint Attention Diffusion
  強み: 最大2分 / 人体動作自然 / 無料枠あり
  弱み: 生成速度がやや遅い (5秒で3〜5分)
```

### 快手 (Kuaishou) のAI戦略

快手はTikTok (ByteDance) の最大ライバルである中国の動画SNSプラットフォーム。DAU 4億人超。Kling AIは快手の**「Content Creator支援」**の一環として開発された。

**他の快手AIプロダクト**:
- **Kolors**: テキスト→高品質画像生成モデル (Stable Diffusion競合)
- **Kwai AI Assistant**: 快手内のAIチャット機能
- **LivePortrait**: 静止画を動画に変換するリアルタイムPortraitアニメーション

### 自分株式会社での活用可能性
- **AI大学プロモーション**: ブログ記事のサムネ画像 → Kling AI Image-to-Video → SNS動画
- **コスト最適化**: 無料36クレジット/日を活用 → 月5〜6本のショート動画を無料制作
- **NotebookLMパイプライン拡張**: `notebooklm-video-pipeline.yml` の生成動画をKling AIで視覚化$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 232→233社化: Kling AI 追加',
  'PS#3 S69。Kling AI (快手Kuaishouの動画生成AI/text-to-video/image-to-video/最大2分1080p30fps/3D時空間注意機構/Sora対抗/無料36cr/日/9/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
