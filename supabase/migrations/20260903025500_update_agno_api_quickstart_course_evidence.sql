-- Issue #5126: Agno API 入門コースのエビデンス契約・現行Memory×Knowledge×Tools統合ラボ・更新日付の強化
UPDATE ai_university_contents
SET
  description = $md$
# Agno API 入門 — Memory × Knowledge × Tools エージェント統合実践 (2026)

**Agno (旧 phidata)** の最新 API (`agno>=1.0.0`) を使い、**短期/長期記憶 (Memory)**、**ベクトル知識検索 (Knowledge)**、**外部ツール (Tools)** を 1 つのエージェントに統合する実践チュートリアルです。

## 対象学習者 & 到達目標
- **対象者**: Python で LLM エージェントを構築したいエンジニア
- **到達目標**: Agno の現行 API を用いて Memory (SqliteDb)・Knowledge (LanceDb/PgVector)・Tools を統合した自律エージェントを構築し、ステートレス構成との応答精度・トークン消費量の差異を評価できる

## 環境セットアップ (Pinned Environment)

```bash
# Python 3.11+ 推奨
pip install "agno>=1.0.0" openai anthropic lancedb duckduckgo-search
export ANTHROPIC_API_KEY="your_api_key"
```

## 実践 60 分ラボ: Memory × Knowledge × Tools 3 点統合エージェント

```python
from agno.agent import Agent
from agno.models.anthropic import Claude
from agno.db.sqlite import SqliteDb
from agno.memory import MemoryManager
from agno.knowledge import Knowledge
from agno.vectordb.lancedb import LanceDb
from agno.tools.duckduckgo import DuckDuckGoTools

# 1. ナレッジベースの定義 (LanceDB ローカルベクトル検索)
knowledge_base = Knowledge(
    vector_db=LanceDb(table_name="company_docs", uri="/tmp/lancedb"),
)
knowledge_base.load_text("社内規程: 経費精算の締切日は毎月25日。領収書はPDF原本添付が必須。")

# 2. 統合エージェントの作成
agent = Agent(
    model=Claude(id="claude-sonnet-4-6"),
    db=SqliteDb(table_name="agent_sessions", db_file="/tmp/agno_agent.db"),
    memory_manager=MemoryManager(),
    knowledge=knowledge_base,
    tools=[DuckDuckGoTools()],
    show_tool_calls=True,
    markdown=True,
)

# 3. 実行テスト: 過去の対話記憶とナレッジ検索とWeb検索の横断処理
agent.print_response("私の名前は山田です。経費精算の締切日はいつですか？")
agent.print_response("私の名前を覚えていますか？ 最新のドル円為替レートも調べて教えてください。")
```

## 評価基準 & トラブルシューティング

| 評価項目 | 合格基準 | 不合格時の対応 |
| :--- | :--- | :--- |
| **ナレッジ検索** | 社内規程の締切日（25日）を正確に回答 | `knowledge_base.load_text` のインデックス完了を確認 |
| **会話記憶** | 2回目の質問で名前（山田）を保持・引用 | `SqliteDb` のファイルパス書き込み権限を確認 |
| **外部検索** | 最新の為替レートを Tool Calling で取得 | `DuckDuckGoTools` のネットワーク疎通を確認 |
$md$,
  source_url = 'https://docs.agno.com/',
  published_at = '2026-09-02'
WHERE provider_id = 'agno' AND (title LIKE '%Agno API 入門%' OR id = '41283504-615b-4911-9ebb-af81298a5770' OR sort_order = 3);
