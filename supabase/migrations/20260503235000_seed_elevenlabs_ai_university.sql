-- PS#3 S151: AI大学 ElevenLabs 音声AI追加 (Issue #1735)
-- Source: NotebookLM 音声AI学科 ElevenLabs Voice Design

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'elevenlabs', 'voice_design',
  'ElevenLabs — 多言語TTS・Voice Design・感情制御・音声クローニング完全ガイド (10/10)',
  $$## ElevenLabs とは

**ElevenLabs** は 2022 年設立のニューヨーク発 AI 音声スタートアップ。
**最高品質の多言語 TTS** と **感情豊かな Voice Cloning** で知られ、
Podcast / YouTube / audiobook / 音声 AI 分野のデファクトスタンダード。

## 主要機能

```
[テキスト読み上げ (TTS)]
  ・29 言語対応 (日本語含む)
  ・Turbo v2.5: 高速低遅延モード (~300ms)
  ・Multilingual v2: 最高品質モード
  ・感情スタイル制御 (narration / newscast / excited / cheerful 等)

[Voice Cloning]
  ・Instant Clone: 11 秒の音声サンプルで声質複製
  ・Professional Clone: 3 時間の高品質データで商業用声優レベル
  ・Voice Library: 3000+ コミュニティ公開ボイス

[Voice Design (ゼロショット)]
  ・テキスト記述から新しい声を生成
  → "A warm and cheerful Japanese female voice in her 30s"
  → 即座に音声合成

[Projects (長文コンテンツ)]
  ・章単位でのオーディオブック生成
  ・複数スピーカー対応 (会話形式の Podcast 自動生成)
  ・音声・テキスト完全同期 (タイムスタンプ付き)
```

## ElevenLabs API (Python)

```python
from elevenlabs import ElevenLabs, VoiceSettings

client = ElevenLabs(api_key="YOUR_API_KEY")

# 基本 TTS
audio = client.text_to_speech.convert(
    text="自分株式会社のAI大学へようこそ。",
    voice_id="JBFqnCBsd6RMkjVDRZzb",  # Rachel (日本語対応)
    model_id="eleven_turbo_v2_5",
    voice_settings=VoiceSettings(
        stability=0.5,
        similarity_boost=0.75,
        style=0.4,
        use_speaker_boost=True
    ),
)
play(audio)

# ストリーミング TTS
for chunk in client.text_to_speech.convert_as_stream(
    text="長い文章をリアルタイムで音声化します...",
    voice_id="JBFqnCBsd6RMkjVDRZzb",
    model_id="eleven_turbo_v2_5",
):
    if isinstance(chunk, bytes):
        audio_buffer.write(chunk)
```

## 料金体系

| プラン | 文字数/月 | 料金 | 主用途 |
|--------|----------|------|--------|
| **Free** | 10,000 | $0 | 個人実験 |
| **Starter** | 30,000 | $5 | 小規模プロジェクト |
| **Creator** | 100,000 | $22 | Podcast・YouTube |
| **Pro** | 500,000 | $99 | 商業利用 |
| **Scale** | 2,000,000 | $330 | エンタープライズ |

## 音声クローニング倫理とガイドライン

```
ElevenLabs の安全対策:
  ・同意なしの声複製は TOS 違反
  ・プロフェッショナルクローニング: 本人の音声同意書必須
  ・AI Speech Classifier: 合成音声の検出ツール公開
  ・Watermarking: 生成音声への透かし埋め込み (2025-)

自分株式会社での倫理適用:
  → ユーザーの声を本人同意なしにクローニングしない
  → AI生成音声には "AI音声" の明示ラベルを付与
  → ElevenLabs Usage Policy を AI_CHARACTER_PRINCIPLES.md に反映
```

## 自分株式会社での活用シナリオ

```
1. 日次AIポッドキャスト (Issue #924):
   → Claude が朝のサマリー生成 (Supabase schedule-hub から取得)
   → ElevenLabs "Multilingual v2" で日本語音声生成
   → S3/Firebase Storage 保存 → PWA ホーム画面で自動再生
   → 費用試算: 1日 500文字 × 30日 = 15,000文字/月 → Free プランで十分

2. AI大学 音声講義自動生成:
   → ai_university_content の各コンテンツを章ごとに音声化
   → ElevenLabs Projects API で audiobook 形式生成
   → NotebookLM Audio Overview の完全代替実装

3. カスタマーサポート音声:
   → Supabase EF: reply-support-request に音声応答オプション追加
   → ブランドボイス (自分株式会社固有の声) で顧客対応
   → 費用: Starter $5/月 で 30,000文字 → 月1000件応答可能

4. Replit LP 音声デモ (Issue #1737 関連):
   → Replit の新機能説明を ElevenLabs で音声化
   → LP に "聴いてみる" ボタン追加
   → Engagement 率向上 (読む → 聴く への拡張)
```

## ElevenLabs vs Cartesia Sonic 使い分け

| シナリオ | 推奨 | 理由 |
|----------|------|------|
| リアルタイム会話 AI | **Cartesia Sonic** | 25ms vs 300ms |
| Podcast / 長文コンテンツ | **ElevenLabs** | Projects 機能・高品質 |
| Voice Cloning 商業利用 | **ElevenLabs** | Professional Clone |
| コスト最優先 | **Cartesia** | $0.065 vs $0.30/1K文字 |
| 感情豊かな表現 | **ElevenLabs** | スタイル制御が豊富 |

## 自分株式会社 AI 大学での位置づけ

- **学部**: 音声AI学部 (audio_ai / sort_order 18)
- **学科**: Voice Design・多言語TTS 学科 (voice_design)
- **関連プロバイダー**: Cartesia Sonic / Whisper / D-ID (動画AI) / Hedra
- **実用的示唆**: Free プラン (10K文字/月) で AI大学コンテンツの音声デモを十分実装可能。
  Professional Clone を使えば自分株式会社のオリジナルブランドボイス確立も可能。
$$,
  'https://elevenlabs.io',
  '2026-01-01',
  101
)
ON CONFLICT (provider, category) DO NOTHING;
