---
title: "LangGraph ステートマシンパターン — AIエージェントの「暴走」を防ぐ設計手法"
tags: AI,programming,個人開発,python
published: true
---

# LangGraph ステートマシンパターン — AIエージェントの「暴走」を防ぐ設計手法

## 「エージェントが意図しない動作をする」問題

LLM を使ったエージェントが予想外の動作をする — 無限ループ、スコープ外の操作、中断不能な処理。これはエージェントの状態管理が不明確なときに起きる。

LangGraph は「グラフ構造のステートマシン」でこの問題を解決するフレームワークだ。LangChain の上に構築され、エージェントの状態遷移を明示的に定義できる。

---

## LangGraph の基本概念

| 概念 | 説明 |
|------|------|
| **State** | エージェントが保持するデータ構造 (TypedDict) |
| **Node** | 状態を変換する処理単位 (関数) |
| **Edge** | ノード間の遷移ルール (条件付き分岐可) |
| **Checkpoint** | 状態のスナップショット (再開・ロールバック用) |

---

## 基本パターン: 線形チェーン

```python
from langgraph.graph import StateGraph, END
from typing import TypedDict

class AgentState(TypedDict):
    messages: list[str]
    result: str

def analyze(state: AgentState) -> AgentState:
    # LLM 呼び出し
    result = llm.invoke(state["messages"])
    return {"result": result.content}

def validate(state: AgentState) -> AgentState:
    # 結果検証
    if len(state["result"]) < 10:
        return {"result": "ERROR: 結果が短すぎる"}
    return state

# グラフ定義
graph = StateGraph(AgentState)
graph.add_node("analyze", analyze)
graph.add_node("validate", validate)
graph.add_edge("analyze", "validate")
graph.add_edge("validate", END)
graph.set_entry_point("analyze")

app = graph.compile()
result = app.invoke({"messages": ["分析して"], "result": ""})
```

---

## 実践パターン: 条件分岐 (Router)

LLM の出力によって次の処理を分岐させる:

```python
from langgraph.graph import StateGraph, END

class RoutingState(TypedDict):
    query: str
    route: str
    answer: str

def router(state: RoutingState) -> str:
    """どのノードに進むか決定"""
    if "SQL" in state["query"] or "データベース" in state["query"]:
        return "sql_node"
    elif "コード" in state["query"]:
        return "code_node"
    else:
        return "general_node"

graph = StateGraph(RoutingState)
graph.add_node("router_node", classify_query)
graph.add_node("sql_node", handle_sql)
graph.add_node("code_node", handle_code)
graph.add_node("general_node", handle_general)

# 条件付きエッジ
graph.add_conditional_edges(
    "router_node",
    router,
    {
        "sql_node": "sql_node",
        "code_node": "code_node",
        "general_node": "general_node"
    }
)
```

---

## 実践パターン: ループ制御 (最大試行数)

エージェントの「無限ループ」を防ぐ:

```python
class RetryState(TypedDict):
    task: str
    result: str
    attempts: int
    max_attempts: int

def should_retry(state: RetryState) -> str:
    """再試行するかどうか判定"""
    if state["attempts"] >= state["max_attempts"]:
        return "give_up"
    if "ERROR" in state["result"]:
        return "retry"
    return "done"

graph = StateGraph(RetryState)
graph.add_node("execute", execute_task)
graph.add_node("give_up", handle_failure)

graph.add_conditional_edges(
    "execute",
    should_retry,
    {
        "retry": "execute",   # ループバック
        "done": END,
        "give_up": "give_up"
    }
)
```

`max_attempts` を State に持たせることで、外部から上限を注入できる。

---

## Checkpoint: 中断・再開

長時間タスクを途中で止めて後から再開:

```python
from langgraph.checkpoint.sqlite import SqliteSaver

# SQLite で状態を永続化
checkpointer = SqliteSaver.from_conn_string("checkpoints.db")
app = graph.compile(checkpointer=checkpointer)

# スレッドID で実行 (同一スレッドは状態を引き継ぐ)
config = {"configurable": {"thread_id": "user-123-task-456"}}
result = app.invoke(initial_state, config=config)

# 別の実行で再開
result2 = app.invoke(None, config=config)  # Noneで前回状態から再開
```

Supabase Edge Function と組み合わせる場合、スレッドIDをリクエストIDとして使うと状態が自動的にユーザー・タスク単位で分離される。

---

## 自分株式会社での活用パターン

### CS (カスタマーサポート) 自動応答

```python
class CSState(TypedDict):
    ticket: str
    category: str
    response: str
    escalated: bool

def classify(state): ...  # FAQ / bug / feature request 分類
def auto_reply(state): ...  # FAQ なら自動返信
def escalate(state): ...   # バグ・要望は人間にエスカレーション

def should_escalate(state: CSState) -> str:
    if state["category"] in ["bug", "feature"]:
        return "escalate"
    return "auto_reply"
```

LangGraph のステートマシンにより、「FAQ 以外は必ず人間に届く」という保証が取れる。

---

## LangGraph の注意点

- **Python 専用**: Deno / TypeScript では使えない → Supabase EF より Python サービス向き
- **LangChain 依存**: LangChain のバージョン変化の影響を受ける
- **非同期**: `async` 対応済みだが、checkpoint の非同期実装は別クラス
- **可視化**: `graph.get_graph().draw_mermaid()` でフロー図を出力できる

---

## まとめ

LangGraph は「AIエージェントの状態を明示的に管理する」ツールだ。

- **ループ制御**: `max_attempts` で暴走を防ぐ
- **条件分岐**: Router パターンでスコープ外動作を防ぐ
- **Checkpoint**: 長時間タスクを安全に中断・再開

「エージェントに全部任せる」のではなく、「ステートマシンで制御する」という発想の転換が、本番に耐えるエージェント設計の鍵だ。

→ [自分株式会社 AI 大学で LangGraph を学ぶ](https://my-web-app-b67f4.web.app/)
