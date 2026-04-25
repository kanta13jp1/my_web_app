-- PS#3 S59: AI大学 211→212社化 — Soundraw 追加
-- Soundraw: AI 音楽生成 / ムード・テンポ・楽器 GUI 指定 / 無制限生成 / 著作権フリー / Premiere Pro 統合

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'soundraw',
  'overview',
  'Soundraw — AI 音楽生成 (ムード/テンポ/楽器 GUI 指定 / 無制限生成 / 著作権フリー / Premiere Pro 統合)',
  $$## Soundraw — AI 音楽生成プラットフォーム

**カテゴリ**: AI Music Generation / Content Creator Tools / Royalty-Free Music
**設立**: 2020年 / 本社: 東京 (日本)
**特徴**: ムード・テンポ・楽器・長さを GUI で指定して AI 音楽を無制限生成
**ユーザー**: YouTuber / Streamer / 映像クリエイター / 広告制作者
**評価**: 8/9

### 概要
Soundraw は**クリエイター向け AI 音楽生成プラットフォーム**。ムード (Happy / Cinematic / Dark など)・テンポ (BPM)・楽器・曲の長さをドロップダウンで指定するだけで、AI が著作権フリーの楽曲を即座に生成する。生成回数は無制限で、気に入った曲の長さやセクション構成をリアルタイム編集できる。Adobe Premiere Pro との公式統合により、映像編集ワークフローにシームレスに組み込める。

### 主な特長
- **無制限生成**: プランに応じて何曲でも AI 生成可能 (クレジット制ではない)
- **GUI カスタマイズ**: ムード / ジャンル / テンポ / 長さ / 楽器編成をスライダーで即調整
- **リアルタイム編集**: イントロ・サビ・アウトロの長さをドラッグで変更
- **著作権フリー**: 全楽曲が商用利用 OK (YouTube / Twitch / 広告 / SNS)
- **Premiere Pro プラグイン**: Adobe CC から直接 Soundraw にアクセスして楽曲挿入
- **カスタムカット**: 動画の長さに合わせて楽曲を自動トリミング

### 競合との差別化
Mubert: ストリーミング BGM / API 向け / Beatoven.ai: 動画シーン感情マッチング / Epidemic Sound: 人間制作の高品質楽曲 (割高) / AIVA: 作曲・楽譜生成 / ゲーム音楽向け

Soundraw の強みは **日本発 × GUI 操作 × 無制限生成 × Premiere Pro 公式統合 × コスパ**。映像クリエイターが「今すぐ BGM が欲しい」ときに最も手軽なソリューション。

### 導入コスト
- **Free**: 生成のみ (ダウンロード不可)
- **Creator**: 月 16.99 USD (無制限ダウンロード / 商用 OK)
- **Artist**: 月 29.99 USD (SoundrawによるArtist認証 / 楽曲の二次配信 OK)
- **Business**: 問い合わせ (チームライセンス / API / ホワイトラベル)$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'soundraw',
  'api',
  'Soundraw API — 楽曲生成 REST API + Premiere Pro プラグイン統合 (Python)',
  $$## Soundraw API / 統合

### 楽曲生成 API (Python)

```python
import requests

# Soundraw API で楽曲生成
url = "https://soundraw.io/api/v1/musics"
headers = {
    "Authorization": "Bearer YOUR_API_KEY",
    "Content-Type": "application/json"
}
payload = {
    "length": 120,              # 秒 (15〜300)
    "tempo": "medium",          # slow / medium / fast / very_fast
    "mood": "happy",            # happy / cinematic / dark / romantic など
    "genre": "pop",             # pop / hip-hop / electronic / jazz など
    "instruments": ["guitar", "piano", "drums"]
}
response = requests.post(url, json=payload, headers=headers)
music = response.json()
music_id = music["id"]
download_url = music["audio_url"]
```

### 楽曲リスト取得

```python
# 生成済み楽曲一覧
list_url = "https://soundraw.io/api/v1/musics"
params = {
    "mood": "cinematic",
    "page": 1,
    "per_page": 20
}
response = requests.get(list_url, params=params, headers=headers)
musics = response.json()["musics"]

for m in musics:
    print(f"{m['title']} — {m['length']}s — {m['audio_url']}")
```

### カスタムカット (動画長さに自動マッチ)

```python
# 動画の長さに合わせてトリミング
cut_url = f"https://soundraw.io/api/v1/musics/{music_id}/cut"
payload = {
    "start": 0,      # 開始秒
    "end": 90        # 終了秒 (動画の長さに合わせる)
}
response = requests.post(cut_url, json=payload, headers=headers)
cut_url = response.json()["audio_url"]
```

### Adobe Premiere Pro プラグイン
```
1. Creative Cloud → Exchange → "Soundraw" プラグインをインストール
2. Premiere Pro → ウィンドウ → エクステンション → Soundraw を開く
3. GUI でムード / ジャンル / テンポを選択 → 生成
4. 楽曲をドラッグ&ドロップでタイムラインに配置
5. 動画の長さに自動でカット調整 (1クリック)
```

### 制限事項
- API は Business プラン以上 (Creator は GUI のみ)
- 生成楽曲の所有権: Soundraw がライセンス保持 (ユーザーに著作権移転なし)
- リアルタイムストリーミング不可 (事前生成型)
- 最大楽曲長: 5分 (300秒)$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'soundraw',
  'models',
  'Soundraw モデル — AI 作曲エンジン + ムード分類 + セクション構成生成',
  $$## Soundraw の AI モデル

| 機能 | 技術 |
|------|------|
| 音楽生成 | 独自 Neural Music Composition (日本発) |
| ムード分類 | 15+ ムード × ジャンル × 楽器の組み合わせ |
| セクション生成 | イントロ / Aメロ / Bメロ / サビ / アウトロを個別生成 |
| テンポ制御 | BPM 指定 + 相対値 (slow/medium/fast/very_fast) |

### 対応ムード (主要)
Happy / Peaceful / Cinematic / Dark / Romantic / Energetic / Dramatic /
Inspiring / Mysterious / Tense / Uplifting / Melancholic / Epic / Playful / Corporate

### 対応ジャンル
Pop / Hip-Hop / Electronic / Jazz / Classical / Rock / R&B / Ambient /
Lo-Fi / Folk / Latin / Trap / House / Future Bass

### 楽器編成カスタマイズ
Guitar / Piano / Drums / Bass / Strings / Brass / Synth /
Flute / Choir / Pad / Arpeggio / Acoustic Guitar / Electric Guitar

### 自分株式会社での活用可能性
- AI 大学 e-ラーニング動画の BGM (ムード: Corporate / Inspiring / Peaceful)
- LP 紹介動画の BGM (Premiere Pro プラグインでワンクリック統合)
- 週次 Podcast の OP/ED 楽曲生成 (毎週新しい楽曲 / 無制限生成プランなら追加コストなし)
- X / SNS 投稿動画の BGM 自動付与 (Creator プラン $16.99/月 → 全コンテンツ対応)

### Mubert / Beatoven.ai との比較
- Soundraw: GUI 操作 / 映像クリエイター向け / Premiere Pro 統合 / 無制限生成
- Mubert: API ストリーミング / アプリ内 BGM / 開発者向け
- Beatoven.ai: 動画感情検出 / ノーコード / シーン自動マッチング$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 211→212社化: Soundraw 追加',
  'PS#3 S59。Soundraw (AI 音楽生成 / ムード・テンポ・楽器 GUI 指定 / 無制限生成 / 著作権フリー / Adobe Premiere Pro 公式統合 / 日本発 / 8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
