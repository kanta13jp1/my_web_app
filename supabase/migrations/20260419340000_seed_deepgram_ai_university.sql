-- PS版#3 Session 4: Deepgram — 音声 AI 専門プロバイダー (STT/TTS/Voice Agent)
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'deepgram',
  'overview',
  'Deepgram — 音声 AI 特化プロバイダー (STT / TTS / Voice Agent)',
  E'## Deepgram とは\n\nDeepgram は 2015 年に設立されたサンフランシスコ発の **音声 AI 専門企業**。\n独自の深層学習アーキテクチャで業界最速・最高精度の **音声認識 (STT)・音声合成 (TTS)・Voice Agent API** を提供。\n\n「AI で音声コミュニケーションをより豊かにする」をミッションに掲げ、NVIDIA・Twilio・NASA など大手企業への導入実績を持つ。\n\n## 主な特徴\n\n- **Nova-3 系**: 業界最高精度・多言語対応の最新 STT モデル群\n- **Flux**: 会話音声認識に特化した Voice Agent 向けモデル\n- **$200 無料クレジット**: クレジットカード不要で即試用可能\n- **リアルタイム + バッチ**: ストリーミング・事前録音両対応\n- **スピーカー分離 (Diarization)**: 会議録音の話者特定に対応\n\n## 資金調達\n\n- 累計調達: 約 1 億ドル以上\n- 出資: Tiger Global、Madrona Venture Group ほか\n- エンタープライズ顧客: NVIDIA・Twilio・Zoom・NASA',
  '2026-04-19'
),
(
  'deepgram',
  'models',
  'Deepgram モデル一覧',
  E'## Speech-to-Text (STT)\n\n### Nova-3（最新推奨）\n- **精度**: 業界最高水準\n- **言語**: 多言語対応（英語・日本語ほか）\n- **料金**: $0.0052/min（Nova-3 Multilingual）\n- **特徴**: 医療用特化版 Nova-3 Medical も提供\n\n### Nova-2（安定版）\n- **料金**: $0.0043/min（一般） / $0.0045/min（医療）\n- **強み**: 汎用・医療・会話・航空管制の 4 バリアント\n- **ノイズ耐性**: バックグラウンドノイズに強い\n\n### Flux（会話特化）\n- Voice Agent 向けに最適化\n- 低遅延・インタラプション検出対応\n\n## Text-to-Speech (TTS)\n\n| モデル | 特徴 | 料金 |\n|--------|------|------|\n| Aura-2 | 高品質・自然 | $0.0150/1K chars |\n| Aura | 標準品質 | $0.0150/1K chars |\n\n## Voice Agent API\n\n- LLM + STT + TTS を 1 API で統合\n- Flux モデルで超低遅延会話\n- WebSocket / REST 両対応',
  '2026-04-19'
),
(
  'deepgram',
  'api',
  'Deepgram API 使い方',
  E'## Python SDK\n\n```python\nfrom deepgram import DeepgramClient, PrerecordedOptions\n\nclient = DeepgramClient("YOUR_API_KEY")\n\nwith open("audio.mp3", "rb") as audio:\n    response = client.listen.rest.v("1").transcribe_file(\n        {"buffer": audio},\n        PrerecordedOptions(\n            model="nova-2",\n            smart_format=True,\n            language="ja"\n        )\n    )\n\nprint(response.results.channels[0].alternatives[0].transcript)\n```\n\n## リアルタイム STT (WebSocket)\n\n```python\nfrom deepgram import DeepgramClient, LiveTranscriptionEvents, LiveOptions\n\nclient = DeepgramClient("YOUR_API_KEY")\nconnection = client.listen.websocket.v("1")\n\ndef on_message(self, result, **kwargs):\n    transcript = result.channel.alternatives[0].transcript\n    if transcript:\n        print(transcript)\n\nconnection.on(LiveTranscriptionEvents.Transcript, on_message)\noptions = LiveOptions(model="nova-2", language="ja", smart_format=True)\nconnection.start(options)\n```\n\n## TTS\n\n```python\nfrom deepgram import DeepgramClient, SpeakOptions\n\nclient = DeepgramClient("YOUR_API_KEY")\nresponse = client.speak.rest.v("1").save(\n    "output.mp3",\n    {"text": "こんにちは、Deepgramです"},\n    SpeakOptions(model="aura-asteria-en")\n)\n```\n\n## 料金\n\n| API | 料金 |\n|-----|------|\n| Nova-2 STT | $0.0043/min |\n| Nova-3 STT | $0.0052/min |\n| TTS (Aura-2) | $0.0150/1K chars |\n| 無料クレジット | $200（クレカ不要）|',
  '2026-04-19'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
