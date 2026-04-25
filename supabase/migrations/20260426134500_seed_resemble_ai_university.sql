-- PS#3 S55 fix (PS#1 S46): 20260426134500 — Resemble AI 大学 seed (provider/category/content schema)
-- Resemble AI: リアルタイム音声クローン / 50ms以下 / Deepfake Detection / 8M USD YC S20

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'resemble_ai',
  'overview',
  'Resemble AI — リアルタイム音声クローン (50ms以下 / Deepfake Detection / 8M USD YC S20)',
  $$## Resemble AI — リアルタイム音声クローン & 合成

**カテゴリ**: Real-Time Voice Cloning / Text-to-Speech / Deepfake Detection
**設立**: 2019年 / 本社: サンフランシスコ (カリフォルニア)
**調達**: 8M USD (シード / Y Combinator S20)
**特許技術**: リアルタイム声クローン (50ms 以下レイテンシ)
**評価**: 8/9

### 概要
Resemble AI はリアルタイム音声クローンを最大の特徴とする SaaS プラットフォーム。テキスト入力から 50ms 以下で合成音声を返す低遅延 API が強みで、ゲームのプレイヤー音声生成・会話 AI アシスタント・カスタマーサービスボットなど、応答速度が命のユースケースに特化している。また、自社技術で Deepfake 音声検出サービスも提供し、音声セキュリティ側面も網羅する。

### 主な特長
- **50ms 以下レイテンシ**: WebSocket ストリーミング API でリアルタイム合成
- **感情・スタイル制御**: API で感情強度・話速・ピッチをリアルタイム変更
- **声クローン**: 5 分のサンプルで高品質な声クローン生成
- **Deepfake Detection**: 合成音声か本物かを判定する逆方向 API
- **多言語**: 英語・日本語・スペイン語など対応
- **エンタープライズ**: オンプレミス展開 / 音声データの自社所有保証

### 競合との差別化
ElevenLabs: 最高品質・感情豊か / 非リアルタイム中心 / Murf: コンテンツ制作向け / Canva 統合 / Coqui: OSS・ローカル実行 / リアルタイム非対応 / Cartesia: Sonic モデル 80ms / スタートアップ競合

Resemble の強みは **50ms リアルタイム × Deepfake 検出 × 音声データ所有保証**。ゲーム・会話 AI・音声セキュリティの 3 領域をカバーする唯一のプラットフォーム。

### 導入コスト
- **Pay-as-you-go**: 0.006 USD/秒
- **Professional**: 99 USD/月 (200 万文字・Deepfake Detection 付き)
- **Enterprise**: 問い合わせ (オンプレミス / SLA / 音声データ完全所有)$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'resemble_ai',
  'api',
  'Resemble AI — Python SDK・WebSocket (リアルタイムストリーミング / Deepfake Detection API)',
  $$## Resemble AI API / 統合

### Python SDK
pip install resemble でインストール。Resemble.api_key("YOUR_KEY") で認証後、Resemble.v2.clips.create_sync(project_uuid, voice_uuid, body, sample_rate, output_format) で音声生成。戻り値の audio_src から MP3/WAV をダウンロード。

### WebSocket ストリーミング (リアルタイム 50ms 以下)
wss://app.resemble.ai/ws/api/v1/stream に接続し、token / voice_uuid / data / sample_rate を JSON 送信。サーバーから音声チャンクが逐次届き、b"END" で終了。初回チャンクまで 50ms 以下。

### 声クローン作成
Resemble.v2.voices.create(name, dataset_url) で 5 分以上のサンプル ZIP を渡すと voice_uuid が返る。以降そのボイスで全 API 利用可能。

### Deepfake Detection API
Resemble.v2.detect.create(audio_url) で音声 URL を渡すと is_deepfake (True/False) と confidence (0.0-1.0) が返る。精度 97.8% (自社ベンチマーク)。

### 制限事項
- 声クローンは 5 分以上の高品質サンプルが必要
- ストリーミング API は Professional プラン以上
- 日本語のサンプルは英語より多め (10 分推奨)$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'resemble_ai',
  'models',
  'Resemble AI — 技術 (Chroma Neural TTS / WebSocket 50ms / Deepfake 97.8% / MOS 4.2)',
  $$## Resemble AI の技術

Text-to-Speech: 独自 Neural TTS (Chroma モデル) / Voice Cloning: 独自ゼロショット / フューショット クローニング / Real-time Streaming: WebSocket + チャンク分割合成 / Deepfake Detection: 独自バイナリ分類モデル / 感情制御: SSML 拡張 + API パラメータ

### パフォーマンス指標
- **レイテンシ**: 50ms 以下 (WebSocket ストリーミング初回チャンク)
- **品質**: MOS スコア 4.2/5.0 (English)
- **声クローン精度**: EER 3.2% (話者識別誤り率)
- **Deepfake 検出精度**: 97.8% (自社ベンチマーク)

### 自分株式会社での活用可能性
- 会話 AI アシスタントへの低遅延音声合成統合 (50ms 以下でネイティブ体験)
- ゲーミフィケーション機能でのプレイヤー固有音声生成
- 音声コンテンツの Deepfake 検出・認証 (セキュリティ強化)
- 自社キャラクターの声クローン → LP 音声案内

### 日本語対応状況
- 日本語対応: 7/9 (英語 9/9 に対して改善余地あり)
- 日本語声クローン: サンプル 10 分以上推奨$$,
  NULL,
  NULL,
  204
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 203→204社化: Resemble AI 追加',
  'PS#3 S55 (PS#1 S46 fix)。Resemble AI (リアルタイム音声クローン / 50ms 以下 WebSocket ストリーミング / Deepfake 検出 / 5分サンプルで声クローン / 8M USD YC S20 / 8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
