-- PS#3 S58: AI大学 208→209社化 — Mubert 追加
-- Mubert: AI BGM ストリーミング生成 / リアルタイム無限ループ / API / 著作権フリー

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'mubert',
  'overview',
  'Mubert — AI BGM ストリーミング生成 (リアルタイム無限ループ / API / 著作権フリー)',
  $$## Mubert — AI BGM ストリーミング生成

**カテゴリ**: AI Generative Music / Background Music / Music API
**設立**: 2016年 / 本社: デラウェア (米国)
**特徴**: リアルタイム無限ループ BGM 生成 / ライブ配信・ポッドキャスト・アプリ向け
**パートナー**: React Native / Twitch 対応 / 著作権フリー配信
**評価**: 8/9

### 概要
Mubert は**リアルタイムで無限に続く AI 生成 BGM**を提供するプラットフォーム。ムード・BPM・ジャンルを指定するだけで、途切れることなく続く BGM をストリーミング提供する。Twitch ライブ配信・YouTube 動画・アプリ内 BGM・ポッドキャスト等で著作権フリーの音楽を使いたい開発者・クリエイター向けに最適化されている。

### 主な特長
- **リアルタイム生成**: API リクエストで即座に BGM ストリームが開始 (途切れなし)
- **ムード・BPM 指定**: calm / focus / energetic / melancholic など 30+ ムード
- **著作権フリー**: Mubert API 経由の楽曲は配信・商用利用 OK (収益化も可)
- **React Native SDK**: モバイルアプリへの BGM 統合が容易
- **Mubert Studio**: ブラウザ UI でノーコード BGM カスタマイズ
- **Mubert Render**: 動画用に指定秒数の楽曲をレンダリング

### 競合との差別化
AIVA: 作曲・楽譜生成 / ゲーム・映画向け / Beatoven.ai: 動画シーン別 BGM / Loudly: ソーシャル動画向け / Epidemic Sound: 人間が作った高品質 BGM (非 AI)

Mubert の強みは **ストリーミング特化 × リアルタイム無限ループ × React SDK × Twitch 対応**。ライブ配信・アプリ内 BGM の自動化に唯一対応するプラットフォーム。

### 導入コスト
- **Free**: 個人 / ウォーターマーク / 非商用
- **Creator**: 月 14 USD (商用 / 著作権フリー / 25 曲/月)
- **Pro**: 月 39 USD (無制限 / Render API / ライブ配信 OK)
- **Business**: 月 199 USD (API アクセス / React SDK / 商用配信)$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'mubert',
  'api',
  'Mubert API — BGM ストリーミング + Render API + React Native SDK (Python/JS)',
  $$## Mubert API / 統合

### Mubert API (Python)

```python
import requests

# BGM トラック生成 (指定秒数)
url = "https://api-b2b.mubert.com/v2/TTMusicByTags"
payload = {
    "method": "TTMusicByTags",
    "params": {
        "pat": "YOUR_API_KEY",
        "tags": "calm,focus,ambient",     # ムードタグ
        "bpm": 90,                         # BPM
        "duration": 60,                    # 秒
        "format": "mp3",
        "intensity": "medium"
    }
}
response = requests.post(url, json=payload)
track_url = response.json()["data"]["tasks"][0]["download_link"]
```

### Render API (動画用 BGM)

```python
# 動画の長さに合わせた BGM を生成
payload = {
    "method": "RecordTrackTTM",
    "params": {
        "pat": "YOUR_API_KEY",
        "duration": 120,      # 動画の長さ (秒)
        "tags": "cinematic,epic,inspiring",
        "format": "mp3"
    }
}
response = requests.post(url, json=payload)
job_id = response.json()["data"]["tasks"][0]["task_id"]
```

### React Native SDK

```javascript
import { Mubert } from '@mubert/react-native';

// アプリ内 BGM ストリーミング
await Mubert.play({
  tags: ['lo-fi', 'chill', 'study'],
  intensity: 'low',
  bpm: 75
});

// ムード切り替え (フェード付き)
await Mubert.transition({ tags: ['energetic', 'workout'] });
```

### 制限事項
- Render API は Pro プラン以上
- React SDK は Business プラン以上
- 最大 8 タグ/リクエスト
- ストリーミングは WebSocket 非対応 (HTTP ポーリング)$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'mubert',
  'models',
  'Mubert モデル — リアルタイム生成 AI + タグベース音楽合成 + 著作権管理',
  $$## Mubert の AI モデル

| 機能 | 技術 |
|------|------|
| BGM 生成 | 独自タグベース Neural Music Generation |
| ムード分類 | 30+ ムード × BPM × ジャンルの組み合わせ |
| リアルタイム | チャンク生成 + シームレス接続アルゴリズム |
| 著作権管理 | 自動 ContentID 免除登録 |

### ムードタグ一覧 (主要)
calm / focus / energetic / melancholic / happy / dark / cinematic / lo-fi /
ambient / epic / jazz / electronic / corporate / meditation / workout / sleep

### 自分株式会社での活用可能性
- AI 大学 e-ラーニング動画の自動 BGM (シーン別ムード切り替え)
- LP・プロダクト紹介動画のバックグラウンド BGM (Render API)
- 将来的なポモドーロタイマー機能 → 集中 BGM 自動再生 (React SDK)
- 週次 Podcast の OP/ED BGM 自動生成

### AIVA / Beatoven との違い
- Mubert: ストリーミング・ループ BGM / リアルタイム / アプリ統合向け
- AIVA: 作曲・楽譜 / ゲーム・映画向け / 一回生成
- Beatoven: 動画シーン別自動調整 / ノーコード向け$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 208→209社化: Mubert 追加',
  'PS#3 S58。Mubert (AI BGM ストリーミング生成 / リアルタイム無限ループ / 30+ ムード / React Native SDK / Render API / 著作権フリー / 8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
