-- PS版#3 Session 6: Descript — AI ポッドキャスト・動画編集プラットフォーム
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'descript',
  'overview',
  'Descript — テキスト編集で動画・音声を操る AI クリエイティブツール',
  E'## Descript とは\n\nDescript は 2017 年設立のサンフランシスコ発スタートアップ。\n「**動画・音声をワードプロセッサのように編集できる**」という独自コンセプトで注目を集める AI クリエイティブプラットフォーム。\n\nトランスクリプトのテキストを編集するだけで動画・音声が自動編集される革新的なアプローチ。\nAndreessen Horowitz などから累計 $100M 以上を調達。\n\n## 主な特徴\n\n- **Overdub**: 自分の声をクローンして書き直し・追加録音が不要に\n- **テキスト → 動画編集**: 台本テキストを削除するだけで映像も削除\n- **自動文字起こし**: Whisper ベースの高精度 STT\n- **Filler Word 削除**: 「えー」「あー」などのフィラー音を自動除去\n- **Studio Sound**: AI によるバックグラウンドノイズ除去・音質改善\n- **Eye Contact**: AI で目線を常にカメラ方向に自動補正\n\n## 活用事例\n\n- **ポッドキャスト制作**: 録音 → 文字起こし → テキスト編集で素早く完成\n- **YouTube 動画編集**: 不要部分をテキスト削除で瞬時にカット\n- **コース動画**: 言い間違いを Overdub で後から修正\n- **リール・Shorts 生成**: 長動画からハイライトを自動抽出',
  '2026-04-20'
),
(
  'descript',
  'models',
  'Descript 主要 AI 機能一覧',
  E'## AI 機能\n\n### Overdub（音声クローン）\n- 自分の声を学習させてテキスト入力で新規音声生成\n- 録音後の言い間違い修正に最適\n- 品質: 高品質・自然な抑揚\n\n### Underlord (AI エディター)\n- テキスト削除 → 対応映像・音声を自動削除\n- フィラーワード一括削除\n- 無音区間の自動カット\n- チャプター自動生成\n\n### Studio Sound\n- AI ノイズキャンセリング\n- 会議室・自宅録音を「スタジオ品質」に\n\n### Eye Contact Correction\n- 話し手の目線を AI でカメラ正面に補正\n\n### AI Clip Creator\n- 長編動画 → ソーシャルメディア用短尺クリップを自動生成\n- キャプション自動付与\n\n## 料金\n\n| プラン | 月額 | 主な機能 |\n|--------|------|----------|\n| Free | $0 | 1時間/月、ウォーターマーク |\n| Hobbyist | $24 | 10時間/月、Overdub |\n| Creator | $40 | 30時間/月、全 AI 機能 |\n| Business | $60 | 無制限、チーム共有 |\n\n## API (Descript API)\n\n- 転写 API: 音声ファイル → テキスト + タイムスタンプ\n- プロジェクト管理 API: プログラムでのメディア操作\n- Webhook: 書き起こし完了イベント通知',
  '2026-04-20'
),
(
  'descript',
  'api',
  'Descript API 使い方',
  E'## Descript API 概要\n\nDescript は主に GUI ツールだが、**転写 API** と **プロジェクト API** で自動化が可能。\n\n```bash\nexport DESCRIPT_API_KEY="YOUR_API_KEY"\n```\n\n## 転写 API\n\n```python\nimport requests\n\nheaders = {\n    "Authorization": f"Bearer {DESCRIPT_API_KEY}",\n    "Content-Type": "application/json"\n}\n\n# 音声ファイルをアップロードして転写\nwith open("podcast.mp3", "rb") as f:\n    upload_response = requests.post(\n        "https://api.descript.com/v2/uploads",\n        headers=headers,\n        files={"file": f}\n    )\nupload_id = upload_response.json()["id"]\n\n# 転写ジョブ作成\ntranscription = requests.post(\n    "https://api.descript.com/v2/transcriptions",\n    headers=headers,\n    json={\n        "upload_id": upload_id,\n        "language": "ja",\n        "speaker_detection": True\n    }\n).json()\n\nprint(transcription["transcript"])  # テキスト取得\n```\n\n## Webhook 設定\n\n```python\n# 転写完了時の Webhook\nrequests.post(\n    "https://api.descript.com/v2/webhooks",\n    headers=headers,\n    json={\n        "url": "https://yourapp.com/webhook",\n        "events": ["transcription.completed", "transcription.failed"]\n    }\n)\n```\n\n## 自動化ワークフロー例\n\n```python\n# 週次ポッドキャスト自動フロー\n# 1. 録音ファイルを Descript API で転写\n# 2. テキストを GPT-4 で要約・チャプター生成\n# 3. Descript プロジェクトに反映\n# 4. PlayHT で紹介音声を自動生成\n# 5. 動画を YouTube にアップロード\n```\n\n## 活用シーン\n\n- **ポッドキャスト文字起こし**: Descript → テキスト → ブログ記事自動生成\n- **社内会議録**: 録音 → STT → AI 要約 → Slack 投稿パイプライン\n- **動画コンテンツ再活用**: YouTube → テキスト → SNS 投稿 → ブログ',
  '2026-04-20'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
