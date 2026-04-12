-- Windows版#59: Cohere (cohere) — AI大学40社目
-- エンタープライズRAG・Command R+ 特化API

INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
  ('cohere', 'overview',
   'Cohere — エンタープライズ向けNLP AIプラットフォーム',
   E'## Cohere とは\n\nCohere は**企業向けNLP (自然言語処理) AI**に特化したプロバイダー。\nトロント拠点、2019年創業。Google Brain・University of Toronto 出身の研究者が設立。\n\n「企業が自社データでAIを活用できるようにする」をミッションとする。\n\n## 特徴\n\n### エンタープライズ特化の強み\n\n| 強み | 詳細 |\n|------|------|\n| **RAG最適化** | 検索拡張生成に特化したCommand Rシリーズ |\n| **多言語対応** | 100言語以上、日本語精度が高い |\n| **プライバシー** | オンプレ・プライベートクラウド対応 |\n| **埋め込み精度** | MTEB リーダーボード上位常連 |\n| **低コスト** | GPT-4比で最大10倍のコスト効率 |\n\n## 主な用途\n\n- エンタープライズ検索 (社内文書・ナレッジベース)\n- カスタマーサポート自動化\n- コンテンツ生成・要約\n- 感情分析・分類タスク\n- 多言語コンテンツ処理\n\n## 実績\n\n- Oracle・Accenture・HubSpot などが採用\n- シリーズD: $5億ドル調達 (2024年)\n- 評価額: $50億ドル超',
   '2026-04-12'),

  ('cohere', 'models',
   'Cohere モデル一覧 (2026年4月現在)',
   E'## Command R+ (最新・最高精度)\n\nRAGと多ステップ推論に最適化されたフラッグシップモデル。\n\n| スペック | 値 |\n|---------|----|\n| コンテキスト長 | 128K トークン |\n| 対応言語 | 10言語 (日本語含む) |\n| RAG精度 | GPT-4 に匹敵 |\n| 価格 (input) | $3.00 / 1M tokens |\n\n## Command R\n\nコスト効率重視のバランスモデル。中規模RAGシステムに最適。\n\n| スペック | 値 |\n|---------|----|\n| コンテキスト長 | 128K トークン |\n| 対応言語 | 10言語 |\n| 価格 (input) | $0.50 / 1M tokens |\n\n## Command Light\n\n高速・低コストの軽量モデル。分類・タグ付けなどシンプルタスク向け。\n\n## Embed v3 (埋め込みモデル)\n\n業界最高水準の多言語テキスト埋め込みモデル。\nRAGのリトリーバル精度を最大化する。\n\n| 機能 | 詳細 |\n|------|------|\n| MTEB スコア | 64.5 (英語) / 62.1 (多言語) |\n| 次元数 | 1024 |\n| 最大入力 | 512 トークン |\n\n## Rerank 3 (再ランキングモデル)\n\n検索結果の精度を向上させる特化モデル。RAGの最終ステップで使用。\n\n## 競合比較\n\n| 指標 | Command R+ | Claude Sonnet 4.6 | GPT-4o |\n|------|------------|------------------|--------|\n| RAG精度 | ◎ | ○ | ○ |\n| コスト | ◎ ($3/1M) | △ ($15/1M) | △ ($15/1M) |\n| 多言語 | ◎ (100言語) | ○ | ○ |\n| オンプレ対応 | ✓ | ✗ | ✗ |',
   '2026-04-12'),

  ('cohere', 'api',
   'Cohere API ガイド',
   E'## API アクセス\n\n**Cohere API** は公式に公開中。Python/TS/Java/Go SDK 提供。\n\n```\nベースURL: https://api.cohere.com/v2\n認証: Authorization: Bearer {API_KEY}\n```\n\n## 主要エンドポイント\n\n### テキスト生成 (Chat)\n```http\nPOST /v2/chat\nAuthorization: Bearer {API_KEY}\nContent-Type: application/json\n\n{\n  "model": "command-r-plus-08-2024",\n  "messages": [\n    {"role": "user", "content": "RAGシステムの設計を教えて"}\n  ]\n}\n```\n\n### RAG (Tool Use)\n```http\nPOST /v2/chat\n{\n  "model": "command-r-plus-08-2024",\n  "messages": [...],\n  "documents": [\n    {\n      "id": "doc1",\n      "data": {"title": "...", "text": "社内文書の内容..."}\n    }\n  ]\n}\n```\n\n### 埋め込み生成\n```http\nPOST /v2/embed\n{\n  "model": "embed-multilingual-v3.0",\n  "texts": ["テキスト1", "テキスト2"],\n  "input_type": "search_document",\n  "embedding_types": ["float"]\n}\n```\n\n### 再ランキング\n```http\nPOST /v2/rerank\n{\n  "model": "rerank-multilingual-v3.0",\n  "query": "RAGとは何か",\n  "documents": ["文書1の内容", "文書2の内容"],\n  "top_n": 3\n}\n```\n\n## 料金 (2026年4月)\n\n| モデル | Input | Output |\n|--------|-------|--------|\n| Command R+ | $3.00/1M | $15.00/1M |\n| Command R | $0.50/1M | $1.50/1M |\n| Embed (多言語) | $0.10/1M | — |\n| Rerank | $2.00/1K検索 | — |\n\n## Python SDK 例\n\n```python\nimport cohere\n\nco = cohere.Client("YOUR_API_KEY")\n\n# RAG チャット\nresponse = co.chat(\n    model="command-r-plus-08-2024",\n    message="社内規程の有給休暇について教えて",\n    documents=[\n        {"title": "就業規則", "text": "有給休暇は年間20日..."}\n    ]\n)\nprint(response.text)\nprint(response.citations)  # 引用箇所も返す\n```\n\n## 日本語コミュニティ\n\n- X: `@CohereAI`\n- Discord: Cohere Community\n- 公式日本語ドキュメント: docs.cohere.com (日本語対応中)',
   '2026-04-12')
ON CONFLICT (provider, category) DO UPDATE
  SET title = EXCLUDED.title,
      content = EXCLUDED.content,
      published_at = EXCLUDED.published_at;
