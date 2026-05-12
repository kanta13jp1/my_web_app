-- PS#3 S132: AI大学 358→359社化 — LangGraph (ステートフルエージェント / グラフ実行 / サイクル制御)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'langgraph', 'overview',
  'LangGraph — ステートフルマルチエージェント・グラフ型ワークフロー・サイクル・ヒューマンインザループ (9/9)',
  $$## LangGraph とは

**LangGraph** は LangChain チームが開発したステートフルなエージェントワークフローフレームワーク。「グラフ構造」でエージェントの処理フローを定義し、**サイクル (ループ)** を含む複雑な実行パターンを実現する。

CrewAI / AutoGen と同じマルチエージェントカテゴリだが、**より低レイヤー**な位置づけで、エージェントの状態管理・条件分岐・ロールバックを精密に制御できる。

## LangGraph のコアコンセプト: グラフとして考える

```
従来の LLM チェーン (線形):
  A → B → C → 終了

LangGraph (グラフ型):
  START
    ↓
  agent_node ←────────────┐
    ↓                      │
  tool_node               │ (ツール呼び出しが必要な場合はループ)
    ↓                      │
  should_continue? ────────┘
    ↓ (終了条件を満たした場合)
  END

  ↑ サイクルを含む複雑な実行が可能
```

## 実際のコード例

```python
from langgraph.graph import StateGraph, END
from typing import TypedDict, Annotated
import operator

# 状態の型定義 (TypedDict)
class AgentState(TypedDict):
    messages: Annotated[list, operator.add]  # メッセージ履歴
    next: str  # 次のノード

# グラフを構築
workflow = StateGraph(AgentState)

# ノード (処理ステップ) を追加
workflow.add_node("agent", call_agent)      # LLM呼び出し
workflow.add_node("tools", call_tools)      # ツール実行
workflow.add_node("human_review", pause)   # 人間確認

# エッジ (遷移) を定義
workflow.set_entry_point("agent")

# 条件分岐エッジ
workflow.add_conditional_edges(
    "agent",
    should_continue,  # どこに進むか決定する関数
    {
        "tools": "tools",        # ツールが必要
        "human": "human_review", # 人間確認が必要
        "end": END               # 終了
    }
)

# ツール実行後は agent に戻る (サイクル)
workflow.add_edge("tools", "agent")
workflow.add_edge("human_review", "agent")

# コンパイルして実行
app = workflow.compile(
    checkpointer=MemorySaver()  # 状態を永続化
)

result = app.invoke({"messages": [HumanMessage("データを分析して")]})
```

## LangGraph の主要機能

```
LangGraph の強み:

  1. Checkpointing (状態永続化):
    ・実行途中の状態を保存
    ・中断 → 再開が可能
    ・デバッグ時に任意のステップから再実行

  2. Human-in-the-Loop:
    ・任意のノードで実行を一時停止
    ・人間が状態を確認・修正してから再開
    ・interrupt_before / interrupt_after で制御

  3. Multi-agent coordination:
    ・Supervisor (管理者) エージェント
    ・Worker エージェントを動的に呼び出し
    ・並列実行も対応

  4. LangGraph Studio:
    ・グラフをビジュアルで確認
    ・デバッグツール内蔵
    ・LangSmith と統合
```

## LangGraph vs CrewAI vs AutoGen

| 項目 | LangGraph | CrewAI | AutoGen |
|------|-----------|--------|---------|
| 抽象レベル | 低 (精密制御) | 中 (役割定義) | 中 (会話型) |
| 状態管理 | ◎ (TypedDict) | △ | △ |
| サイクル | ◎ (ネイティブ) | △ | △ |
| 学習コスト | 高 | 低 | 中 |
| 柔軟性 | ◎ | ○ | ○ |

## LangGraph Cloud / Platform

- **LangGraph Cloud**: マネージドホスティング (LangSmith に統合)
- **LangGraph Studio**: デスクトップ GUI でグラフを可視化・デバッグ
- **LangGraph API**: REST API でエージェントをサービスとして公開

## 自分株式会社との関連

LangGraph の「Checkpointing + Human-in-the-Loop + 条件分岐グラフ」アーキテクチャは、自分株式会社の GitHub Actions ワークフローと同構造。GHA の `job` = LangGraph の `node`、`needs` = エッジ、`if: failure()` = 条件分岐エッジ。`claude-agent-review.yml` の「AI レビュー → 条件判断 → マージ or 修正依頼」サイクルは LangGraph のループそのもの。
$$,
  'https://github.com/langchain-ai/langgraph',
  NOW(),
  359
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
