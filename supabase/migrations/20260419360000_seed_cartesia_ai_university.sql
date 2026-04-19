-- PS版#3 Session 5: Cartesia AI — 状態空間モデルによる超低遅延音声合成
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'cartesia',
  'overview',
  'Cartesia AI — 状態空間モデルで実現する超低遅延リアルタイム TTS',
  E'## Cartesia とは\n\nCartesia は 2023 年に設立されたサンフランシスコ発の音声 AI スタートアップ。\nTransformer ではなく **状態空間モデル (SSM)** ベースの独自アーキテクチャ「Sonic」で業界最速クラスの **135ms 以下の遅延**を実現する TTS を提供。\n\n「音声はリアルタイムでなければ意味がない」という思想のもと、音声エージェント・コールセンター自動化・インタラクティブコンテンツに特化。\n\n## 主な特徴\n\n- **Sonic**: 135ms 以下の超低遅延 TTS（業界最速クラス）\n- **状態空間モデル**: Transformer より高速かつ省メモリなアーキテクチャ\n- **音声クローニング**: 数秒のサンプルから音声を複製\n- **感情制御**: 話速・トーン・感情をリアルタイムに動的変更\n- **Streaming WebSocket API**: チャンクごとの段階的音声生成\n\n## 活用事例\n\n- **AI コールセンター**: 会話型 AI エージェントのリアルタイム音声\n- **対話型キャラクター**: ゲーム・VR での自然な音声応答\n- **ポッドキャスト自動生成**: テキストを高品質音声に一括変換\n- **多言語ローカライズ**: 同一の感情・トーンを複数言語で再現',
  '2026-04-19'
),
(
  'cartesia',
  'models',
  'Cartesia モデル一覧',
  E'## Sonic（TTS フラッグシップ）\n\n### Sonic-2（最新・2025年リリース）\n- **遅延**: 135ms 以下（ストリーミング初回チャンク）\n- **品質**: 自然な抑揚・感情表現\n- **言語**: 英語・日本語・スペイン語・フランス語ほか多言語\n- **形式**: PCM / MP3 / Opus 出力対応\n\n### Sonic-1（安定版）\n- より軽量・省コスト\n- バッチ処理向け\n\n## 音声クローニング\n\n| 機能 | 内容 |\n|------|------|\n| **Instant Clone** | 数秒のサンプル → 即座に複製 |\n| **Professional Clone** | 長めのサンプルで高品質クローン |\n| **Voice Library** | 事前生成済みの共有音声 100+ |\n\n## 感情・スタイル制御\n\n```json\n{\n  "speed": 1.2,\n  "emotion": ["positivity:high", "curiosity:medium"]\n}\n```\n\n- **speed**: 0.5〜2.0 倍速\n- **emotion**: positivity / negativity / curiosity / surprise / sadness / anger を段階制御\n\n## 料金\n\n| プラン | 料金 | 内容 |\n|--------|------|------|\n| Free | $0 | 月 100 万文字 |\n| Growth | $19/月〜 | 従量課金 |\n| Enterprise | 要相談 | SLA + カスタム |',
  '2026-04-19'
),
(
  'cartesia',
  'api',
  'Cartesia API 使い方',
  E'## Python SDK\n\n```python\nimport cartesia\n\nclient = cartesia.Cartesia(api_key="YOUR_API_KEY")\n\n# シンプルな TTS\naudio_arr = client.tts.bytes(\n    model_id="sonic-2",\n    transcript="こんにちは、Cartesia です。超低遅延の音声合成をお楽しみください。",\n    voice={\n        "mode": "id",\n        "id": "694f9389-aac1-45b6-b726-9d9369183238"  # 公式音声 ID\n    },\n    language="ja",\n    output_format={\n        "container": "mp3",\n        "bit_rate": 128000,\n        "sample_rate": 44100\n    }\n)\n\nwith open("output.mp3", "wb") as f:\n    f.write(audio_arr)\n```\n\n## WebSocket ストリーミング（超低遅延）\n\n```python\nimport asyncio\nimport cartesia\n\nasync def stream_tts():\n    client = cartesia.AsyncCartesia(api_key="YOUR_API_KEY")\n    \n    async with client.tts.websocket() as ws:\n        async for chunk in ws.send(\n            model_id="sonic-2",\n            transcript="リアルタイム音声ストリーミング",\n            voice={"mode": "id", "id": "VOICE_ID"},\n            language="ja",\n            output_format={"container": "raw", "sample_rate": 16000, "encoding": "pcm_s16le"}\n        ):\n            # chunk.audio をリアルタイムで再生\n            play_audio(chunk.audio)\n\nasyncio.run(stream_tts())\n```\n\n## 感情制御の例\n\n```python\naudio = client.tts.bytes(\n    model_id="sonic-2",\n    transcript="本日のニュースをお届けします！",\n    voice={\n        "mode": "id",\n        "id": "VOICE_ID",\n        "__experimental_controls": {\n            "speed": "fast",\n            "emotion": ["positivity:high"]\n        }\n    },\n    language="ja"\n)\n```\n\n## 活用シーン\n\n- **Voice Agent 統合**: Deepgram STT + Cartesia TTS で完全音声対話\n- **LLM 応答を即座に読み上げ**: GPT/Claude → Cartesia パイプライン\n- **感情的なナレーション**: 教育動画・広告の感情制御音声',
  '2026-04-19'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
