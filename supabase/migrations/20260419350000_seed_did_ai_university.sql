-- PS版#3 Session 4: D-ID — リアルタイム AI アバター動画生成 API
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'did',
  'overview',
  'D-ID — リアルタイム AI アバター動画生成プラットフォーム',
  E'## D-ID とは\n\nD-ID（Digital Identity）は 2017 年にイスラエルで設立された **AI アバター動画生成プラットフォーム**。\n静止画から **リアルタイムで話すアバター動画** を生成する技術で知られ、REST API・Web Studio・リアルタイムストリーミングを提供する。\n\n当初はディープフェイク防止（顔認識回避）技術の企業だったが、生成 AI ブームで転換。企業向けバーチャルスポークスパーソン・教育動画・顧客対応アバターなどに広く採用。\n\n## 主な特徴\n\n- **Talks API**: 静止画 + 音声 → 自然な口の動きの動画を自動生成\n- **Clips API**: テキスト → アバター動画（TTS 統合）\n- **Agents API**: リアルタイム会話アバター（LLM + 音声 + 動画統合）\n- **全プランで API 提供**: 月 $4.70 〜 のプランから利用可能\n- **音声クローニング**: ユーザー自身の声で話すアバターを作成\n\n## 活用事例\n\n- **企業研修動画**: 一度撮影せずにアバターで大量生成\n- **多言語コンテンツ**: 同じアバターで複数言語の動画を自動生成\n- **カスタマーサービス**: 24/7 対応の AI アバター受付',
  '2026-04-19'
),
(
  'did',
  'models',
  'D-ID API 一覧',
  E'## Talks API（静止画 → 動画）\n\n- **入力**: 画像ファイル + 音声ファイル / TTS テキスト\n- **出力**: 口が動く動画ファイル (.mp4)\n- **処理**: 非同期（Webhook またはポーリング）\n- **精度**: 自然な口の動き・アイコンタクト・首の動き\n\n## Clips API（テキスト → アバター動画）\n\n- **入力**: テキスト + プリセットアバター / カスタム画像\n- **TTS 統合**: ElevenLabs / Microsoft Azure TTS / Deepgram 連携\n- **出力**: スクリプトを読み上げるアバター動画\n\n## Agents API（リアルタイム AI アバター）\n\n- **LLM 統合**: OpenAI GPT / Claude / Gemini を接続\n- **ストリーミング**: WebRTC でリアルタイム映像配信\n- **対話**: 質問に自然に答えるアバターセッション\n\n## Presenters（プリセットアバター）\n\n- 50+ のプロフェッショナルアバターを標準提供\n- 言語・性別・スタイルでフィルタリング可能\n\n## プランと分数制限\n\n| プラン | 月額 | 動画分数 |\n|--------|------|----------|\n| Lite | $5.99 | 10分 |\n| Pro | $49.99 | 15分（API 含む）|\n| Advanced | $299 | 65分 |\n| Enterprise | 要相談 | カスタム |',
  '2026-04-19'
),
(
  'did',
  'api',
  'D-ID API 使い方',
  E'## 認証\n\n```bash\nexport DID_API_KEY="YOUR_API_KEY"\n```\n\n## Talks API — 静止画 + 音声 → 動画\n\n```python\nimport requests, base64, time\n\n# 動画生成リクエスト\nheaders = {"Authorization": f"Basic {base64.b64encode(f"{DID_API_KEY}:".encode()).decode()}"}\n\nresponse = requests.post(\n    "https://api.d-id.com/talks",\n    headers=headers,\n    json={\n        "source_url": "https://example.com/portrait.jpg",\n        "script": {\n            "type": "audio",\n            "audio_url": "https://example.com/speech.mp3"\n        }\n    }\n)\ntalk_id = response.json()["id"]\n\n# ポーリングで完了待ち\nwhile True:\n    result = requests.get(f"https://api.d-id.com/talks/{talk_id}", headers=headers).json()\n    if result["status"] == "done":\n        print(result["result_url"])  # 動画 URL\n        break\n    time.sleep(2)\n```\n\n## Clips API — テキスト → アバター動画\n\n```python\nresponse = requests.post(\n    "https://api.d-id.com/clips",\n    headers=headers,\n    json={\n        "presenter_id": "amy-jcwCkr1grs",\n        "script": {\n            "type": "text",\n            "input": "こんにちは！AI 大学へようこそ。",\n            "provider": {\n                "type": "microsoft",\n                "voice_id": "ja-JP-NanamiNeural"\n            }\n        }\n    }\n)\n```\n\n## 活用シーン\n\n- **教育動画の量産**: テキスト更新だけで動画を再生成\n- **多言語対応**: 同一アバターを複数言語でコピー\n- **リアルタイム FAQ ボット**: Agents API で 24/7 対応',
  '2026-04-19'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
