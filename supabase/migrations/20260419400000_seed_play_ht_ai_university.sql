-- PS版#3 Session 6: PlayHT — 音声クローニング特化 TTS プラットフォーム
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'play_ht',
  'overview',
  'PlayHT — 音声クローニング × 超低遅延 TTS の老舗プラットフォーム',
  E'## PlayHT とは\n\nPlayHT は 2019 年設立のカナダ発音声 AI スタートアップ。\n当初はブログをポッドキャスト化するツールとして始まり、現在は **高品質音声クローニング** と\n**超低遅延リアルタイム TTS** を提供する開発者向けプラットフォームに進化。\n\n「Play.ai」ブランドでリアルタイム AI 音声エージェントにも進出。\n\n## 主な特徴\n\n- **PlayHT 3.0 Ultra**: 最高品質の音声クローニング・感情制御\n- **Turbo v2**: 業界最速クラスの低遅延 TTS（75ms〜）\n- **Instant Clone**: 数秒のサンプルで声を即座に複製\n- **900+ プリセット音声**: 多様なアクセント・年齢・性別\n- **Play.ai**: リアルタイム音声エージェント (会話型 AI)\n\n## 活用事例\n\n- **ポッドキャスト自動生成**: ブログ記事を自然な会話音声に変換\n- **有声書籍 (Audiobook)**: テキストを人間品質の音声読み上げに\n- **カスタマーサービス**: AI 音声エージェントで 24/7 対応\n- **ゲームキャラクター**: NPCのセリフをリアルタイム生成',
  '2026-04-20'
),
(
  'play_ht',
  'models',
  'PlayHT モデル一覧',
  E'## TTS モデル\n\n| モデル | 特徴 | 遅延 | 用途 |\n|--------|------|------|------|\n| **PlayHT 3.0 Ultra** | 最高品質・最自然 | ~1秒 | 高品質コンテンツ |\n| **PlayHT 2.0** | バランス型 | ~500ms | 汎用 |\n| **Turbo v2** | 超低遅延 | ~75ms | リアルタイムエージェント |\n| **Emotion** | 感情制御特化 | ~300ms | ドラマ・ゲーム |\n\n## 音声クローニング\n\n| タイプ | サンプル時間 | 品質 |\n|--------|------------|------|\n| **Instant Clone** | 数秒〜1分 | 高品質 |\n| **Professional Clone** | 30分以上 | 最高品質 |\n\n## 感情・スタイル制御\n\n```python\n# 感情パラメータ例\n{\n  "emotion": "happy",  # happy / sad / angry / fearful / disgust / surprised\n  "voice_engine": "PlayHT3.0-ultra",\n  "speed": 1.0,\n  "temperature": 0.7  # 多様性 0.0-2.0\n}\n```\n\n## 料金\n\n| プラン | 月額 | 文字数 |\n|--------|------|--------|\n| Free | $0 | 12,500文字 |\n| Creator | $31.2 | 100万文字 |\n| Unlimited | $99 | 無制限 |\n| Enterprise | 要相談 | API + SLA |',
  '2026-04-20'
),
(
  'play_ht',
  'api',
  'PlayHT API 使い方',
  E'## Python SDK\n\n```python\nfrom pyht import Client, TTSOptions, Format\n\nclient = Client(\n    user_id="YOUR_USER_ID",\n    api_key="YOUR_API_KEY"\n)\n\noptions = TTSOptions(\n    voice="s3://voice-cloning-zero-shot/XXX",  # 音声 ID\n    sample_rate=44100,\n    format=Format.FORMAT_MP3,\n    speed=1.0\n)\n\n# ストリーミング TTS\nwith open("output.mp3", "wb") as f:\n    for chunk in client.tts("こんにちは！PlayHT の超自然な音声をお楽しみください。", options):\n        f.write(chunk)\n```\n\n## REST API\n\n```python\nimport requests\n\nheaders = {\n    "Authorization": "Bearer YOUR_API_KEY",\n    "X-User-ID": "YOUR_USER_ID",\n    "Content-Type": "application/json",\n    "Accept": "audio/mpeg"\n}\n\nresponse = requests.post(\n    "https://api.play.ht/api/v2/tts/stream",\n    headers=headers,\n    json={\n        "text": "AI大学でPlayHTを学習中です。",\n        "voice": "ja-JP-NanamiNeural",\n        "voice_engine": "PlayHT2.0",\n        "output_format": "mp3",\n        "sample_rate": 24000\n    },\n    stream=True\n)\n\nwith open("output.mp3", "wb") as f:\n    for chunk in response.iter_content(chunk_size=8192):\n        f.write(chunk)\n```\n\n## 音声クローニング\n\n```python\n# 音声サンプルをアップロードしてクローン作成\nresponse = requests.post(\n    "https://api.play.ht/api/v2/cloned-voices/instant/",\n    headers={**headers, "Accept": "application/json"},\n    files={"sample_file": open("voice_sample.mp3", "rb")},\n    data={"voice_name": "MyClonedVoice"}\n)\ncloned_voice_id = response.json()["id"]\n```\n\n## 活用シーン\n\n- **Deepgram STT + PlayHT TTS**: 完全音声パイプライン構築\n- **ポッドキャスト量産**: ブログ記事を Turbo v2 で即音声化\n- **ゲーム NPC**: Emotion モデルで感情豊かなキャラクター音声',
  '2026-04-20'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
