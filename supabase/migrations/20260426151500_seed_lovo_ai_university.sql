-- PS#3 S57: AI大学 206→207社化 — LOVO (Genny) 追加
-- LOVO: AI 音声 + 動画エディタ統合 / 500+ AI 音声 / 100+ 言語 / 7M USD 調達

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'lovo_ai',
  'overview',
  'LOVO (Genny) — AI 音声 + 動画エディタ統合 (500+ 音声 / 100+ 言語 / 7M USD)',
  $$## LOVO (Genny) — AI 音声 & 動画エディタ統合

**カテゴリ**: AI Text-to-Speech / Video Editor / Content Creation
**設立**: 2019年 / 本社: サンフランシスコ (カリフォルニア)
**調達**: 7M USD (シリーズ A)
**旗艦製品**: Genny (AI 動画エディタ統合型 TTS ツール)
**評価**: 8/9

### 概要
LOVO は AI 音声生成 (TTS) と動画編集を統合した**オールインワン コンテンツ制作プラットフォーム**。旗艦製品 Genny は AI ライター + TTS + 動画エディタを 1 つの画面で完結させる。500+ AI 音声・100+ 言語対応で、e-ラーニング・マーケティング動画・ポッドキャストなど幅広いコンテンツに対応する。

### 主な特長
- **500+ AI 音声**: 100+ 言語・アクセント / 年齢・性格別に豊富
- **感情制御**: 14 種類の感情スタイル (excited / serious / sad / angry など)
- **Genny 動画エディタ**: テキスト→ナレーション→動画完成を 1 ツールで
- **AI ライター統合**: GPT ベースのスクリプト自動生成 → 即音声化
- **音声クローン**: 自分の声を複製 (Instant Clone / Professional Clone)
- **API**: REST API + WordPress / Zapier 統合

### 競合との差別化
ElevenLabs: 最高品質 / API 特化 / Murf: Canva 統合 / プレゼン向け / WellSaid: エンタープライズ品質 / 倫理的クローン / Pictory: 動画特化 / TTS はサブ機能

LOVO の強みは **TTS + 動画エディタ + AI ライター を統合した唯一のプラットフォーム**。コンテンツチームが 1 ツールで動画完成まで持っていける。

### 導入コスト
- **Free**: 20 分/月・5 ダウンロード
- **Basic**: 月 19 USD (毎月 2h・ウォーターマークなし)
- **Pro**: 月 29 USD (無制限・AI ライター・音声クローン)
- **Enterprise**: 問い合わせ (API / SSO / カスタム音声)$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'lovo_ai',
  'api',
  'LOVO API — TTS REST API + 感情制御 + 音声クローン (Python SDK)',
  $$## LOVO API / 統合

### TTS REST API

```python
import requests

url = "https://api.lovo.ai/v1/convert"
headers = {
    "X-Api-Key": "YOUR_API_KEY",
    "Content-Type": "application/json"
}
payload = {
    "speaker_id": "...",          # 声優 ID
    "content": [
        {
            "text": "AI大学へようこそ。LOVOが生成する音声です。",
            "speed": 1,           # 0.5 〜 2.0
            "pause_before": 0
        }
    ]
}
response = requests.post(url, json=payload, headers=headers)
audio_url = response.json()["urls"][0]
```

### 声優 ID 一覧取得

```python
speakers_url = "https://api.lovo.ai/v1/speakers"
response = requests.get(speakers_url, headers={"X-Api-Key": "YOUR_API_KEY"})
speakers = response.json()
# 例: [{"id": "xx", "name": "Aiko", "locale": "ja-JP", "gender": "f"}, ...]
```

### 感情制御

```python
# 感情スタイルを指定
payload = {
    "speaker_id": "...",
    "content": [{"text": "すごい！", "emotion": "excited", "emotion_strength": 0.8}]
}
```

### WordPress プラグイン
- 記事本文を自動音声化してページに埋め込み
- SEO 効果 + アクセシビリティ向上

### 制限事項
- 音声クローンは Pro プラン以上
- API は Enterprise プランのみ
- 最大 5000 文字/リクエスト$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'lovo_ai',
  'models',
  'LOVO モデル — 感情制御 Neural TTS + Instant Voice Clone + Genny 動画統合',
  $$## LOVO の AI モデル

| 機能 | 技術 |
|------|------|
| Text-to-Speech | 独自 Neural TTS (500+ 音声 / 100+ 言語) |
| 感情制御 | 14 種類の感情スタイル分類モデル |
| Instant Clone | 30 秒サンプルで声クローン |
| Professional Clone | 高品質スタジオ収録ベースクローン |
| AI ライター | GPT ベース スクリプト生成 |

### 感情スタイル一覧
excited / serious / sad / angry / cheerful / friendly / calm / newscast / empathetic / documentary / customer-service / sports / meditation / casual

### 自分株式会社での活用可能性
- AI 大学コンテンツの動画ナレーション自動化 (Genny 統合で動画完成まで)
- マーケティング動画の多言語展開 (100+ 言語対応)
- LP 音声案内 → ユーザー滞在時間向上
- 週次レポートの Podcast 変換 (感情制御でナチュラルな読み上げ)

### 日本語対応状況
- 日本語: 7/9 (Aiko など日本語 AI 音声複数提供)
- 感情制御の日本語精度: 英語より制限あり$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 206→207社化: LOVO (Genny) 追加',
  'PS#3 S57。LOVO / Genny (AI 音声 + 動画エディタ統合 / 500+ AI 音声 / 100+ 言語 / 14感情スタイル / 音声クローン / API 提供 / 7M USD 調達 / 8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
