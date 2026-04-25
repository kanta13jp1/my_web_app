-- Session PS#3-S46: AI大学 191→192社化 — Composio 追加
-- AI エージェントが外部サービス (GitHub/Slack/Gmail など 250+) と連携するためのツール統合プラットフォーム。
-- OAuth 2.0 の複雑な認証処理を代行し、LangGraph・CrewAI・OpenAI Agents SDK と統合。
-- Kleiner Perkins 主導の Series A $53.2M 調達 / Y Combinator S23 卒業生。
-- Step 0: 8.5/9 (エージェント時代の必須インフラ / 250+統合 / $53M / OpenAI公式パートナー)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'composio',
  'overview',
  'Composio — AI エージェントが 250+ の外部サービスと連携するためのツール統合プラットフォーム',
  $md$
# Composio — AI Agent Tool Integration Platform

**AI エージェントが外部サービスと安全に連携する**ための統合プラットフォーム。

GitHub・Slack・Gmail・Linear・Notion など **250+ のアプリ/API** との接続を提供し、
OAuth 2.0 の複雑な認証処理・トークン管理・セキュリティを完全に代行する。
LangGraph・CrewAI・AutoGen・OpenAI Agents SDK など主要フレームワークに対応。

**Y Combinator S23 卒業 / Kleiner Perkins 主導 $53.2M Series A 調達**。

## なぜ Composio か

| 課題 | Composio の解決策 |
| :--- | :--- |
| OAuth 実装が複雑 | **Managed Auth** — OAuth 2.0 フローを完全代行 |
| API ごとにツール実装が必要 | **250+ Pre-built Tools** — すぐに使えるツール群 |
| エージェントの権限管理が難しい | **Tool Permissions** — 最小権限の自動適用 |
| フレームワーク間の互換性 | **Universal Support** — LangGraph/CrewAI/AutoGen 対応 |
| ツール実行のデバッグが困難 | **Dashboard** — リアルタイム実行ログ |

## 対応サービス (抜粋)

| カテゴリ | サービス |
| :--- | :--- |
| **開発ツール** | GitHub, GitLab, Linear, Jira, Notion |
| **コミュニケーション** | Slack, Discord, Gmail, Outlook, Teams |
| **生産性** | Google Calendar, Google Drive, Dropbox |
| **CRM/営業** | Salesforce, HubSpot, Pipedrive |
| **AI/データ** | Supabase, Airtable, Snowflake |

## エコシステム統合

```
OpenAI Agents SDK ─┐
CrewAI             ──── Composio ──── 250+ Apps
LangGraph          ─┘
AutoGen            ─┘
```

## ビジネスモデル

- **Free**: 月 1,000 ツール実行まで
- **Pro**: $29/月 (無制限実行・優先サポート)
- **Enterprise**: カスタム (SOC 2 Type II 認定・オンプレ対応)
$md$,
  'https://composio.dev/',
  '2026-04-25',
  1
),

(
  'composio',
  'api',
  'Composio 入門 — LangGraph・CrewAI・OpenAI Agents SDK との統合パターン',
  $md$
## インストール

```bash
pip install composio-core composio-langchain
# または
pip install composio-core composio-crewai
```

---

## 1. LangGraph との統合

```python
from composio_langchain import Action, ComposioToolSet
from langchain_anthropic import ChatAnthropic
from langgraph.prebuilt import create_react_agent

# Composio ツールセットを初期化
toolset = ComposioToolSet()

# GitHub ツールを取得 (issues 読み書き・PR 管理など)
tools = toolset.get_tools(
    actions=[
        Action.GITHUB_CREATE_AN_ISSUE,
        Action.GITHUB_LIST_OPEN_PULL_REQUESTS,
        Action.SLACK_SEND_MESSAGE,
    ]
)

# LangGraph ReAct エージェントに渡す
llm = ChatAnthropic(model="claude-sonnet-4-6")
agent = create_react_agent(llm, tools)

result = agent.invoke({
    "messages": [{
        "role": "user",
        "content": "GitHub の未解決 issue を Slack #dev-updates に投稿して"
    }]
})
```

---

## 2. CrewAI との統合

```python
from composio_crewai import Action, ComposioToolSet
from crewai import Agent, Task, Crew

toolset = ComposioToolSet()
github_tools = toolset.get_tools(
    actions=[Action.GITHUB_CREATE_AN_ISSUE, Action.GITHUB_LIST_OPEN_PULL_REQUESTS]
)

# CrewAI エージェントに Composio ツールを渡す
engineer = Agent(
    role="Software Engineer",
    goal="GitHub リポジトリを管理する",
    backstory="GitHub 操作を自動化する AI エンジニア",
    tools=github_tools,
    verbose=True,
)

task = Task(
    description="先週のPRをすべて確認してサマリーを作成する",
    agent=engineer,
)

crew = Crew(agents=[engineer], tasks=[task])
result = crew.kickoff()
```

---

## 3. OpenAI Agents SDK との統合

```python
from composio_openai import Action, ComposioToolSet
from openai import OpenAI

client = OpenAI()
toolset = ComposioToolSet()

# ツールを OpenAI の tool_choice 形式で取得
tools = toolset.get_tools(
    actions=[
        Action.GMAIL_SEND_EMAIL,
        Action.GOOGLE_CALENDAR_CREATE_EVENT,
    ]
)

response = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "明日の10時に MTG を Google Calendar に追加して"}],
    tools=tools,
)

# ツール呼び出しを Composio で実行
result = toolset.handle_tool_calls(response)
```

---

## 4. OAuth 認証のセットアップ

```bash
# CLI で接続
composio add github     # GitHub OAuth フロー開始
composio add slack      # Slack OAuth フロー開始
composio add gmail      # Gmail OAuth フロー開始

# 接続済みアカウントを確認
composio connections

# コードから接続状態を確認
from composio import ComposioToolSet

toolset = ComposioToolSet(api_key="your-api-key")
connections = toolset.get_connected_accounts()
```

---

## 5. カスタムツールの作成

```python
from composio import ComposioToolSet, action

toolset = ComposioToolSet()

@action(toolname="my_custom_tool")
def fetch_internal_data(query: str) -> dict:
    """
    社内データベースから情報を取得します。

    :param query: 検索クエリ
    :return: 検索結果
    """
    # 社内 API を呼び出す
    results = internal_api.search(query)
    return {"results": results, "count": len(results)}

# カスタムツールをエージェントに追加
tools = toolset.get_tools(actions=[fetch_internal_data])
```
$md$,
  'https://docs.composio.dev/',
  '2026-04-25',
  2
),

(
  'composio',
  'models',
  'Composio 本番実装 — Enterprise 機能・セキュリティ・コスト最適化',
  $md$
## エンタープライズ機能

### Managed Authentication (認証の完全代行)

```python
# ユーザーごとの OAuth 接続を管理
from composio import ComposioToolSet

# entity_id でユーザーを区別 (マルチテナント対応)
toolset = ComposioToolSet(
    api_key="your-api-key",
    entity_id="user-123"  # ユーザーごとに異なる接続を管理
)

# ユーザーに OAuth 接続 URL を発行
request = toolset.initiate_connection(
    app="github",
    redirect_url="https://your-app.com/callback"
)
print(f"認証 URL: {request.redirectUrl}")

# 接続完了後のコールバック処理
connection = toolset.get_connected_account(connection_id)
```

---

### Tool Filtering (最小権限の原則)

```python
# 必要なアクションのみを許可
tools = toolset.get_tools(
    actions=[
        # 読み取りのみ (書き込み禁止)
        Action.GITHUB_LIST_OPEN_PULL_REQUESTS,
        Action.GITHUB_GET_AN_ISSUE,
        # Slack は投稿のみ
        Action.SLACK_SEND_MESSAGE,
    ]
)

# タグでフィルタリング (カテゴリ単位)
read_only_tools = toolset.get_tools(tags=["github:read"])
```

---

### Trigger (リアルタイムイベント処理)

```python
from composio import ComposioToolSet, Trigger

toolset = ComposioToolSet()

# GitHub PR 作成時にトリガー
@toolset.listener(filters=Trigger.GITHUB_PULL_REQUEST_EVENT)
def on_pr_created(event):
    pr = event.payload
    print(f"新しい PR: {pr['title']} by {pr['user']['login']}")

    # 自動で Slack 通知
    toolset.execute_action(
        action=Action.SLACK_SEND_MESSAGE,
        params={
            "channel": "#dev-updates",
            "text": f"新 PR: {pr['title']} — {pr['html_url']}"
        }
    )

toolset.start_triggers()  # イベントリスニング開始
```

---

## Supabase との統合パターン (このプロジェクト向け)

```python
from composio_langchain import Action, ComposioToolSet
from langchain_anthropic import ChatAnthropic
from langgraph.prebuilt import create_react_agent
import os

# 自分株式会社のエージェント: GitHub Issue → Supabase 自動登録
toolset = ComposioToolSet(api_key=os.getenv("COMPOSIO_API_KEY"))
tools = toolset.get_tools(
    actions=[
        Action.GITHUB_LIST_OPEN_ISSUES,
        Action.GITHUB_CREATE_AN_ISSUE,
        Action.SLACK_SEND_MESSAGE,
    ]
)

llm = ChatAnthropic(model="claude-sonnet-4-6")
agent = create_react_agent(llm, tools)

# 毎日 GitHub Issue をチェックして Slack に報告
result = agent.invoke({
    "messages": [{
        "role": "user",
        "content": "kanta13jp1/my_web_app の open issue で label=bug のものを Slack #bugs に投稿"
    }]
})
```

## クイックスタート (3 ステップ)

1. `pip install composio-core composio-langchain` でインストール
2. `composio add github` で GitHub 接続 (OAuth 自動処理)
3. `toolset.get_tools([Action.GITHUB_CREATE_AN_ISSUE])` でツール取得 → エージェントに渡す
$md$,
  'https://docs.composio.dev/patterns/tools/use-tools/use-specific-actions',
  '2026-04-25',
  3
)

ON CONFLICT DO NOTHING;
