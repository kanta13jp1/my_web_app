-- Session PS#3-S45: AI大学 191社化 — LangGraph 追加
-- LangChain チームが開発するステートフル・マルチアクター LLM アプリ構築フレームワーク。
-- グラフ構造でノード (LLM) とエッジ (条件分岐) を定義。Cycle・Persistence 対応。
-- GitHub 11k+ Stars / MIT License / LangChain エコシステムと統合。
-- Step 0: 7.5/9 (ステートフルエージェント / マルチアクター / 11k+ Stars / 企業採用 / MIT)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'langgraph',
  'overview',
  'LangGraph — ステートフル・マルチアクター LLM アプリをグラフで構築するフレームワーク',
  $md$
# LangGraph — Stateful Multi-Actor Applications with LLMs

**LangChain** チームが開発する、**グラフ構造**で LLM アプリケーションを定義するフレームワーク。

単純な LLM チェーンでは表現できない「ループ」「条件分岐」「状態の永続化」を実現し、
本番グレードのエージェントシステムを構築できる。

GitHub Stars **11,000+** / MIT ライセンス。

## なぜ LangGraph か

| 課題 | LangGraph の解決策 |
| :--- | :--- |
| 複雑な条件分岐が書けない | **条件付きエッジ** (conditional edges) で分岐を定義 |
| エージェントがループできない | **サイクル対応** のグラフ構造 |
| 会話状態が消える | **State** オブジェクトで永続化 |
| 人間による承認が難しい | **Human-in-the-Loop** の中断・再開機能 |
| マルチエージェント協調が複雑 | **サブグラフ** で階層的なエージェント構成 |

## グラフの基本概念

```
ノード (Node) = LLM 呼び出し・ツール実行・カスタム処理
エッジ (Edge) = ノード間の接続 (無条件 or 条件付き)
状態 (State) = グラフ全体で共有されるデータ
```

## 主要ユースケース

- **ReAct エージェント** — 推論 → 行動 → 観察のループ
- **カスタマーサポートボット** — 問合せ分類 → 対応 → エスカレーション
- **コードレビューシステム** — 解析 → 修正提案 → 承認ループ
- **マルチエージェント調査** — 並行調査 → 統合 → レポート
- **RAG + 再検索** — 回答品質不足 → 再検索ループ

## LangChain との関係

| ツール | 用途 |
| :--- | :--- |
| **LangChain** | LLM 呼び出し・プロンプト・チェーンの基礎 |
| **LangGraph** | ステートフル・ループ・条件分岐を持つ複雑なフロー |
| **LangSmith** | デバッグ・トレーシング・評価 |
$md$,
  'https://langchain-ai.github.io/langgraph/',
  '2026-04-25',
  1
),

(
  'langgraph',
  'api',
  'LangGraph 入門 — StateGraph・ノード・エッジ・条件分岐の基本',
  $md$
## インストール

```bash
pip install langgraph langchain-anthropic
```

---

## 基本的な StateGraph

```python
from typing import TypedDict, Annotated
from langgraph.graph import StateGraph, END
from langchain_anthropic import ChatAnthropic
from langchain_core.messages import HumanMessage, AIMessage
import operator

# Step 1: State を定義 (グラフ全体で共有されるデータ)
class State(TypedDict):
    messages: Annotated[list, operator.add]  # メッセージリストに追記
    next_step: str

# Step 2: LLM とノードを定義
llm = ChatAnthropic(model="claude-sonnet-4-6")

def chat_node(state: State) -> dict:
    """LLM に話しかけるノード"""
    response = llm.invoke(state["messages"])
    return {"messages": [response]}

def should_continue(state: State) -> str:
    """条件付きエッジ: 次のノードを決定する関数"""
    last_message = state["messages"][-1]
    if "DONE" in last_message.content:
        return "end"
    return "continue"

# Step 3: グラフを構築
builder = StateGraph(State)
builder.add_node("chat", chat_node)
builder.set_entry_point("chat")
builder.add_conditional_edges(
    "chat",
    should_continue,
    {"continue": "chat", "end": END}
)
graph = builder.compile()

# Step 4: 実行
result = graph.invoke({
    "messages": [HumanMessage(content="こんにちは！DONE と書いたら終了します。")]
})
```

---

## ReAct エージェント (ツール呼び出しループ)

```python
from langgraph.prebuilt import create_react_agent
from langchain_anthropic import ChatAnthropic
from langchain_core.tools import tool

# ツール定義
@tool
def search(query: str) -> str:
    """Web を検索して情報を取得します。"""
    return f"検索結果: {query} に関する最新情報..."

@tool
def calculator(expression: str) -> str:
    """数式を計算します。"""
    return str(eval(expression))

# ReAct エージェント (LangGraph の内蔵プリセット)
llm = ChatAnthropic(model="claude-sonnet-4-6")
agent = create_react_agent(llm, tools=[search, calculator])

result = agent.invoke({
    "messages": [HumanMessage(content="東京の人口は？ 東京と大阪の人口の差も計算して。")]
})
```

---

## Human-in-the-Loop (人間の承認)

```python
from langgraph.graph import StateGraph, END
from langgraph.checkpoint.memory import MemorySaver

checkpointer = MemorySaver()  # 状態を保存するチェックポインター

# interrupt_before でノード前に一時停止
graph = builder.compile(
    checkpointer=checkpointer,
    interrupt_before=["approval_required"]  # このノードの前で停止
)

# 実行 (approvalノードの前で一時停止)
config = {"configurable": {"thread_id": "conversation-1"}}
result = graph.invoke({"messages": [...]}, config=config)

# ユーザーの承認後に再開
print("承認しますか？ (y/n): ", end="")
if input() == "y":
    result = graph.invoke(None, config=config)  # None で再開
```

---

## 並行実行 (マルチエージェント)

```python
from langgraph.graph import StateGraph, END

def research_agent(state):
    """並行して実行されるリサーチエージェント"""
    return {"research_result": "調査結果..."}

def writing_agent(state):
    """並行して実行されるライティングエージェント"""
    return {"draft": "下書き..."}

def merge_results(state):
    """並行実行の結果をマージ"""
    return {"final_output": f"{state['research_result']} + {state['draft']}"}

builder = StateGraph(State)
builder.add_node("research", research_agent)
builder.add_node("writing", writing_agent)
builder.add_node("merge", merge_results)

# 並行実行: research と writing を同時スタート
builder.add_edge("start", "research")
builder.add_edge("start", "writing")
# 両方完了後に merge
builder.add_edge(["research", "writing"], "merge")
builder.add_edge("merge", END)
```
$md$,
  'https://langchain-ai.github.io/langgraph/tutorials/',
  '2026-04-25',
  2
),

(
  'langgraph',
  'models',
  'LangGraph 本番実装 — Persistence・サブグラフ・LangGraph Platform デプロイ',
  $md$
## Persistence — 会話状態の永続化

```python
from langgraph.checkpoint.sqlite import SqliteSaver
from langgraph.checkpoint.postgres import PostgresSaver

# SQLite (開発用)
with SqliteSaver.from_conn_string(":memory:") as checkpointer:
    graph = builder.compile(checkpointer=checkpointer)
    config = {"configurable": {"thread_id": "user-123"}}

    # 会話 1 回目
    graph.invoke({"messages": [HumanMessage("こんにちは")]}, config)

    # 会話 2 回目 (前の状態を自動的に引き継ぐ)
    graph.invoke({"messages": [HumanMessage("さっきの続きを教えて")]}, config)

# PostgreSQL (本番用) — Supabase と統合可能
DB_URI = "postgresql://user:pass@host:5432/db"
with PostgresSaver.from_conn_string(DB_URI) as checkpointer:
    graph = builder.compile(checkpointer=checkpointer)
```

---

## サブグラフ — 複雑なシステムを階層化

```python
# サブグラフ: 専門エージェント
support_graph = StateGraph(SupportState)
support_graph.add_node("classify", classify_inquiry)
support_graph.add_node("respond", generate_response)
support_graph.add_edge("classify", "respond")
support_graph.add_edge("respond", END)
support_subgraph = support_graph.compile()

# メイングラフにサブグラフを埋め込む
main_graph = StateGraph(MainState)
main_graph.add_node("router", route_to_department)
main_graph.add_node("support", support_subgraph)  # サブグラフをノードとして追加
main_graph.add_node("billing", billing_subgraph)
main_graph.add_conditional_edges("router", route_fn, {"support": "support", "billing": "billing"})
```

---

## LangGraph Platform でのデプロイ

```bash
# LangGraph Cloud へのデプロイ
pip install langgraph-cli

# langgraph.json 設定ファイル
cat > langgraph.json << EOF
{
  "graphs": {
    "my_agent": "./agent.py:graph"
  },
  "dependencies": ["langchain-anthropic", "langgraph"]
}
EOF

# デプロイ
langgraph up
```

---

## LangChain / CrewAI との使い分け

| フレームワーク | 最適なユースケース |
| :--- | :--- |
| **LangGraph** | 条件分岐・ループ・状態永続化が必要な複雑なエージェント |
| **CrewAI** | 役割分担が明確なマルチエージェントチーム |
| **AutoGen** | Microsoft エコシステム / 会話型マルチエージェント |
| **LangChain** | シンプルなチェーン・RAG (LangGraph の基盤として) |

## クイックスタート (3 ステップ)

1. `pip install langgraph langchain-anthropic` でインストール
2. `StateGraph(State)` でグラフを定義
3. `graph.compile()` してから `graph.invoke({...})` で実行
$md$,
  'https://langchain-ai.github.io/langgraph/how-tos/',
  '2026-04-25',
  3
)

ON CONFLICT DO NOTHING;
