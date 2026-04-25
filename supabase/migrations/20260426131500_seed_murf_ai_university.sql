-- PS#3 S54: AI大学 201→202社化 — Murf 追加
-- Murf: AI 音声生成 (TTS) / 120+ 声 / スタジオ品質 / $10M / API 提供

INSERT INTO ai_university_content (provider_id, section, content_md, display_order)
VALUES
(
  'murf_ai',
  'overview',
  $md$## Murf — AI 音声生成 (Text-to-Speech)

**カテゴリ**: AI Voice Generation / Text-to-Speech
**設立**: 2020年 / 本社: サンフランシスコ
**調達**: $10M (Elevation Capital)
**評価**: ★8/9

### 概要
Murf はスタジオ品質の AI 音声を生成できる Text-to-Speech (TTS) プラットフォーム。120+ 言語・アクセントの 200+ 種類の音声から選べ、プレゼン動画・広告ナレーション・e-ラーニングコンテンツなどに活用できる。Canva との統合や API 提供でクリエイターからエンタープライズまで幅広く対応する。

### 主な特長
- **200+ AI 音声**: 120+ 言語・アクセント対応 / 年齢層・性格・トーン別に豊富
- **スタジオ品質**: 自然な抑揚・ブレスコントロール / ロボット感なし
- **ビデオ同期**: テキスト変更が即座に動画のタイムラインに反映
- **音声クローン (Voice Clone)**: 自分の声を AI で複製してナレーション
- **Canva 統合**: Canva デザインに直接 AI ナレーション追加
- **多言語日本語対応**: 日本語 AI 音声も提供

### 競合との差別化
| ツール | 特徴 |
|--------|------|
| **ElevenLabs** | 最高品質・感情表現 / 声クローン特化 / 高価格帯 |
| **Resemble AI** | リアルタイム音声変換 / ゲーム・会話 AI |
| **Play.ht** | 900+ 音声・Web リーダー特化 |
| **Amazon Polly** | AWS 統合・大量処理向け / 企業向け |

Murf の強みは **Canva 統合 × ビデオ同期 × コスパの高い多機能プラン**。クリエイター向けの使いやすさが際立つ。

### 導入コスト
- **Free**: 10 分/月・ウォーターマーク付き
- **Creator**: $19/月 (24 時間/月・商用利用・ダウンロード可)
- **Business**: $26/月 (無制限・Voice Clone・API アクセス)
- **Enterprise**: 問い合わせ (SSO / 専用サポート / SLA)
$md$,
  1
),
(
  'murf_ai',
  'api',
  $md$## Murf API / 統合

### Murf API (REST)
テキストを音声ファイル (MP3/WAV) に変換する REST API。

```python
import requests

url = "https://api.murf.ai/v1/speech/generate"
headers = {
    "api-key": "YOUR_API_KEY",
    "Content-Type": "application/json"
}
payload = {
    "voiceId": "ja-JP-rohan",   # 日本語 AI 音声
    "text": "自分株式会社のAI大学へようこそ。",
    "style": "Conversational",
    "rate": 0,       # 話速 (-50 〜 +50%)
    "pitch": 0,      # ピッチ (-50 〜 +50%)
    "sampleRate": 48000,
    "format": "MP3",
    "channelType": "MONO"
}
response = requests.post(url, json=payload, headers=headers)
audio_url = response.json()["audioFile"]
```

**対応音声フォーマット**: MP3 / WAV / FLAC
**最大文字数**: 1 リクエスト 3000 文字

### Canva 統合
- Canva アプリマーケットプレイスから直接使用
- デザイン上のテキストをワンクリックで AI ナレーション化

### Zapier / Make 連携
- Google Docs テキスト → 音声ファイル自動生成 → Drive 保存
- Notion ページ → ポッドキャスト音声自動生成

### 制限事項
- Voice Clone は Business プラン以上
- API レート制限: 60 リクエスト/分 (Creator プラン)
$md$,
  2
),
(
  'murf_ai',
  'models',
  $md$## Murf の AI モデル

| 用途 | 技術 |
|------|------|
| Text-to-Speech | 独自 Neural TTS モデル |
| Voice Clone | 独自音声複製モデル (5 分のサンプルで生成) |
| 感情・スタイル制御 | 独自スタイル分類モデル |

### 音声スタイル
- **Conversational**: 日常会話・ポッドキャスト
- **Narration**: e-ラーニング・ドキュメンタリー
- **News**: ニュース・アナウンス
- **Promo**: CM・マーケティング
- **Inspirational**: モチベーション・プレゼン

### 自分株式会社での活用可能性
- AI 大学コンテンツの音声ナレーション自動生成 (e-ラーニング化)
- 週次 SNS 投稿動画のナレーション自動化
- 競合分析レポートの Podcast 音声版生成
- Landing Page の音声案内 (アクセシビリティ向上)

### 日本語対応状況
- 日本語 AI 音声: rohan (男性) / keiko (女性) など複数提供
- 日本語の自然さ: ★7/9 (英語 ★9/9 に対して改善余地あり)
$md$,
  3
)
ON CONFLICT (provider_id, section) DO UPDATE
  SET content_md = EXCLUDED.content_md,
      display_order = EXCLUDED.display_order,
      updated_at = NOW();

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 201→202社化: Murf 追加',
  'PS#3 S54。Murf (AI TTS / 200+ AI 音声 / 120+ 言語 / スタジオ品質 / Voice Clone / Canva 統合 / API 提供 / $10M / ★8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
