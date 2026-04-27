---
title: "LangGraph State Machine Patterns — How to Stop AI Agents from Going Off-Script"
tags: ai,programming,python,webdev
published: true
---

# LangGraph State Machine Patterns — How to Stop AI Agents from Going Off-Script

## The "Agent Does Something Unexpected" Problem

LLM-powered agents that run outside their intended scope — infinite loops, unauthorized operations, non-interruptible processes. This happens when agent state management is implicit rather than defined.

LangGraph solves this with a graph-based state machine that makes state transitions explicit. Built on LangChain, it lets you define exactly which states exist and how the agent moves between them.

---

## Core Concepts

| Concept | Description |
|---------|-------------|
| **State** | Data structure the agent holds (TypedDict) |
| **Node** | Processing unit that transforms state (a function) |
| **Edge** | Transition rules between nodes (supports conditional branching) |
| **Checkpoint** | State snapshot for resume and rollback |

---

## Pattern 1: Linear Chain

```python
from langgraph.graph import StateGraph, END
from typing import TypedDict

class AgentState(TypedDict):
    messages: list[str]
    result: str

def analyze(state: AgentState) -> AgentState:
    result = llm.invoke(state["messages"])
    return {"result": result.content}

def validate(state: AgentState) -> AgentState:
    if len(state["result"]) < 10:
        return {"result": "ERROR: result too short"}
    return state

graph = StateGraph(AgentState)
graph.add_node("analyze", analyze)
graph.add_node("validate", validate)
graph.add_edge("analyze", "validate")
graph.add_edge("validate", END)
graph.set_entry_point("analyze")

app = graph.compile()
result = app.invoke({"messages": ["Analyze this"], "result": ""})
```

---

## Pattern 2: Conditional Router

Branch based on LLM output:

```python
class RoutingState(TypedDict):
    query: str
    route: str
    answer: str

def router(state: RoutingState) -> str:
    if "SQL" in state["query"] or "database" in state["query"]:
        return "sql_node"
    elif "code" in state["query"]:
        return "code_node"
    else:
        return "general_node"

graph = StateGraph(RoutingState)
graph.add_node("router_node", classify_query)
graph.add_node("sql_node", handle_sql)
graph.add_node("code_node", handle_code)
graph.add_node("general_node", handle_general)

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

The agent can only go to nodes you've explicitly defined. Out-of-scope destinations are structurally impossible.

---

## Pattern 3: Loop Control (Max Attempts)

Prevent infinite loops with a counter in state:

```python
class RetryState(TypedDict):
    task: str
    result: str
    attempts: int
    max_attempts: int

def should_retry(state: RetryState) -> str:
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
        "retry": "execute",  # Loop back
        "done": END,
        "give_up": "give_up"
    }
)
```

`max_attempts` in State means the caller controls the limit — no code changes needed to adjust retry behavior.

---

## Pattern 4: Checkpointing for Long Tasks

Pause and resume long-running agent tasks:

```python
from langgraph.checkpoint.sqlite import SqliteSaver

checkpointer = SqliteSaver.from_conn_string("checkpoints.db")
app = graph.compile(checkpointer=checkpointer)

# Thread ID scopes state to a specific user + task
config = {"configurable": {"thread_id": "user-123-task-456"}}
result = app.invoke(initial_state, config=config)

# Resume from where it left off
result2 = app.invoke(None, config=config)  # None resumes from checkpoint
```

Combined with Supabase Edge Functions: use a request ID as the thread ID and state automatically isolates per-user, per-task without extra logic.

---

## Real Application: CS Auto-Reply

```python
class CSState(TypedDict):
    ticket: str
    category: str
    response: str
    escalated: bool

def classify(state): ...  # FAQ / bug / feature request
def auto_reply(state): ...  # Auto-reply if FAQ
def escalate(state): ...   # Route bugs and feature requests to humans

def should_escalate(state: CSState) -> str:
    if state["category"] in ["bug", "feature"]:
        return "escalate"
    return "auto_reply"
```

The state machine structure provides a hard guarantee: bugs and feature requests always reach a human. The agent cannot accidentally auto-close a bug report.

---

## Caveats

- **Python only**: No Deno/TypeScript support — better suited for Python services than Supabase Edge Functions
- **LangChain dependency**: Subject to LangChain version changes
- **Async**: Supported, but async checkpointing uses a different class
- **Visualization**: `graph.get_graph().draw_mermaid()` outputs a flow diagram

---

## Summary

LangGraph applies state machine discipline to AI agents. Instead of "let the agent figure it out," you define exactly which states exist and how transitions happen.

Three patterns cover most production needs:
- **Router**: structurally prevent out-of-scope actions
- **Loop control**: `max_attempts` in state prevents runaway execution
- **Checkpointing**: long-running tasks can pause and resume safely

Controllable agents are more reliable than autonomous ones for production use.

→ [Learn LangGraph in Jibun Kaisha's AI University](https://my-web-app-b67f4.web.app/)
