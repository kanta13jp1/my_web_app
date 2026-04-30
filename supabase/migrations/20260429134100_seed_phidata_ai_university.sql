-- PS#3 S133: AI大学 361→362社化 — Phidata (エージェントフレームワーク / メモリ・知識・ツール統合)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'phidata', 'overview',
  'Phidata — エージェント+メモリ+知識+ツール統合フレームワーク・フルスタックAI開発基盤 (9/9)',
  $$## Phidata とは

**Phidata** (旧 phidata、現在は **Agno** にリブランド中) は「エージェント + メモリ + 知識 + ツール」を一体化したフルスタック AI アプリケーションフレームワーク。

単なるエージェントフレームワークではなく、**AI アプリケーション全体の開発基盤**として設計されており、データベース・ベクトルストア・API・UI を含む完全なスタックを提供する。

## Phidata の 4 つの柱

```
Phidata のアーキテクチャ:

  1. Agent (エージェント):
    ・LLM をコアにした処理エンジン
    ・Tools / Knowledge / Memory を内蔵
    ・chain_of_thought, reasoning 対応
    ・structured_outputs で型安全な出力

  2. Memory (メモリ):
    ・Short-term: 会話内の文脈
    ・Long-term: PostgreSQL / Redis に永続化
    ・User-specific: ユーザー別メモリ
    ・Summarization: 自動要約・圧縮

  3. Knowledge (知識ベース):
    ・PDF, URL, テキストをベクトル化
    ・PostgreSQL (pgvector) に保存
    ・ハイブリッド検索対応

  4. Tools (ツール):
    ・Web 検索 (DuckDuckGo, Brave)
    ・計算・コード実行
    ・API 呼び出し
    ・カスタムツール追加可
```

## 実際のコード例

```python
from phi.agent import Agent
from phi.model.openai import OpenAIChat
from phi.tools.duckduckgo import DuckDuckGo
from phi.storage.agent.postgres import PgAgentStorage
from phi.knowledge.pdf import PDFUrlKnowledgeBase
from phi.vectordb.pgvector import PgVector

# 知識ベースを構築 (PDF → pgvector)
knowledge_base = PDFUrlKnowledgeBase(
    urls=["https://example.com/product-manual.pdf"],
    vector_db=PgVector(
        table_name="product_docs",
        db_url="postgresql://localhost/ai_db"
    )
)

# エージェントを作成
agent = Agent(
    model=OpenAIChat(id="gpt-4o"),
    tools=[DuckDuckGo()],              # Web検索ツール
    knowledge=knowledge_base,           # 知識ベース
    storage=PgAgentStorage(            # 会話履歴をDBに永続化
        table_name="agent_sessions",
        db_url="postgresql://localhost/ai_db"
    ),
    show_tool_calls=True,
    markdown=True
)

# 実行
agent.print_response(
    "製品マニュアルを参照してセットアップ手順を教えて",
    stream=True
)
```

## Phidata のフルスタック構成

```
Phidata のスタック全体像:

  AI Layer:
    ・Agent (LLM + Tools)
    ・Team (複数エージェント協調)
    ・Workflow (複数ステップ処理)

  Data Layer:
    ・PostgreSQL + pgvector
    ・Redis (セッション管理)
    ・S3 (ファイルストレージ)

  API Layer:
    ・FastAPI (自動生成)
    ・REST / WebSocket
    ・認証・認可

  UI Layer:
    ・Streamlit UI (ビルトイン)
    ・Next.js テンプレート
```

## Agno へのリブランド

2025年に Phidata から **Agno** にリブランドを進めている。機能はそのままに、より高速なモデルルーティングと multi-modal 対応を強化。

## 自分株式会社との関連

Phidata の「Memory (PostgreSQL 永続化) + Knowledge (pgvector) + Agent」の組み合わせは、自分株式会社の Supabase (PostgreSQL + pgvector) + Edge Function の設計と完全一致。特に memory-search-hub EF で実装予定の「ユーザー別長期記憶 + ベクトル検索」は Phidata の Long-term Memory + Knowledge Base の実装パターンを直接参照できる。
$$,
  'https://github.com/agno-agi/phidata',
  NOW(),
  362
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
