-- PS版#3 Session 8: LlamaIndex — RAG・エージェント構築のデータフレームワーク
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'llamaindex',
  'overview',
  'LlamaIndex — LLM アプリ向けデータフレームワーク (RAG の標準ツール)',
  E'## LlamaIndex とは\n\nLlamaIndex (旧称 GPT Index) は 2022 年末に Jerry Liu が公開した\n**LLM アプリケーション向けデータフレームワーク**。\n「どんなデータソースでも LLM に食わせる」をミッションに、\nRAG パイプライン構築ツールとして LangChain と双璧をなす存在。\n\nLlamaIndex Inc. として累計 $8.5M+ を調達。\nPython / TypeScript 両対応、600+ 統合モジュールを提供。\n\n## LangChain との違い\n\n| 観点 | LlamaIndex | LangChain |\n|------|-----------|----------|\n| **主眼** | データ取り込み・インデックス構築 | チェーン・エージェント構築 |\n| **強み** | 高度な検索戦略・データ構造化 | ワークフロー・ツール統合 |\n| **学習曲線** | 低い (RAG に集中) | やや高い (広大な機能) |\n| **エンタープライズ向き** | ◎ ドキュメント重視 | ○ 汎用エージェント |\n\n## 主な特徴\n\n- **SimpleDirectoryReader**: フォルダを渡すだけで全文書を読み込み\n- **高度な検索**: HyDE・コリファイン・BM25 ハイブリッド検索\n- **SubQuestion Decomposer**: 複雑な質問を分解してマルチステップ回答\n- **LlamaParse**: PDF・PowerPoint・HTML を高精度でテキスト化\n- **LlamaHub**: 600+ のデータローダー・ツール・エージェント集\n\n## 活用事例\n\n- **社内 Knowledge Base**: PDF・Notion・Confluence を一括インデックス化\n- **マルチドキュメント QA**: 複数レポートをまたいだ質問応答\n- **エージェント**: コードインタープリタ + 検索 + DB をフル活用\n- **SQL エージェント**: 自然言語で DB クエリを自動生成・実行',
  '2026-04-20'
),
(
  'llamaindex',
  'models',
  'LlamaIndex エコシステム一覧',
  E'## コアコンポーネント\n\n### Documents & Nodes\n```python\nfrom llama_index.core import SimpleDirectoryReader\ndocs = SimpleDirectoryReader("./data").load_data()\n# PDF / Markdown / CSV / HTML / JSON 対応\n```\n\n### Index 種類\n\n| インデックス | 特徴 | 用途 |\n|-------------|------|------|\n| **VectorStoreIndex** | 埋め込みベクター検索 | セマンティック検索 |\n| **SummaryIndex** | ドキュメント要約ベース | 長文ドキュメント |\n| **KnowledgeGraphIndex** | グラフ構造で関係性保持 | エンティティ関連検索 |\n| **SQLStructStoreIndex** | DB スキーマをインデックス化 | Text-to-SQL |\n\n### 高度な検索戦略\n\n- **HyDE (仮想ドキュメント埋め込み)**: 質問から仮答えを生成して検索精度向上\n- **SubQuestion**: 複雑な質問を複数サブ質問に分解\n- **Cohere Reranker**: 検索結果を LLM でリランキング\n- **BM25 Hybrid**: ベクター + キーワード検索を組み合わせ\n\n### LlamaParse\n\n```python\nfrom llama_parse import LlamaParse\nparser = LlamaParse(api_key="...", result_type="markdown")\ndocs = parser.load_data("annual_report.pdf")  # 表・図も高精度変換\n```\n\n## LlamaHub\n\n- 600+ データローダー (Notion / Slack / GitHub / Google Drive など)\n- エージェントツール集 (Web 検索 / コード実行 / DB など)\n- ワンクリックインストール\n\n## 料金\n\n- **LlamaIndex OSS**: 無料\n- **LlamaParse**: 無料枠 1,000 ページ/日 → $0.003/ページ\n- **LlamaCloud**: $97/月〜 (マネージドパイプライン)',
  '2026-04-20'
),
(
  'llamaindex',
  'api',
  'LlamaIndex 使い方',
  E'## インストール\n\n```bash\npip install llama-index llama-index-llms-anthropic llama-index-embeddings-openai\npip install llama-parse  # PDF高精度パース\n```\n\n## シンプルな RAG パイプライン\n\n```python\nfrom llama_index.core import VectorStoreIndex, SimpleDirectoryReader\nfrom llama_index.llms.anthropic import Anthropic\nfrom llama_index.embeddings.openai import OpenAIEmbedding\nfrom llama_index.core import Settings\n\n# モデル設定\nSettings.llm = Anthropic(model="claude-sonnet-4-6")\nSettings.embed_model = OpenAIEmbedding(model="text-embedding-3-small")\n\n# ドキュメント読み込み → インデックス作成\ndocs = SimpleDirectoryReader("./ai_docs").load_data()\nindex = VectorStoreIndex.from_documents(docs)\n\n# クエリエンジン\nquery_engine = index.as_query_engine(similarity_top_k=3)\nresponse = query_engine.query("Claude の料金体系を教えて")\nprint(response)\n```\n\n## 高度な検索: SubQuestion Decomposer\n\n```python\nfrom llama_index.core.query_engine import SubQuestionQueryEngine\nfrom llama_index.core.tools import QueryEngineTool\n\n# 複数インデックスを用意\nai_index = VectorStoreIndex.from_documents(ai_docs)\nbiz_index = VectorStoreIndex.from_documents(biz_docs)\n\ntools = [\n    QueryEngineTool.from_defaults(ai_index.as_query_engine(), name="ai_knowledge"),\n    QueryEngineTool.from_defaults(biz_index.as_query_engine(), name="biz_knowledge"),\n]\n\n# 複雑な質問を自動分解\nengine = SubQuestionQueryEngine.from_defaults(query_engine_tools=tools)\nresponse = engine.query(\n    "AI ベンダーを比較して、ビジネス的に最もコスパが良い選択肢はどれですか？"\n)\nprint(response)\n```\n\n## SQL エージェント (自然言語 → DB クエリ)\n\n```python\nfrom llama_index.core import SQLDatabase\nfrom llama_index.core.query_engine import NLSQLTableQueryEngine\nfrom sqlalchemy import create_engine\n\nengine = create_engine("postgresql://user:pass@localhost/mydb")\nsql_db = SQLDatabase(engine, include_tables=["ai_university_content"])\nquery_engine = NLSQLTableQueryEngine(sql_database=sql_db)\nresponse = query_engine.query("プロバイダー別の記事数を教えて")\nprint(response.metadata["sql_query"])  # 生成されたSQLを確認\n```\n\n## 活用シーン\n\n- **AI 大学 RAG 強化**: プロバイダー記事をインデックス化して自然言語検索\n- **Supabase 接続**: LlamaIndex × Supabase Vector Store で完全 RAG\n- **マルチドキュメント比較**: 複数プロバイダーのドキュメントをまたいだ比較質問',
  '2026-04-20'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
