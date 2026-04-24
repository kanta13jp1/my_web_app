-- Session PS#3-S31: AI大学 157社化 — Higgsfield AI 追加
-- Alex Mashrabov (CEO) + Igor Pasechnik (CTO) が 2023 年に創業した AI 動画生成プラットフォーム。
-- 2026-01 Series A $80M (Accel 主導) @ $1.3B valuation / 累計 $138M / 20M ユーザー。
-- $300M ARR (2026-02) — Runway / Pika / Kling 等の単一モデル競合と異なり 15+ モデルを統合。
-- Sora 2 / Veo 3.1 / Kling 3.0 / WAN 2.5 を 1 サブスクで利用可能 + 70+ 映画的カメラプリセット。
-- Starter $15/月・Plus $39/月・Ultra $99/月 / Cloud API (cloud.higgsfield.ai) 提供。
-- 既存 156 社に空白だった「マルチモデル AI 動画生成プラットフォーム」軸を埋める。
-- Step 0: 9/9 (マルチモデル差別化・公開 API・$1.3B valuation・$300M ARR 急成長)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'higgsfield',
  'overview',
  'Higgsfield AI — 15+ 動画モデルを統合したマルチモデル AI 動画生成プラットフォーム',
  $md$
# Higgsfield AI — The Multi-Model AI Video Platform

2023 年創業。**Alex Mashrabov** (CEO) と **Igor Pasechnik** (CTO) が
「あらゆる AI 動画モデルを 1 つのサブスクで使えるプラットフォーム」を目指して設立。

2026 年 1 月に **Series A $80M** (Accel 主導) を調達し評価額 **$1.3B** に到達。
累計調達 $138M / ユーザー数 **2,000 万人** / ARR **$300M** (2026 年 2 月時点)。

Runway / Pika / Kling などの「単一モデル」競合と異なり、**Sora 2・Veo 3.1・Kling 3.0・
WAN 2.5** を含む **15 以上の AI 動画・画像モデル** を 1 つのサブスクリプションで利用できる。
さらに **70+ 映画的カメラプリセット** (ドリー・パン・クレーン・ハンドヘルドなど) と
キャラクター一貫性を保つ **人物主体動画生成** が強みとして評価される。

## 主要機能
- **マルチモデル統合** — Sora 2 / Veo 3.1 / Kling 3.0 / WAN 2.5 など 15+ モデルを横断選択
- **キャラクター一貫性** — 同一人物の顔・衣装・スタイルを複数シーンで統一
- **70+ カメラプリセット** — 映画的な camera motion を直感的に指定 (ドリー/パン/クレーン等)
- **Diffuse** — Higgsfield 独自の高精度動画生成モデル (人物動作・物理法則に優れる)
- **Cloud API** — プログラマティックな動画生成 (cloud.higgsfield.ai)
- **クリエイター報酬プログラム** — 人気クリエイターへの報酬支払い制度

## 強み
- 単一サブスクで業界最多モデル数を利用可能 → モデル切り替えコスト不要
- **キャラクター一貫性** が競合より優れるとユーザーから評価 (人物・キャラクター主体コンテンツに最適)
- $300M ARR の急成長はコンテンツ制作 AI の大衆化を示す
- エンタープライズ向けカスタム連携 (Enterprise 問合せ対応)
$md$,
  'https://higgsfield.ai/',
  '2026-04-24',
  1
),

(
  'higgsfield',
  'models',
  'Higgsfield AI 統合モデル一覧 (2026)',
  $md$
## Higgsfield が統合する AI 動画・画像モデル

Higgsfield はモデルを独自開発するだけでなく、他社モデルも統合して提供する。

## 統合動画モデル

| モデル | 提供元 | 特徴 |
| :--- | :--- | :--- |
| **Sora 2** | OpenAI | 高品質・長尺・物理法則 |
| **Veo 3.1** | Google DeepMind | 映画品質・音声同期 |
| **Kling 3.0** | Kuaishou | コスト効率・高速生成 |
| **WAN 2.5** | Alibaba | 多スタイル・オープン |
| **Diffuse** | Higgsfield 独自 | キャラクター一貫性に特化 |
| **Hailuo** | MiniMax | アニメ・コミック風 |

## 統合画像モデル

| モデル | 特徴 |
| :--- | :--- |
| **FLUX.1 Pro** | Black Forest Labs / 高精細 |
| **Stable Diffusion XL** | Stability AI / オープン |
| **Ideogram 2.0** | テキスト埋め込み品質 |

## カメラプリセット (70+)

映画的な camera motion を選択するだけで動画に適用できる。

| カテゴリ | プリセット例 |
| :--- | :--- |
| **トラッキング** | ドリー・プッシュイン・プルアウト |
| **パン/チルト** | 水平パン・垂直チルト・オービット |
| **クレーン** | クレーンアップ・ペデスタル |
| **ハンドヘルド** | ハンドヘルド・シェイキー |

## プラン比較

| プラン | 月額 | クレジット | 主なモデルアクセス |
| :--- | :--- | :--- | :--- |
| **Starter** | $15/月 | 200 クレジット/月 | 全モデル |
| **Plus** | $39/月 | 1,000 クレジット/月 | 全モデル + 優先処理 |
| **Ultra** | $99/月 | 3,000 クレジット/月 | 全モデル + 最高優先 |
| **Enterprise** | 要相談 | カスタム | カスタム統合 |
$md$,
  'https://higgsfield.ai/pricing',
  '2026-04-24',
  2
),

(
  'higgsfield',
  'api',
  'Higgsfield Cloud API 入門',
  $md$
## Higgsfield Cloud API の始め方

Higgsfield は `cloud.higgsfield.ai` でプログラマティックな動画・画像生成 API を提供。

```python
# pip install requests

import requests
import time

API_KEY = "your-higgsfield-api-key"
BASE_URL = "https://cloud.higgsfield.ai/api/v1"

headers = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}

# 動画生成リクエスト
response = requests.post(
    f"{BASE_URL}/generations",
    headers=headers,
    json={
        "model": "diffuse",          # diffuse / kling-3.0 / wan-2.5 など
        "prompt": "A woman walking through a cherry blossom park in Tokyo, "
                  "cinematic dolly shot, golden hour lighting",
        "duration": 5,               # 秒数 (5 or 10)
        "camera_preset": "dolly_in", # 70+ プリセットから選択
        "aspect_ratio": "16:9"
    }
)

generation = response.json()
generation_id = generation["id"]

# 完了まで待機 (非同期生成)
while True:
    status_response = requests.get(
        f"{BASE_URL}/generations/{generation_id}",
        headers=headers
    )
    result = status_response.json()

    if result["status"] == "completed":
        print(f"動画 URL: {result['output_url']}")
        break
    elif result["status"] == "failed":
        print(f"エラー: {result['error']}")
        break

    time.sleep(5)  # 5秒ごとにポーリング
```

## 料金 (2026年4月時点)

| プラン | 月額 | クレジット |
| :--- | :--- | :--- |
| **Starter** | $15/月 | 200 クレジット/月 |
| **Plus** | $39/月 | 1,000 クレジット/月 |
| **Ultra** | $99/月 | 3,000 クレジット/月 |

> クレジット消費はモデルと動画長によって異なる (5 秒動画: 約 10〜50 クレジット)

## クイックスタート

1. [higgsfield.ai](https://higgsfield.ai) でアカウント作成 → Plus 以上のプランに加入
2. [cloud.higgsfield.ai](https://cloud.higgsfield.ai) で API キー発行
3. `/api/v1/generations` に POST リクエスト → generation_id を受取り
4. ステータスをポーリングして動画 URL を取得
$md$,
  'https://cloud.higgsfield.ai/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
