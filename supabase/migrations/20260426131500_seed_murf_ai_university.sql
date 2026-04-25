-- PS#3 S54 fix (PS#1 S46): 20260426131500 — Murf AI大学 seed (provider/category/content schema)
-- Murf: AI 音声生成 (TTS) / 200+ 音声 / Voice Clone / Canva統合 / 10M USD

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'murf_ai',
  'overview',
  'Murf — AI 音声生成 TTS (200+音声 / Voice Clone / Canva統合 / 10M USD)',
  $$## Murf — AI 音声生成 (Text-to-Speech)

**カテゴリ**: AI Voice Generation / Text-to-Speech
**設立**: 2020年 / 本社: サンフランシスコ
**調達**: 10M USD (Elevation Capital)
**評価**: 8/9

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
ElevenLabs: 最高品質・感情表現 / 声クローン特化 / 高価格帯 / Resemble AI: リアルタイム音声変換・ゲーム向け / Play.ht: 900+ 音声・Web リーダー特化 / Amazon Polly: AWS統合・大量処理向け

Murf の強みは **Canva 統合 × ビデオ同期 × コスパの高い多機能プラン**。クリエイター向けの使いやすさが際立つ。

### 導入コスト
- **Free**: 10 分/月・ウォーターマーク付き
- **Creator**: 月 19 USD (24 時間/月・商用利用・ダウンロード可)
- **Business**: 月 26 USD (無制限・Voice Clone・API アクセス)
- **Enterprise**: 問い合わせ (SSO / 専用サポート / SLA)$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'murf_ai',
  'api',
  'Murf — API・統合 (REST API / Python SDK / Canva / Zapier / Make)',
  $$## Murf API / 統合

### Murf API (REST)
テキストを音声ファイル (MP3/WAV) に変換する REST API。エンドポイント: POST https://api.murf.ai/v1/speech/generate

主なパラメータ: voiceId (例: ja-JP-rohan) / text (最大 3000 文字) / style (Conversational/Narration/News/Promo/Inspirational) / rate (-50〜+50%) / pitch / sampleRate / format (MP3/WAV/FLAC) / channelType (MONO/STEREO)

認証: api-key ヘッダー

### Canva 統合
- Canva アプリマーケットプレイスから直接使用
- デザイン上のテキストをワンクリックで AI ナレーション化

### Zapier / Make 連携
- Google Docs テキスト → 音声ファイル自動生成 → Drive 保存
- Notion ページ → ポッドキャスト音声自動生成

### 制限事項
- Voice Clone は Business プラン以上
- API レート制限: 60 リクエスト/分 (Creator プラン)$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'murf_ai',
  'models',
  'Murf — AIモデル (Neural TTS / Voice Clone / 5スタイル / 日本語 rohan・keiko)',
  $$## Murf の AI モデル

Text-to-Speech: 独自 Neural TTS モデル / Voice Clone: 独自音声複製モデル (5 分のサンプルで生成) / 感情・スタイル制御: 独自スタイル分類モデル

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
- 日本語の自然さ: 7/9 (英語 9/9 に対して改善余地あり)$$,
  NULL,
  NULL,
  202
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 201→202社化: Murf 追加',
  'PS#3 S54 (PS#1 S46 fix)。Murf (AI TTS / 200+ AI 音声 / 120+ 言語 / スタジオ品質 / Voice Clone / Canva 統合 / API 提供 / 10M USD / 8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
