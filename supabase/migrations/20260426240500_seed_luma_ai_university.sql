-- PS#3 S69: AI大学 233→234社化 — Luma AI 追加
-- Luma AI: Dream Machine動画生成 / Genie 3D生成 / Ray2 / Photon画像 / a16z/KP $43M / SF

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'luma-ai',
  'overview',
  'Luma AI — Dream Machine動画生成 + Genie 3D生成 (Ray2 / Photon / a16z $43M / SF)',
  $$## Luma AI — マルチモーダル生成AI (動画・3D・画像)

**カテゴリ**: Video Generation AI / 3D Generation / Image Generation
**設立**: 2021年 / 本社: San Francisco, CA
**資金調達**: $43M (Andreessen Horowitz / Kleiner Perkins / GV / Sequoia)
**プロダクト**: Dream Machine (動画) / Ray2 (動画) / Genie (3D) / Photon (画像)
**評価**: 8/9

### 概要
Luma AI は **「現実世界の3D・動画をAIで生成・再現する」** をミッションに掲げるSFスタートアップ。元々は **NeRF (Neural Radiance Fields) を使ったスマートフォンでの3Dスキャン** を主力にしていたが、2024年に **Dream Machine** (テキスト/画像→動画) をリリースし世界的に注目を浴びた。

2024年〜2025年にかけて、動画生成モデル **Ray2**・3D生成モデル **Genie 2**・画像生成モデル **Photon** を相次いでリリースし、「生成AI × 物理シミュレーション」の分野で独自のポジションを確立している。

### プロダクト詳細

**Dream Machine / Ray2 (動画生成)**
- テキストまたは画像から最大120秒の動画を生成
- Ray2モデル: 映画的品質 / カメラワーク自然 / 人物動作が滑らか
- 4K出力対応 (Premiumプラン)
- カメラモーション: 手ブレ/ドリー/クレーン/FPV など20種類以上
- キャラクター一貫性: 同一人物を複数シーンで維持

**Genie / Genie 2 (3D生成)**
- テキストプロンプトから3Dオブジェクト・環境を生成
- glTF / FBX / OBJ などゲームエンジン互換フォーマット出力
- Unreal Engine / Unity / Blenderに直接インポート可能
- ゲーム開発・メタバース・建築ビジュアライズに活用

**Photon (画像生成)**
- テキスト→高品質スチル画像 (Stable Diffusion / DALL-E 3 競合)
- Photon Flash: 高速・低コスト版 (API向け)
- 商用ライセンス付き

**NeRF / 3D Scanning (旧来の強み)**
- スマートフォンで物体を360度撮影 → Webブラウザで3Dモデル化
- ARコマース (EC商品の3D表示) に活用 → Amazon / IKEA が導入

### 競合との差別化
| 項目 | Luma AI | Sora | Kling AI | Runway |
|------|---------|------|----------|--------|
| 3D生成 | ✅ Genie 2 | ❌ | ❌ | ❌ |
| 物理品質 | ◎ Ray2 | ◎ | ○ | △ |
| 動画尺 | 最大120s | 60s(Pro) | **2分** | 10s |
| 無料枠 | ✅ (30クレジット) | ❌ | ✅ (36cr/日) | ❌ |
| API | ✅ Luma API | △ 制限中 | ✅ | ✅ |
| 画像生成 | ✅ Photon | ❌ | ❌ | ❌ |

### 導入コスト
- **Free**: 月30クレジット (Ray1 動画5秒 ≈ 1クレジット)
- **Standard**: 月$29.99 / 120クレジット + 高速生成
- **Pro**: 月$99.99 / 400クレジット + 4K + 商用
- **Premier**: 月$499.99 / 2000クレジット + カスタム
- **API**: $0.14〜$1.00/クレジット (モデル・解像度により変動)

### 自分株式会社での活用可能性
- **3Dプロダクトビジュアライズ**: アプリ機能のコンセプトアートを3D化してLP掲載
- **動画コンテンツ**: Kling AI と組み合わせてA/Bテスト → 品質比較してコスト最適化
- **Genieで3Dアセット生成**: 将来のARモバイルアプリ対応時のアセット制作コスト削減$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'luma-ai',
  'api',
  'Luma AI API — 動画・3D・画像生成REST API (Python/TypeScript / Ray2 / Genie / Photon)',
  $$## Luma AI API / 統合

### 概要
Luma AI は **lumaapi.com** でREST APIを提供。動画 (Ray2)・3D (Genie)・画像 (Photon) を単一APIキーでアクセス可能。

### セットアップ
```bash
pip install lumaai  # 公式 Python SDK
export LUMAAI_API_KEY="your_api_key_here"
```

### Text-to-Video生成 (Python SDK)
```python
import os
import time
from lumaai import LumaAI

client = LumaAI(auth_token=os.environ["LUMAAI_API_KEY"])

def generate_video(
    prompt: str,
    model: str = "ray-2",   # "ray-1-6" / "ray-2" / "ray-flash-2"
    duration: str = "5s",    # "5s" / "9s"
    aspect_ratio: str = "16:9",
    loop: bool = False,
) -> str:
    """動画生成タスクを開始し完了後にURLを返す"""
    generation = client.generations.create(
        model=model,
        prompt=prompt,
        duration=duration,
        aspect_ratio=aspect_ratio,
        loop=loop,
    )
    task_id = generation.id
    print(f"Generation started: {task_id}")

    while True:
        gen = client.generations.get(task_id)
        if gen.state == "completed":
            return gen.assets.video
        elif gen.state == "failed":
            raise RuntimeError(f"Generation failed: {gen.failure_reason}")
        time.sleep(5)

# AI大学コンテンツ紹介動画の生成
video_url = generate_video(
    prompt=(
        "A sleek dark-themed web application showing AI tools dashboard, "
        "smooth UI transitions, Japanese text labels, modern SaaS design, "
        "cinematic pan shot"
    ),
    model="ray-2",
    duration="5s",
)
print(f"Video: {video_url}")
```

### Image-to-Video (画像→動画)
```python
def image_to_video(
    image_url: str,
    prompt: str = "",
    model: str = "ray-2",
) -> str:
    """画像URLから動画を生成"""
    generation = client.generations.create(
        model=model,
        prompt=prompt,
        keyframes={
            "frame0": {
                "type": "image",
                "url": image_url,
            }
        },
    )
    while True:
        gen = client.generations.get(generation.id)
        if gen.state == "completed":
            return gen.assets.video
        elif gen.state == "failed":
            raise RuntimeError(gen.failure_reason)
        time.sleep(5)

# スクリーンショットを動画デモに変換
video_url = image_to_video(
    image_url="https://my-web-app-b67f4.web.app/screenshot.png",
    prompt="The app UI comes to life with smooth animations",
)
```

### Photon 画像生成
```python
def generate_image(
    prompt: str,
    model: str = "photon-1",   # "photon-1" / "photon-flash-1"
    aspect_ratio: str = "16:9",
) -> str:
    """テキストから画像を生成してURLを返す"""
    generation = client.generations.image.create(
        model=model,
        prompt=prompt,
        aspect_ratio=aspect_ratio,
    )
    while True:
        gen = client.generations.get(generation.id)
        if gen.state == "completed":
            return gen.assets.image
        elif gen.state == "failed":
            raise RuntimeError(gen.failure_reason)
        time.sleep(3)

# AI大学のOGP画像を生成
og_image = generate_image(
    prompt="Modern Japanese AI university concept art, futuristic digital learning, dark theme",
    model="photon-1",
    aspect_ratio="1:1",
)
```

### Deno Edge Function統合
```typescript
// supabase/functions/luma-video-gen/index.ts
const LUMA_API_KEY = Deno.env.get("LUMAAI_API_KEY")!;

Deno.serve(async (req: Request) => {
  const { prompt, model = "ray-2", duration = "5s" } = await req.json();

  const genResp = await fetch("https://api.lumalabs.ai/dream-machine/v1/generations", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${LUMA_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ prompt, model, duration, aspect_ratio: "16:9" }),
  });

  if (!genResp.ok) {
    return new Response(
      JSON.stringify({ error: "Luma API error", status: genResp.status }),
      { status: genResp.status, headers: { "Content-Type": "application/json" } },
    );
  }

  const { id } = await genResp.json();
  return new Response(JSON.stringify({ generation_id: id }), {
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
  'luma-ai',
  'models',
  'Luma AI 技術詳細 — Ray2モデル / NeRF起源 / 3D Gaussian Splatting / 動画生成AI物理品質比較',
  $$## Luma AI 技術詳細

### Ray2 モデルアーキテクチャ

Ray2は Luma AIの主力動画生成モデル。**「映画的品質」** と **「物理整合性」** を最重視して設計されている。

```
[Ray2 動画生成パイプライン]

テキストプロンプト入力
  "A camera slowly pans over a misty Japanese mountain at sunrise"
       ↓
テキスト理解:
  - シーン構造解析 (主体 / 動き / 環境 / 照明 / カメラワーク)
  - 言語的スタイルガイダンス (misty → 霧 + 散乱光)
       ↓
ノイズ除去拡散 (Video Diffusion):
  - 高次元時空間潜在空間でのノイズ除去
  - フレーム間一貫性を保つ3D注意機構
  - 動き推定による物理的整合性
       ↓
物理シミュレーション補正:
  - 重力・光の散乱・流体の挙動を学習した補正レイヤー
  - 「ありえない動き」をポスト補正で除去
       ↓
4K アップスケーリング (Premiumのみ):
  - Super-Resolution モジュール (Real-ESRGAN ベース)
       ↓
最終動画出力 (MP4 / WebM)
```

### Luma AIの起源: NeRFから生成AIへ

Luma AIは2021年に**「スマートフォンでNeRFを民主化する」**というビジョンで創業した。

```
NeRF (Neural Radiance Fields) とは:
  - 複数の写真から3D空間を暗黙的に学習するニューラルネットワーク
  - カメラが移動した場合の未知視点を高精度に合成できる
  - 従来の3Dスキャン (LiDAR / フォトグラメトリ) より簡単・高精度

Luma AI の貢献:
  - iPhoneのLiDAR + カメラで30秒スキャン → NeRFモデル生成
  - ブラウザで3D表示可能 (WebGL)
  - EC商品ページ向け3D表示 / ARビューに活用
  → Amazon/IKEA が商品ページに採用

2023年以降の進化:
  NeRF → 3D Gaussian Splatting (高速化・高品質化)
       → Genie (テキスト→3D生成) へ昇華
       → Dream Machine (動画生成) にNeRF知識を応用
```

### 3D Gaussian Splatting 技術

```
NeRFの次世代技術: 3D Gaussian Splatting (3DGS)

NeRFの弱点:
  - 推論速度が遅い (1フレーム数秒)
  - リアルタイムレンダリング不可

3DGSの改善:
  - 3D空間を「楕円体のガウス関数」の集合で表現
  - GPU上でリアルタイムレンダリング (60fps+)
  - 編集可能: 個々のガウス関数を移動・変形・削除

Luma Genie での活用:
  テキスト → 3DGSモデル生成 → Unreal Engineにインポート
  → ゲーム開発の3Dアセット制作を10分の1に短縮
```

### 自分株式会社との技術的親和性
- **Flutter Web × Luma API**: OGP画像を Photon で動的生成 → SNS拡散改善
- **NotebookLM動画パイプライン**: Ray2 + Kling AI の品質A/Bテストフレームワーク
- **将来のAR機能**: Genie 2 で3Dアセット生成 → Flutter ARプラグインで表示$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 233→234社化: Luma AI 追加',
  'PS#3 S69。Luma AI (Dream Machine/Ray2動画生成/Genie 3D生成/Photon画像生成/NeRF起源/3D Gaussian Splatting/a16z+KP $43M/SF/8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
