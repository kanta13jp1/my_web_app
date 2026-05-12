-- PS#3 S151: AI大学 Cartesia Sonic 音声AI追加 (Issue #1735)
-- Source: NotebookLM 4fb089e8 Cartesia Sonic リアルタイム音声AI

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'cartesia', 'sonic_tts',
  'Cartesia Sonic — リアルタイム低遅延TTS・Voice Cloning・音声AI最前線 (10/10)',
  $$## Cartesia Sonic とは

**Cartesia** が開発する **Sonic** は、**25ms 以下の超低遅延** でリアルタイム音声生成を実現する
次世代 TTS (Text-to-Speech) エンジン。GPT-4o / Claude API と組み合わせることで
**会話型 AI エージェントにリアルタイム音声応答** を付与できる。

## Sonic の主要技術

```
[State Space Model (SSM) アーキテクチャ]
  → Transformer ではなく SSM を採用
  → シーケンス長に対して O(n) 線形計算 (Transformer は O(n²))
  → 長文でも遅延が増加しない → リアルタイム会話に最適

[ストリーミング TTS パイプライン]
  LLM テキスト生成 → Sonic API → 音声チャンク (25ms 以下) → ブラウザ再生
  → 最初のトークンから即時音声化 → 体感遅延を最小化

[Voice Cloning (3秒録音)]
  → わずか 3 秒の音声サンプルで話者の声質を複製
  → ゼロショット音声クローニング
  → 60+ 感情制御パラメータ (興奮度/悲しみ/笑い声 等)
```

## Sonic API 仕様

```python
import cartesia

client = cartesia.Cartesia(api_key="YOUR_API_KEY")

# ストリーミング TTS (WebSocket)
ws = client.tts.websocket()
for chunk in ws.send(
    model_id="sonic-2",
    transcript="こんにちは、自分株式会社へようこそ。",
    voice={
        "mode": "id",
        "id": "YOUR_VOICE_ID",
    },
    output_format={
        "container": "raw",
        "encoding": "pcm_f32le",
        "sample_rate": 44100,
    },
    language="ja",  # 日本語対応
):
    audio_buffer.append(chunk.audio)

ws.close()
```

## Sonic vs 競合比較

| 特性 | Cartesia Sonic | ElevenLabs | OpenAI TTS | Google TTS |
|------|---------------|------------|------------|------------|
| **初回遅延** | **25ms** | ~300ms | ~500ms | ~200ms |
| **日本語品質** | ✅ ネイティブ | ✅ 高品質 | ✅ | ✅ |
| **Voice Cloning** | ✅ 3秒 | ✅ 11秒 | ✗ | ✗ |
| **感情制御** | ✅ 60+ パラメ | ✅ 高精度 | △ | △ |
| **WebSocket API** | ✅ | ✅ | ✗ | ✗ |
| **料金** | $0.065/1K文字 | $0.30/1K文字 | $0.015/1K文字 | $0.016/1K文字 |
| **リアルタイム特化** | **最優秀** | 普通 | 普通 | 普通 |

## 自分株式会社での活用シナリオ

```
1. AI アシスタント音声応答:
   → Claude API (テキスト生成) + Cartesia Sonic (音声変換)
   → Supabase Edge Function: ai-assistant EF に Sonic API コール追加
   → Flutter Web: js.callMethod('playAudio', [base64AudioChunk])

2. パーソナルAI Morning Podcast (Issue #924):
   → daily-report EF が Supabase からデータ集約
   → Claude が朝のサマリー生成
   → Cartesia Sonic が 3 分音声ポッドキャスト自動生成
   → Firebase Storage → PWA で再生

3. AI大学 音声講義:
   → ai-university-update.yml が新しいコンテンツ生成時に
   → Sonic API で講義音声を自動生成 (NotebookLM Audio Overview の代替)
   → Supabase Storage に保存 → AI大学ページで再生

4. NotebookLM Audio Overview の自社実装:
   → NotebookLM の Audio Overview 機能を Sonic で代替
   → 自社データ (Supabase) から直接 Podcast 生成
   → コスト比較: NotebookLM ≒ Sonic $0.065/1K文字
```

## 音声 AI の応用パターン (2026 最前線)

```
Voice AI Stack 2026:
  STT (入力): Whisper (OpenAI) / Deepgram / AssemblyAI
  LLM (処理): Claude 3.7 / GPT-4o / Gemini 2.0
  TTS (出力): Cartesia Sonic / ElevenLabs / PlayHT

  → 3 層を繋ぐ "Voice Pipeline" で完全音声会話 AI を構築

Voice Cloning ユースケース:
  ・カスタマーサポート: ブランド固有の声で対応
  ・教育: 教師の声で个別指导
  ・アクセシビリティ: 読み上げ支援の自然化
```

## 自分株式会社 AI 大学での位置づけ

- **学部**: 音声AI学部 (audio_ai / sort_order 18)
- **学科**: TTS・音声合成学科 (sonic_tts)
- **関連プロバイダー**: ElevenLabs / Whisper / Deepgram / PlayHT
- **実用的示唆**: 25ms 遅延は Flutter Web + WebSocket で実現可能。
  ElevenLabs より 4.6x 安価で同等品質 → AI アシスタント音声化の最優先候補
$$,
  'https://cartesia.ai/sonic',
  '2026-01-01',
  100
)
ON CONFLICT (provider, category) DO NOTHING;
