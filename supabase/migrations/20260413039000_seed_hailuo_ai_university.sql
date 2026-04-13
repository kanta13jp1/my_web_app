-- Windows版#61: AI大学43社目 — Hailuo AI (MiniMax)
-- MiniMaxが開発する動画・音声・テキスト生成AIプラットフォーム

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order, is_active)
VALUES
(
  'hailuo',
  'overview',
  'Hailuo AI (MiniMax) とは',
  E'## Hailuo AI (MiniMax) とは\n\nHailuo AI は中国のAI企業**MiniMax**が開発する**マルチモーダルAIプラットフォーム**。\n動画生成・音声生成・テキスト生成をワンストップで提供し、2024年後半から急速に注目を集めている。\n\n### 特徴\n- **Hailuo Video**: テキスト/画像から高品質動画を生成。物理演算の自然さで高評価\n- **Hailuo Image**: テキストから高品質静止画を生成\n- **MiniMax API**: 音声合成 (TTS)・テキスト生成・動画生成をAPI提供\n- **コスト効率**: Runway/Kling と比べリーズナブルな料金体系\n- **グローバル展開**: 中国発ながら英語サービスと国際API提供\n\n### MiniMax 企業概要\n- 設立: 2021年\n- 本社: 上海\n- 評価額: 約25億ドル (2024年)\n- 主力製品: Hailuo AI / Talkie (AIキャラクター会話アプリ)\n\n> 公式サイト: https://hailuoai.com/',
  'https://hailuoai.com/',
  '2026-04-13',
  1,
  true
),
(
  'hailuo',
  'models',
  'Hailuo AI モデル一覧',
  E'## Hailuo AI モデル一覧\n\n### 動画生成\n| モデル | 特徴 | 出力 |\n| --- | --- | --- |\n| **MiniMax Video-01** | フラッグシップ動画モデル | 最大6秒・1080p |\n| **Director Model** | カメラワーク制御 | パン・ズーム・ドリー指定可 |\n| **Subject Reference** | 特定人物・物体を一貫描画 | キャラクター維持 |\n\n### テキスト生成 (LLM)\n| モデル | 特徴 |\n| --- | --- |\n| **MiniMax-Text-01** | 100万トークンコンテキスト対応 |\n| **abab6.5s** | 高速・軽量 |\n\n### 音声生成 (TTS)\n| 機能 | 詳細 |\n| --- | --- |\n| **Speech-02** | 高品質多言語TTS (日本語対応) |\n| 音声クローン | 短い音声サンプルから声質複製 |\n\n### 主要API パラメータ (動画)\n```\nモデル: video-01\nプロンプト: テキスト説明\n画像参照: image_url (任意)\n解像度: 1080p\nフレームレート: 24fps\n```\n\n### 価格\n| 動画生成 | 料金 |\n| --- | --- |\n| MiniMax Video-01 | $0.013/秒 |\n| Director Model | $0.015/秒 |',
  'https://www.minimaxi.com/document/video-generation',
  '2026-04-13',
  2,
  true
),
(
  'hailuo',
  'api',
  'Hailuo AI (MiniMax) API 利用方法',
  E'## Hailuo AI (MiniMax) API 利用方法\n\n### 認証\n```bash\n# APIキー取得: https://platform.minimaxi.com/\nexport MINIMAX_API_KEY="your_api_key"\nexport MINIMAX_GROUP_ID="your_group_id"\n```\n\n### 動画生成 (非同期)\n```bash\n# Step 1: 動画生成ジョブを投入\ncurl -X POST https://api.minimaxi.com/v1/video_generation \\\n  -H "Authorization: Bearer $MINIMAX_API_KEY" \\\n  -H "Content-Type: application/json" \\\n  -d ''{\n    "model": "video-01",\n    "prompt": "A cat playing in a garden, cinematic style",\n    "prompt_optimizer": true\n  }''\n\n# レスポンス: { "task_id": "xxx" }\n\n# Step 2: 結果を取得\ncurl "https://api.minimaxi.com/v1/query/video_generation?task_id=xxx" \\\n  -H "Authorization: Bearer $MINIMAX_API_KEY"\n```\n\n### テキスト生成\n```bash\ncurl -X POST https://api.minimaxi.com/v1/text/chatcompletion_v2 \\\n  -H "Authorization: Bearer $MINIMAX_API_KEY" \\\n  -H "Content-Type: application/json" \\\n  -d ''{\n    "model": "MiniMax-Text-01",\n    "messages": [{"role": "user", "content": "Hello!"}]\n  }''\n```\n\n### 音声合成 (TTS)\n```bash\ncurl -X POST https://api.minimaxi.com/v1/t2a_v2 \\\n  -H "Authorization: Bearer $MINIMAX_API_KEY" \\\n  -H "Content-Type: application/json" \\\n  -d ''{\n    "model": "speech-02",\n    "text": "こんにちは、MiniMaxです。",\n    "voice_id": "Japanese_Female_Yuna"\n  }''\n```\n\n### リソース\n- 開発者ポータル: https://platform.minimaxi.com/\n- APIドキュメント: https://www.minimaxi.com/document\n- Hailuo AI: https://hailuoai.com/',
  'https://platform.minimaxi.com/',
  '2026-04-13',
  3,
  true
),
(
  'hailuo',
  'news',
  'Hailuo AI 最新情報',
  E'## Hailuo AI (MiniMax) 最新情報 (2026-04-13)\n\n### 注目トピック\n- **MiniMax Video-01**: 動画生成の物理演算リアリズムでRunway/Soraと比較評価が続出\n- **Director Model**: カメラワークをプロンプトで制御できる業界初機能\n- **Subject Reference**: 参照画像の人物を動画内で一貫描画するキャラクター維持機能\n- **100万トークン**: MiniMax-Text-01が超長文コンテキスト処理に対応\n- **日本語TTS**: Speech-02が自然な日本語音声合成に対応、声質クローンも可能\n- **グローバルAPI**: 国際向けAPI (platform.minimaxi.com) が正式リリース\n\n### 競合比較\n| 項目 | Hailuo | Runway | Kling |\n| --- | --- | --- | --- |\n| 動画長 | 最大6秒 | 最大18秒 | 最大10秒 |\n| 物理リアリズム | 高 | 中〜高 | 高 |\n| 料金 | 安価 | 高め | 中程度 |\n| API提供 | ○ | ○ | ○ |\n\n> 公式: https://hailuoai.com/ | API: https://platform.minimaxi.com/',
  'https://hailuoai.com/',
  '2026-04-13',
  1,
  true
)
ON CONFLICT (provider, category) DO UPDATE
  SET title = EXCLUDED.title,
      content = EXCLUDED.content,
      source_url = EXCLUDED.source_url,
      published_at = EXCLUDED.published_at,
      updated_at = now();
