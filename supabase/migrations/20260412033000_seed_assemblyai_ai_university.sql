-- Windows版#58: AssemblyAI (assemblyai) — AI大学38社目
-- 音声認識・転写・音声理解特化API

INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
  ('assemblyai', 'overview',
   'AssemblyAI — 音声AI APIのリーディングカンパニー',
   E'## AssemblyAI とは\n\nAssemblyAI は**音声認識・転写・音声理解**に特化したAI APIプロバイダー。\nデンバー拠点、2017年創業。\n\n「開発者が最高の音声AIを最も簡単に使えるようにする」をミッションとする。\n\n## 特徴\n\n### 音声処理の全工程をカバー\n\n| 機能カテゴリ | 具体的機能 |\n|------------|----------|\n| **転写** | リアルタイム文字起こし・バッチ転写 |\n| **理解** | 感情分析・トピック検出・要約 |\n| **識別** | 話者分離・ハイライト抽出 |\n| **安全** | 有害コンテンツ検出・PII削除 |\n\n## 強み\n\n- **精度**: 業界最高水準の転写精度 (WER: 〜4%)\n- **多言語**: 99言語対応 (日本語含む)\n- **低レイテンシ**: リアルタイム転写は〜300ms\n- **開発者フレンドリー**: REST API + SDK 5言語対応\n\n## 利用実績\n\n- Spotify / Zoom / Salesforce などが採用\n- 月間50億分以上の音声を処理\n- 5万人以上の開発者が利用',
   '2026-04-12'),

  ('assemblyai', 'models',
   'AssemblyAI モデル一覧 (2026年4月現在)',
   E'## Universal-2 (最新・最高精度)\n\n最新の汎用音声認識モデル。Universal-1 から精度・速度ともに大幅改善。\n\n| スペック | 値 |\n|---------|----|\n| 精度 (WER) | 〜3.8% (英語) |\n| 日本語精度 | 〜5.2% |\n| 処理速度 | 音声長の1/10の時間で完了 |\n| 最大ファイルサイズ | 2.5GB |\n\n## Nano (高速・低コスト)\n\n精度よりも速度とコストを重視するユースケース向け。\nリアルタイム文字起こしのサブタスクに最適。\n\n## Slam-1 (音声理解特化)\n\n転写結果の「理解」に特化。感情・トーン・意図を高精度で分析。\nコールセンター分析・会議要約に活用。\n\n## Streaming API\n\nリアルタイム転写用の専用モデル。WebSocket で低遅延処理。\n\n## 言語モデル統合\n\nAssemblyAI は転写後の「LeMUR」機能でLLMと連携:\n- Claude (Anthropic) をデフォルトで採用\n- 音声内容についての質問・要約・分析が可能\n\n## 競合比較\n\n| 指標 | AssemblyAI | Whisper (OpenAI) | Google STT | Amazon Transcribe |\n|------|------------|------------------|------------|-------------------|\n| 精度 (WER英語) | 3.8% | 4.2% | 5.1% | 6.8% |\n| 話者分離 | ✓ | ✗ | ✓ | ✓ |\n| 感情分析 | ✓ | ✗ | ✗ | △ |\n| 日本語 | ✓ | ✓ | ✓ | ✓ |',
   '2026-04-12'),

  ('assemblyai', 'api',
   'AssemblyAI API ガイド',
   E'## API アクセス\n\n**AssemblyAI REST API** は公式に公開済み。SDKは Python/JS/Go/Java/Ruby の5言語対応。\n\n```\nベースURL: https://api.assemblyai.com/v2\n認証: HTTP Header "Authorization: {API_KEY}"\n```\n\n## 主要エンドポイント\n\n### 音声ファイルアップロード\n```http\nPOST /upload\nAuthorization: {API_KEY}\nContent-Type: audio/mp3\n[音声ファイルのバイナリ]\n→ { "upload_url": "https://..." }\n```\n\n### 転写ジョブ作成\n```http\nPOST /transcript\nAuthorization: {API_KEY}\nContent-Type: application/json\n\n{\n  "audio_url": "https://upload_url_from_above",\n  "language_code": "ja",\n  "speaker_labels": true,\n  "sentiment_analysis": true,\n  "auto_highlights": true,\n  "summarization": true,\n  "summary_model": "informative",\n  "summary_type": "bullets"\n}\n```\n\n### ポーリング\n```http\nGET /transcript/{transcript_id}\n→ { "status": "completed", "text": "...", "words": [...] }\n```\n\n### LeMUR (音声→LLM質問)\n```http\nPOST /lemur/v3/generate/task\n{\n  "transcript_ids": ["transcript_id_here"],\n  "prompt": "この会議の決定事項を箇条書きで教えて",\n  "final_model": "claude-sonnet-4-6"\n}\n```\n\n## 料金\n\n| モデル | 価格 |\n|--------|------|\n| Nano | $0.05/時間 |\n| Universal-2 | $0.37/時間 |\n| Streaming (Nano) | $0.10/時間 |\n| LeMUR | $0.003/input token |\n\n## Python SDK 例\n\n```python\nimport assemblyai as aai\n\naai.settings.api_key = "YOUR_API_KEY"\ntranscriber = aai.Transcriber()\n\nconfig = aai.TranscriptionConfig(\n    language_code="ja",\n    speaker_labels=True,\n    sentiment_analysis=True\n)\n\ntranscript = transcriber.transcribe("./meeting.mp3", config)\nprint(transcript.text)\n\n# LeMUR で要約\nresult = transcript.lemur.task("要点を3つ教えて")\nprint(result.response)\n```',
   '2026-04-12')
ON CONFLICT (provider, category) DO UPDATE
  SET title = EXCLUDED.title,
      content = EXCLUDED.content,
      published_at = EXCLUDED.published_at;
