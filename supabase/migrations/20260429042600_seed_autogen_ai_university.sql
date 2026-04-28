-- PS#3 S112: AI大学 318→319社化 — AutoGen (Microsoft/マルチエージェント対話フレームワーク)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'autogen', 'overview',
  'AutoGen — Microsoft マルチエージェント対話フレームワーク・自律ループ・Human-in-the-Loop (GitHub 38k+ / 9/9)',
  $$## AutoGen とは

**AutoGen** は **Microsoft Research が開発するマルチエージェント対話フレームワーク**。GitHub 38,000+ スター。「**複数の AI エージェントが互いに会話してタスクを解決する**」思想が核心。LLM・ツール・人間の入力を組み合わせた **自律ループ (Agentic Loop)** を構築できる。

CrewAI が「役割分担チーム」なのに対し、AutoGen は **「エージェント間の対話プロトコル」** が強み。`ConversableAgent` という基底クラスから任意のエージェントを派生させ、エージェント同士の会話ターンを柔軟に制御できる。**AutoGen v0.4** (2024年末) で全面リアーキテクチャ (AgentChat + Core API 分離)。

## AutoGen のアーキテクチャ

```
AutoGen v0.4 (agentchat API):

  AgentChat (高レベル API):
    ・AssistantAgent: LLM ベースのエージェント
    ・UserProxyAgent: 人間の代理 (Human-in-the-Loop)
    ・CodeExecutorAgent: コード実行専門
    ・GroupChat: 複数エージェントの輪番会話

  Core API (低レベル):
    ・Agent Protocol: メッセージ送受信の基底
    ・Runtime: ローカル / 分散 実行環境
    ・Topic / Subscription: Pub-Sub メッセージング

  会話パターン:
    ・Two-agent chat (2者対話)
    ・Group chat (輪番/SelectSpeaker)
    ・Nested chat (サブタスクへの委譲)
    ・Sequential chat (タスクチェーン)
```

## 主要コンポーネント

```
ConversableAgent (基底):
  ・任意の LLM + システムプロンプトで設定
  ・human_input_mode: NEVER / TERMINATE / ALWAYS
  ・max_consecutive_auto_reply: 自律ループ上限

AssistantAgent:
  ・LLM (Claude / GPT / Gemini) で動作
  ・コード生成・タスク実行・提案生成

UserProxyAgent:
  ・人間の代理エージェント
  ・コード実行 (LocalCommandLineCodeExecutor)
  ・自律モード or 人間確認モード

GroupChatManager:
  ・複数エージェントの会話を管理
  ・スピーカー選択: round_robin / auto / custom

Tool (ツール統合):
  ・@register_for_llm / @register_for_execution
  ・FunctionTool (任意の Python 関数)
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬予想ループ** | アシスタント→コード実行→アシスタントの自律ループ | データ分析→コード生成→結果検証を自律実行 |
| **コード品質向上** | レビュアーエージェントとコーダーエージェントの対話 | PR 品質向上の自動化 |
| **AI大学コンテンツ生成** | リサーチャー+ライター+検証者の Group Chat | provider 情報収集から SQL 生成まで自動化 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'autogen', 'api',
  'AutoGen 実践 — インストール/AssistantAgent/UserProxyAgent/GroupChat/Claude統合/ツール/コード実行',
  $$## インストール

```bash
pip install autogen-agentchat   # AgentChat 高レベル API
pip install autogen-ext[anthropic]  # Claude 統合
pip install autogen-ext[openai]     # OpenAI 統合
```

## 基本: 2エージェント対話 (Claude)

```python
import asyncio
from autogen_agentchat.agents import AssistantAgent
from autogen_agentchat.ui import Console
from autogen_agentchat.conditions import TextMentionTermination
from autogen_agentchat.teams import RoundRobinGroupChat
from autogen_ext.models.anthropic import AnthropicChatCompletionClient

# Claude モデルクライアント
claude_client = AnthropicChatCompletionClient(
    model="claude-haiku-4-5",
    api_key="YOUR_ANTHROPIC_API_KEY",
)

# アシスタントエージェント
assistant = AssistantAgent(
    name="競馬アシスタント",
    model_client=claude_client,
    system_message="あなたは日本競馬の専門AIアシスタントです。データ分析と予想が得意です。",
)

# 終了条件
termination = TextMentionTermination("TERMINATE")

# 単一エージェントチーム (簡易)
team = RoundRobinGroupChat([assistant], termination_condition=termination)

async def main():
    result = await Console(team.run_stream(task="天皇賞春2026の注目馬を3頭教えてください。終わったら TERMINATE と言ってください。"))
    return result

asyncio.run(main())
```

## GroupChat (複数エージェント)

```python
import asyncio
from autogen_agentchat.agents import AssistantAgent
from autogen_agentchat.conditions import MaxMessageTermination
from autogen_agentchat.teams import SelectorGroupChat
from autogen_ext.models.anthropic import AnthropicChatCompletionClient
from autogen_ext.models.openai import OpenAIChatCompletionClient

claude = AnthropicChatCompletionClient(model="claude-haiku-4-5", api_key="YOUR_KEY")
claude_sonnet = AnthropicChatCompletionClient(model="claude-sonnet-4-6", api_key="YOUR_KEY")

# 役割ごとにエージェントを定義
researcher = AssistantAgent(
    name="リサーチャー",
    model_client=claude,
    system_message="出走馬の基本データ・戦績・騎手情報を収集・整理します。",
)

analyst = AssistantAgent(
    name="アナリスト",
    model_client=claude,
    system_message="リサーチャーのデータを受けて、統計的観点から各馬を評価します。",
)

predictor = AssistantAgent(
    name="予想師",
    model_client=claude_sonnet,
    system_message="アナリストの評価を元に最終予想と買い目を決定します。",
)

# Selector が自動でスピーカーを選択
termination = MaxMessageTermination(max_messages=10)
team = SelectorGroupChat(
    [researcher, analyst, predictor],
    model_client=claude_sonnet,  # スピーカー選択に使う LLM
    termination_condition=termination,
)

async def run_group_chat():
    from autogen_agentchat.ui import Console
    result = await Console(team.run_stream(task="天皇賞春2026の予想をチームで作成してください"))
    return result

asyncio.run(run_group_chat())
```

## ツール統合

```python
from autogen_agentchat.agents import AssistantAgent
from autogen_ext.models.anthropic import AnthropicChatCompletionClient

# ツール関数 (Python 関数をそのまま)
async def get_race_results(race_name: str, year: int) -> str:
    """指定レースの結果を Supabase から取得"""
    # Supabase REST API 呼び出し
    import httpx
    url = f"https://your-project.supabase.co/rest/v1/race_results"
    params = {"race_name": f"eq.{race_name}", "year": f"eq.{year}"}
    async with httpx.AsyncClient() as client:
        resp = await client.get(url, params=params, headers={"apikey": "YOUR_KEY"})
    return str(resp.json())

async def calculate_horse_score(horse_name: str) -> str:
    """馬のスコアを計算"""
    # ロジック実装
    return f"{horse_name}: 総合スコア 85/100"

# ツール付きエージェント
claude_client = AnthropicChatCompletionClient(model="claude-sonnet-4-6", api_key="YOUR_KEY")

agent = AssistantAgent(
    name="競馬予想エージェント",
    model_client=claude_client,
    tools=[get_race_results, calculate_horse_score],
    system_message="ツールを使って競馬データを収集・分析し予想を立てます。",
    reflect_on_tool_use=True,  # ツール結果を LLM が反省
)
```

## コード実行エージェント (LocalCommandLineCodeExecutor)

```python
import asyncio
from autogen_agentchat.agents import AssistantAgent, CodeExecutorAgent
from autogen_agentchat.conditions import TextMentionTermination
from autogen_agentchat.teams import RoundRobinGroupChat
from autogen_ext.code_executors.local import LocalCommandLineCodeExecutor
from autogen_ext.models.anthropic import AnthropicChatCompletionClient
import tempfile, os

work_dir = tempfile.mkdtemp()

# コード実行エージェント (LLM なし / 実際にコードを実行)
code_executor = CodeExecutorAgent(
    name="コード実行エージェント",
    code_executor=LocalCommandLineCodeExecutor(work_dir=work_dir),
)

# コード生成エージェント (LLM あり)
claude_client = AnthropicChatCompletionClient(model="claude-haiku-4-5", api_key="YOUR_KEY")
coder = AssistantAgent(
    name="コーダー",
    model_client=claude_client,
    system_message="Python コードを書いて競馬データを分析します。コードブロック ```python ... ``` で囲んでください。",
)

termination = TextMentionTermination("TERMINATE")
team = RoundRobinGroupChat([coder, code_executor], termination_condition=termination)

async def main():
    from autogen_agentchat.ui import Console
    await Console(team.run_stream(task="過去5年の天皇賞春の1着馬と人気をリストアップするPythonコードを書いて実行してください。終わったら TERMINATE"))

asyncio.run(main())
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 318→319社化: AutoGen 追加',
  'PS#3 S112。AutoGen (Microsoft Research製/マルチエージェント対話フレームワーク/AssistantAgent+UserProxyAgent+GroupChat/SelectorGroupChat/ツール統合/コード実行/Claude統合/GitHub 38k+/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
