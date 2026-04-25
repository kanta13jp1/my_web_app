-- PS#3 S56 fix: 20260426141500 — Speechify AI大学 seed (provider/category/content schema)
-- Speechify: AI 読み上げ & 音声クローン / 20M+ ユーザー / 30+ 言語 / 76M USD 調達

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'speechify',
  'overview',
  'Speechify — AI 読み上げ & 音声クローン SaaS (20M+ ユーザー / 著名人ボイス / 76M USD)',
  $$## Speechify — AI 読み上げ & 音声クローン SaaS

**カテゴリ**: AI Text-to-Speech / Reading Assistant / Voice Cloning
**設立**: 2016年 / 本社: ロサンゼルス (カリフォルニア)
**調達**: 76M USD (Tiger Global / OpenAI Startup Fund)
**ユーザー数**: 20M+ (2024年)
**評価**: 8/9

### 概要
Speechify は文書・PDF・Web ページを AI 音声で読み上げる SaaS プラットフォーム。ディスレクシア支援ツールとして創業し、現在は企業向けコンテンツナレーション・音声クローン・API サービスに進化。OpenAI の Sam Altman が個人投資家として参加したことでも注目を集めた。

### 主な特長
- **読み上げエンジン**: PDF/EPUB/Web/DOCX/画像テキストを最大 9x 速度で読み上げ
- **著名人音声**: Snoop Dogg / Gwyneth Paltrow / Matthew McConaughey など有名人ボイス
- **30+ 言語**: 英語・日本語・スペイン語・フランス語など多言語対応
- **音声クローン (Studio)**: 自分の声を複製してナレーション生成
- **Chrome 拡張 / iOS / Android / Mac**: 全プラットフォーム対応
- **Speechify API**: TTS API + AI 音声クローン API を開発者向けに提供

### 競合との差別化
ElevenLabs: 最高品質・感情豊か / コンテンツ制作特化 / Murf: プレゼン動画・Canva 統合 / ビジネス向け / NaturalReader: 教育機関向け / 安価 / Amazon Polly: AWS 統合・大量バッチ処理

Speechify の強みは **読み上げ用途特化 × 著名人ボイス × 20M ユーザーの学習データ × API 提供**。コンシューマー向け読み上げ市場トップシェア。

### 導入コスト
- **Free**: 基本読み上げ (速度制限あり)
- **Premium**: 月 11.58 USD (高速・多言語・著名人ボイス)
- **Studio**: 月 29 USD (音声クローン / コンテンツ制作向け)
- **API**: 従量課金 (0.000085 USD/文字〜)$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'speechify',
  'api',
  'Speechify API — TTS REST + Streaming + 音声クローン API (Python SDK)',
  $$## Speechify API / 統合

### Speechify TTS API

```python
import requests

url = "https://api.sws.speechify.com/v1/audio/speech"
headers = {
    "Authorization": "Bearer YOUR_API_KEY",
    "Content-Type": "application/json"
}
payload = {
    "input": "<speak>AI大学へようこそ。</speak>",
    "voice_id": "shimmer",
    "audio_format": "mp3",
    "language": "ja-JP"
}
response = requests.post(url, json=payload, headers=headers)
with open("output.mp3", "wb") as f:
    f.write(response.content)
```

### Streaming API (リアルタイム)

```python
with requests.post(url, json=payload, headers=headers, stream=True) as r:
    for chunk in r.iter_content(chunk_size=4096):
        audio_player.write(chunk)
```

### 音声クローン API

```python
clone_url = "https://api.sws.speechify.com/v1/voices"
files = {"sample": open("voice_sample.mp3", "rb")}
data = {"name": "My Custom Voice", "gender": "female"}
response = requests.post(clone_url, files=files, data=data, headers=headers)
voice_id = response.json()["id"]
```

### 利用可能音声 (主要)
- **著名人**: snoop-dogg / gwyneth-paltrow / matthew-mcconaughey など
- **日本語**: ja-JP-Kenji / ja-JP-Yuki など

### 制限事項
- 音声クローンは Studio プラン以上
- SSML サポートあり
- 最大 5000 文字/リクエスト$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'speechify',
  'models',
  'Speechify モデル — Neural TTS + 読み上げ最適化 + 音声クローン技術',
  $$## Speechify の AI モデル

| 機能 | 技術 |
|------|------|
| Text-to-Speech | 独自 Neural TTS (多言語・自然イントネーション) |
| 読み上げ最適化 | 速度 1x-9x / 音声品質劣化なし |
| Voice Cloning | 独自ゼロショット声クローン |
| 著名人ボイス | 同意取得済みの声クローン |
| 言語検出 | 自動言語識別 (30+ 言語) |

### 自分株式会社での活用可能性
- AI 大学コンテンツの「聴く AI 大学」機能 → 移動中に学習可能
- LP・ランディングページの音声案内 (アクセシビリティ向上)
- 週次レポートの Podcast 音声版自動生成
- ユーザー向け手順書・マニュアルの音声読み上げ機能

### 日本語対応状況
- 日本語: 7/9 (英語 9/9)
- 日本語固有名詞の読み精度: 要カスタム辞書$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 204→205社化: Speechify 追加',
  'PS#3 S56。Speechify (AI 読み上げ & 音声クローン / 20M+ ユーザー / 30+ 言語 / 著名人ボイス / OpenAI Startup Fund / 76M USD 調達 / 8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
