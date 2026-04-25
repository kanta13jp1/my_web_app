-- PS#3 S57: AI大学 207→208社化 — AIVA 追加
-- AIVA: AI 作曲 / SACEM 登録 / ゲーム・映画・広告音楽生成 / 著作権フリー

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'aiva',
  'overview',
  'AIVA — AI 作曲 (SACEM 登録 / ゲーム・映画音楽 / 著作権フリー / API 提供)',
  $$## AIVA — AI 作曲 (Artificial Intelligence Virtual Artist)

**カテゴリ**: AI Music Composition / Generative Music
**設立**: 2016年 / 本社: ルクセンブルク
**特記**: 世界初の SACEM (フランス著作権協会) 登録 AI 作曲家
**ユーザー数**: 企業・ゲームスタジオ・映画制作会社多数
**評価**: 8/9

### 概要
AIVA は AI が楽曲を自動作曲する**ジェネレーティブ音楽プラットフォーム**。世界初の SACEM (フランス著作権協会) 登録 AI アーティストとして認められた先駆的存在。ゲーム BGM・映画サウンドトラック・広告音楽・e-ラーニング BGM など幅広い用途に対応し、生成楽曲の著作権をユーザーが保有できるプランも提供する。

### 主な特長
- **SACEM 認定 AI 作曲家**: 世界初の AI 著作権登録 → 音楽業界に新しい地平
- **多ジャンル対応**: クラシック / ポップ / ロック / ジャズ / ゲーム BGM / 映画音楽 / 電子音楽
- **感情・強度制御**: テンポ・楽器・感情 (epic/calm/dark など) をパラメータで指定
- **スコア出力**: MIDI / MP3 / WAV + 楽譜 (MusicXML / PDF) でダウンロード
- **API**: 楽曲生成 API を提供 (エンタープライズ)
- **著作権**: Pro プランはユーザーが楽曲著作権を保有

### 競合との差別化
Suno AI: 歌声入り / 最新 LLM 世代 / プロンプト入力 / Udio: 高品質歌声 + 楽器 / Mubert: ストリーミング BGM 特化 / Beatoven.ai: 動画 BGM 特化

AIVA の強みは **SACEM 認定 × 著作権保有 × 楽譜出力 × ゲーム・映画特化**。業務用途で法的に安全な AI 楽曲生成が必要な場合の最有力候補。

### 導入コスト
- **Free**: 月 3 曲 (著作権は AIVA 保有)
- **Standard**: 月 11 EUR (月 15 曲・著作権 50% / MP3/FLAC)
- **Pro**: 月 33 EUR (無制限・著作権 100% ユーザー保有・MIDI/楽譜)
- **Enterprise**: 問い合わせ (API / カスタム学習 / SLA)$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'aiva',
  'api',
  'AIVA API — 楽曲生成 REST API + MIDI/MP3 出力 + 楽譜生成 (Enterprise)',
  $$## AIVA API / 統合

### 楽曲生成 API (Enterprise)

```python
import requests

url = "https://api.aiva.ai/v1/compositions"
headers = {
    "Authorization": "Bearer YOUR_API_KEY",
    "Content-Type": "application/json"
}
payload = {
    "influence": "epic_orchestral",  # ジャンル/スタイル
    "duration": 120,                  # 秒 (30-300)
    "tempo": "fast",                  # slow/medium/fast
    "key": "C_major",
    "time_signature": "4/4",
    "instruments": ["piano", "strings", "brass", "percussion"],
    "format": "mp3"
}
response = requests.post(url, json=payload, headers=headers)
job_id = response.json()["job_id"]
```

### 楽曲ダウンロード

```python
# ポーリングで完成確認
status_url = f"https://api.aiva.ai/v1/compositions/{job_id}"
response = requests.get(status_url, headers=headers)
if response.json()["status"] == "ready":
    audio_url = response.json()["url"]  # MP3 / WAV / FLAC
    midi_url = response.json()["midi_url"]  # MIDI
    score_url = response.json()["score_url"]  # 楽譜 PDF
```

### MIDI → DAW 連携

```python
# MIDI ダウンロード → Logic Pro / Ableton Live に取り込み
import urllib.request
urllib.request.urlretrieve(midi_url, "aiva_composition.mid")
# MIDI を DAW で編集 → 人間とコラボ作曲
```

### Webhook 対応 (Enterprise)

```python
payload["webhook_url"] = "https://your-server.com/music-ready"
# 完成時に POST で通知 → ポーリング不要
```

### 制限事項
- API は Enterprise プランのみ
- 生成時間: 30秒〜3分 (楽曲長さによる)
- Free/Standard は API 非対応 → UI のみ$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'aiva',
  'models',
  'AIVA モデル — Transformer ベース作曲 + SACEM 著作権 + 楽器・感情制御',
  $$## AIVA の AI モデル

| 機能 | 技術 |
|------|------|
| 作曲生成 | Transformer ベース 自己回帰音楽モデル |
| スタイル転送 | 参照楽曲のスタイルを学習して新曲生成 |
| 楽器配置 | MIDI 音源 + オーケストラ編成ルール |
| 感情分類 | valence/arousal モデルでテンポ・調性を決定 |
| 楽譜変換 | MIDI → MusicXML → PDF (LilyPond) |

### 対応ジャンル / スタイル (主要)
Epic Orchestral / Fantasy / Sci-Fi / Drama / Action / Peaceful / Jazz / Rock /
Electronic / Corporate / Ambient / Wedding / Hip-Hop / Classical

### 著作権モデル (重要)
| プラン | 楽曲著作権 | 商用利用 |
|--------|-----------|---------|
| Free | AIVA 保有 | 不可 |
| Standard | 50% ユーザー / 50% AIVA | 一部可 |
| Pro | 100% ユーザー | 完全可 |
| Enterprise | 100% ユーザー | API + 完全可 |

### 自分株式会社での活用可能性
- AI 大学 e-ラーニング動画の BGM 自動生成 (著作権フリー)
- LP・プロダクト紹介動画のオリジナル BGM
- 週次レポート Podcast の OP/ED テーマ音楽
- ゲーミフィケーション機能の インゲーム BGM

### Suno / Udio との違い
- AIVA: 楽器 BGM 特化 / 著作権明確 / 楽譜出力 / プロ品質
- Suno / Udio: 歌声付き / プロンプト入力 / カジュアル用途$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 207→208社化: AIVA 追加',
  'PS#3 S57。AIVA (AI 作曲 / 世界初 SACEM 登録 AI アーティスト / ゲーム・映画・広告音楽生成 / 著作権 100% ユーザー保有 Pro / MIDI + 楽譜出力 / API 提供 / 8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
