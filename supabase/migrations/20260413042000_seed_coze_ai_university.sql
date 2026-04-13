-- Windows版#63: AI大学46社目 — Coze (ByteDance)
-- ByteDanceが開発するAIエージェント構築プラットフォーム

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order, is_active)
VALUES
(
  'coze',
  'overview',
  'Coze (ByteDance) とは',
  E'## Coze とは\n\nCoze は **ByteDance** (TikTok親会社) が開発する**AIエージェント構築プラットフォーム**。\nノーコード/ローコードで高度なAIボットを作成・公開できる。\n\n### 特徴\n- **ノーコード**: ドラッグ&ドロップでAIエージェントを構築\n- **プラグインシステム**: 600以上のプラグイン (Web検索・画像生成・コード実行等)\n- **マルチモデル**: GPT-4o / Claude / Gemini / Doubao 等を自由に選択\n- **ワークフロー**: 複雑なタスクをDAGで視覚的に設計\n- **ナレッジベース**: RAGでドキュメントを参照するボット構築\n- **マルチプラットフォーム公開**: Discord / Telegram / Slack / Web / API\n\n### ByteDance AI 戦略\n- Coze: エージェント構築PF (本ページ)\n- Doubao (豆包): 自社LLM\n- TikTok AI: コンテンツ推薦・生成\n- Dreamina: 画像生成AI\n\n> 国際版: https://www.coze.com/ | 中国版: https://www.coze.cn/',
  'https://www.coze.com/',
  '2026-04-13',
  1,
  true
),
(
  'coze',
  'models',
  'Coze プラットフォーム機能一覧',
  E'## Coze プラットフォーム機能\n\n### 対応LLM\n| モデル | 提供元 | 特徴 |\n| --- | --- | --- |\n| **GPT-4o** | OpenAI | 高品質・マルチモーダル |\n| **Claude 3.5 Sonnet** | Anthropic | 長文・コード |\n| **Gemini Pro** | Google | バランス型 |\n| **Doubao** | ByteDance | 中国語特化・自社モデル |\n| **Moonshot** | Kimi | 長コンテキスト |\n\n### エージェント構築機能\n| 機能 | 説明 |\n| --- | --- |\n| **Persona** | ボットの性格・役割を設定 |\n| **Plugins** | 600+ プラグイン (API呼出・Web検索・DB接続) |\n| **Workflows** | DAGベースのタスクフロー設計 |\n| **Knowledge** | RAG: PDF/URL/テキストをナレッジとして追加 |\n| **Memory** | 会話履歴の長期記憶 |\n| **Scheduled Tasks** | 定期実行タスク (ニュース要約等) |\n\n### 公開先\n```\nDiscord / Telegram / Slack / LINE\nWeb Widget (埋め込み)\nCoze API (REST)\nCoze Store (マーケットプレイス)\n```\n\n### 料金\n| プラン | 月額 | メッセージ数 |\n| --- | --- | --- |\n| Free | 無料 | 100回/日 |\n| Professional | $9 | 3,000回/月 |\n| Team | $29 | 10,000回/月 |',
  'https://www.coze.com/docs',
  '2026-04-13',
  2,
  true
),
(
  'coze',
  'api',
  'Coze API 利用方法',
  E'## Coze API 利用方法\n\n### 認証\n```bash\n# APIトークン取得: https://www.coze.com/open/api\nexport COZE_API_TOKEN="your_token"\n```\n\n### ボットにメッセージ送信\n```bash\ncurl -X POST https://api.coze.com/open_api/v2/chat \\\n  -H "Authorization: Bearer $COZE_API_TOKEN" \\\n  -H "Content-Type: application/json" \\\n  -d ''{\n    "bot_id": "your_bot_id",\n    "user": "user_123",\n    "query": "今日のニュースを要約して",\n    "stream": false\n  }''\n```\n\n### ワークフロー実行\n```bash\ncurl -X POST https://api.coze.com/open_api/v1/workflow/run \\\n  -H "Authorization: Bearer $COZE_API_TOKEN" \\\n  -H "Content-Type: application/json" \\\n  -d ''{\n    "workflow_id": "your_workflow_id",\n    "parameters": {\n      "input_text": "分析対象のテキスト"\n    }\n  }''\n```\n\n### ナレッジベースにドキュメント追加\n```bash\ncurl -X POST https://api.coze.com/open_api/v1/knowledge/document/create \\\n  -H "Authorization: Bearer $COZE_API_TOKEN" \\\n  -H "Content-Type: application/json" \\\n  -d ''{\n    "dataset_id": "your_dataset_id",\n    "document_bases": [{\n      "name": "product_manual.pdf",\n      "source_info": {\n        "file_type": "pdf",\n        "file_base64": "..."\n      }\n    }]\n  }''\n```\n\n### リソース\n- APIドキュメント: https://www.coze.com/docs/developer_guides/coze_api_overview\n- Coze Store: https://www.coze.com/store\n- 開発者ポータル: https://www.coze.com/open',
  'https://www.coze.com/docs',
  '2026-04-13',
  3,
  true
),
(
  'coze',
  'news',
  'Coze 最新情報',
  E'## Coze 最新情報 (2026-04-13)\n\n### 注目トピック\n- **Coze Studio**: ノーコードAIエージェント構築UIが大幅刷新。ワークフローエディタが直感的に\n- **マルチエージェント**: 複数ボットが協調する「Agent Team」機能をリリース\n- **Coze API v2**: ストリーミング対応・ファイルアップロード・ワークフロー実行APIを追加\n- **600+ プラグイン**: Google Search / DALL-E / Code Interpreter / YouTube等のプラグインが利用可能\n- **日本語対応**: UIとドキュメントの日本語ローカライズが進行中\n- **Doubao統合**: ByteDance自社LLM「豆包」をデフォルトモデルとして統合\n\n### 競合比較\n| 項目 | Coze | GPTs (OpenAI) | Claude Projects |\n| --- | --- | --- | --- |\n| ノーコード | ◎ | ○ | △ |\n| プラグイン数 | 600+ | 1000+ | ○ MCP |\n| マルチモデル | ◎ | × (GPTのみ) | × (Claudeのみ) |\n| API提供 | ◎ | △ | ○ |\n| 無料枠 | 100回/日 | ChatGPT Plus必須 | 無料あり |\n\n> 公式: https://www.coze.com/',
  'https://www.coze.com/',
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
