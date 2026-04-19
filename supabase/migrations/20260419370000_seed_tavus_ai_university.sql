-- PS版#3 Session 5: Tavus — 個人化 AI 動画生成プラットフォーム
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'tavus',
  'overview',
  'Tavus — パーソナライズ AI 動画生成 & 会話型ビデオ AI',
  E'## Tavus とは\n\nTavus は 2020 年設立のサンフランシスコ発スタートアップ。\n「1 本の動画から無数の個人化動画を生成する」**Video Personalization Platform** と、\nリアルタイム対話を可能にする **Conversational Video Interface (CVI)** を提供する。\n\n元 Twitter エンジニアが創業し、累計調達額 $41M 以上。\nHubSpot・Salesforce・Zoom などとの統合実績を持つ B2B 向けプラットフォーム。\n\n## 主な特徴\n\n- **Replica**: 本人の外見・声・話し方をクローンした AI アバター\n- **Phoenix モデル**: リップシンク精度業界トップクラス\n- **CVI API**: LLM と統合したリアルタイム会話動画エージェント\n- **変数置換**: 名前・会社名などをスクリプトに埋め込み大量個人化\n- **Webhook 対応**: 動画生成完了を非同期通知\n\n## 活用事例\n\n- **セールス動画**: 見込み客に個人化した営業動画を自動生成\n- **カスタマーオンボーディング**: ユーザー名・利用プランを組み込んだウェルカム動画\n- **AI 面接官**: HR の CVI アバターが候補者と対話\n- **E ラーニング**: 講師アバターが学習者の名前を呼んでパーソナライズ指導',
  '2026-04-19'
),
(
  'tavus',
  'models',
  'Tavus モデル・機能一覧',
  E'## Phoenix（リップシンクモデル）\n\n- **Phoenix-3**（最新）: 最高品質のリップシンク・表情生成\n- **Phoenix-2**: 高速処理・コスト最適\n- **Phoenix-1**: レガシーサポート\n\n## Replica（アバター生成）\n\n| タイプ | 内容 |\n|--------|------|\n| **Stock Replica** | Tavus 提供の 100+ プロアバター |\n| **Personal Replica** | 自分の顔・声から 5 分で作成 |\n| **Background** | 仮想背景・グリーンスクリーン対応 |\n\n## Conversational Video Interface (CVI)\n\n- **WebRTC** ベースのリアルタイム映像通話\n- LLM（GPT-4o / Claude / Gemini）と直接統合\n- **割り込み対応**: 話を中断して応答可能\n- **カスタムペルソナ**: 独自の性格・知識ベースを設定\n- **ツール呼び出し**: ビデオ通話中にバックエンド API を実行\n\n## 料金\n\n| プラン | 月額 | 動画分数 |\n|--------|------|----------|\n| Developer | 無料 | 25分/月 |\n| Starter | $99 | 100分 |\n| Growth | $499 | 600分 |\n| Enterprise | 要相談 | 無制限 |\n\n※ CVI は別途 per-minute 課金',
  '2026-04-19'
),
(
  'tavus',
  'api',
  'Tavus API 使い方',
  E'## 動画生成 (Phoenix API)\n\n```python\nimport requests\n\nheaders = {\n    "x-api-key": "YOUR_API_KEY",\n    "Content-Type": "application/json"\n}\n\n# 個人化動画を生成\nresponse = requests.post(\n    "https://tavusapi.com/v2/videos",\n    headers=headers,\n    json={\n        "replica_id": "r9340814e4",  # Personal or Stock Replica\n        "script": "こんにちは {name} さん！{company} へようこそ。",\n        "video_name": "onboarding_video",\n        "variables": {\n            "name": "田中",\n            "company": "自分株式会社"\n        },\n        "callback_url": "https://yourapp.com/webhook"\n    }\n)\nvideo_id = response.json()["video_id"]\nprint(f"生成中: {video_id}")\n```\n\n## 動画ステータス確認\n\n```python\n# ポーリング or Webhook で完了確認\nstatus = requests.get(\n    f"https://tavusapi.com/v2/videos/{video_id}",\n    headers=headers\n).json()\n\nif status["status"] == "ready":\n    print(status["download_url"])  # 完成動画 URL\n```\n\n## CVI (Conversational Video Interface) セッション開始\n\n```python\n# リアルタイム会話動画セッション作成\nresponse = requests.post(\n    "https://tavusapi.com/v2/conversations",\n    headers=headers,\n    json={\n        "replica_id": "r9340814e4",\n        "persona_id": "p5317866",  # カスタムペルソナ\n        "callback_url": "https://yourapp.com/cvi-webhook",\n        "conversational_context": "あなたは自分株式会社のカスタマーサポートです。"\n    }\n)\nconversation_url = response.json()["conversation_url"]\nprint(f"会話セッション: {conversation_url}")\n```\n\n## 活用シーン\n\n- **セールス自動化**: CRM の見込み客リスト → 個人化動画を自動生成・送付\n- **AI 受付アバター**: CVI で 24/7 対応の顔付き AI エージェント\n- **学習コンテンツ**: 生徒の名前・進捗に合わせたパーソナライズ動画',
  '2026-04-19'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
