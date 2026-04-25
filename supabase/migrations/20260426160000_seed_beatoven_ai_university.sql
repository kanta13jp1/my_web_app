-- PS#3 S58: AI大学 209→210社化 — Beatoven.ai 追加
-- Beatoven.ai: 動画・Podcast 向け AI BGM / シーン感情別 / 著作権フリー / 3M USD 調達

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'beatoven_ai',
  'overview',
  'Beatoven.ai — 動画・Podcast AI BGM 生成 (シーン感情別 / 著作権フリー / 3M USD)',
  $$## Beatoven.ai — 動画・Podcast 向け AI BGM 生成

**カテゴリ**: AI Music Generation / Video Background Music / Podcast Music
**設立**: 2021年 / 本社: バンガロール (インド)
**調達**: 3M USD (シード / Kalaari Capital / Global Founders Capital)
**特徴**: 動画シーンの感情に合わせた BGM を自動生成
**評価**: 7/9

### 概要
Beatoven.ai は**動画・Podcast のシーン感情に最適化した AI BGM 生成**プラットフォーム。動画を解析してシーンごとの感情 (happy/dramatic/tense など) を検出し、それに合った BGM を自動生成する。YouTube 動画・ポッドキャスト・広告動画・教育コンテンツなど、映像と音楽の感情的な一致が重要なコンテンツ向けに特化している。

### 主な特長
- **シーン感情検出**: 動画をアップロードするだけで感情曲線を自動解析
- **感情別 BGM**: dramatic / peaceful / tense / happy / romantic など感情別に生成
- **ノーコード**: ドラッグ&ドロップで BGM 配置・調整が完結
- **著作権フリー**: Beatoven 経由の楽曲は YouTube / Twitch / ポッドキャスト OK
- **多フォーマット**: MP3 / WAV 形式でダウンロード
- **カスタム長さ**: 動画の長さに自動マッチした BGM を生成

### 競合との差別化
Mubert: ストリーミング / アプリ BGM 特化 / AIVA: 楽譜・ゲーム音楽特化 / Epidemic Sound: 人間作成の高品質音楽 (高価格) / Artlist: ライセンス購入型

Beatoven の強みは **動画感情検出 × ノーコード × コスパ × インド発スタートアップの急成長**。コンテンツクリエイター向けの最もシンプルな AI BGM ツール。

### 導入コスト
- **Free**: 15 分/月・ウォーターマーク付き
- **Basic**: 月 11 USD (2 時間/月・商用 OK・ウォーターマークなし)
- **Pro**: 月 33 USD (無制限・API アクセス・優先生成)
- **Enterprise**: 問い合わせ (ホワイトラベル / API / SLA)$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'beatoven_ai',
  'api',
  'Beatoven.ai API — BGM 生成 REST API + 動画アップロード + 感情検出 (Python)',
  $$## Beatoven.ai API / 統合

### BGM 生成 API

```python
import requests

# Step 1: トラック作成
create_url = "https://public-api.beatoven.ai/api/v1/tracks"
headers = {
    "Authorization": "Bearer YOUR_API_KEY",
    "Content-Type": "application/json"
}
payload = {
    "title": "My AI BGM",
    "genre": "cinematic",
    "mood": "dramatic",
    "duration": 90,          # 秒
    "format": "mp3",
    "tempo": "medium"
}
response = requests.post(create_url, json=payload, headers=headers)
track_id = response.json()["track_id"]
```

### トラック生成状態確認

```python
# Step 2: 生成完了を待つ (ポーリング)
status_url = f"https://public-api.beatoven.ai/api/v1/tracks/{track_id}"
import time

while True:
    status = requests.get(status_url, headers=headers).json()
    if status["status"] == "composed":
        download_url = status["meta"]["composed_url"]
        break
    elif status["status"] == "failed":
        raise Exception("Track generation failed")
    time.sleep(5)

# Step 3: ダウンロード
audio_data = requests.get(download_url).content
with open("bgm.mp3", "wb") as f:
    f.write(audio_data)
```

### 動画感情検出 + BGM マッチング

```python
# 動画ファイルをアップロードして感情解析
video_url = "https://public-api.beatoven.ai/api/v1/video-analyze"
files = {"video": open("my_video.mp4", "rb")}
response = requests.post(video_url, files=files, headers=headers)
emotion_timeline = response.json()["emotions"]
# 例: [{"time": 0, "mood": "peaceful"}, {"time": 30, "mood": "dramatic"}, ...]
```

### 制限事項
- API は Pro プラン以上
- 動画感情検出は最大 10 分の動画
- 生成時間: 30秒〜2分 (楽曲長さによる)
- 最大 600 秒 (10分) の楽曲生成$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'beatoven_ai',
  'models',
  'Beatoven.ai モデル — 感情検出 + ジャンル生成 AI + 動画シーン最適化',
  $$## Beatoven.ai の AI モデル

| 機能 | 技術 |
|------|------|
| 感情検出 | 動画フレーム分析 + 音声感情推定モデル |
| 音楽生成 | 独自 Neural Music Composition |
| ジャンル分類 | 12+ ジャンル × 感情タグの組み合わせ |
| タイミング調整 | 動画カット点に楽曲変化を自動同期 |

### 対応ジャンル
Cinematic / Ambient / Jazz / Electronic / Classical / Hip-Hop / Rock / Folk / Pop / Lo-Fi / Acoustic / World

### 感情タグ
happy / peaceful / dramatic / tense / romantic / sad / energetic / mysterious / motivational / playful

### 自分株式会社での活用可能性
- AI 大学コンテンツ動画の BGM 自動生成 (ノーコードで即完成)
- LP 紹介動画のシーン別 BGM (dramatic → peaceful → inspiring 遷移)
- 週次レポート Podcast の BGM 自動付与
- ユーザーストーリー動画制作の BGM 選定自動化

### Mubert との比較
- Beatoven: 動画シーン感情マッチング / ノーコード / コンテンツ制作向け
- Mubert: リアルタイムストリーミング / アプリ BGM / 開発者向け API$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 209→210社化: Beatoven.ai 追加',
  'PS#3 S58。Beatoven.ai (動画・Podcast 向け AI BGM / シーン感情検出 + 自動 BGM マッチング / ノーコード / 著作権フリー / 3M USD 調達 / 7/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
