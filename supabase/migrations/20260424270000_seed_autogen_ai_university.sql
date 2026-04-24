-- Session PS#3-S41: AI大学 177社化 — AutoGen 追加
-- Microsoft Research 発の OSS マルチエージェントフレームワーク。Actor Model 採用の v0.4 で大幅刷新。
-- AgentChat API (会話型エージェント) + AutoGen Core (分散 Actor) + AutoGen Studio (ノーコード UI)。
-- GitHub 40k+ Stars / pip install autogen-agentchat / Claude / GPT / Gemini / Ollama 対応。
-- 企業・研究コミュニティで最大シェアのマルチエージェント OSS フレームワーク。
-- Step 0: 9/9 (Microsoft Research / 40k+ Stars / AgentChat+Core+Studio 3層 / Enterprise実績 / Claude対応)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'autogen',
  'overview',
  'AutoGen — Microsoft Research 発マルチエージェント OSS (40k+ Stars / Actor Model)',
  $md$
# AutoGen — The Open-Source Multi-Agent Framework by Microsoft Research

**Microsoft Research** が開発・公開するマルチエージェント会話フレームワーク。
複数の AI エージェントが協調して複雑なタスクを解決する OSS として、
研究・エンタープライズ双方で最大シェアを誇る。

2025 年の v0.4 で **Actor Model** を採用した大幅リアーキテクチャを実施。
GitHub Stars **40,000+** / PyPI 週次 DL 数百万件。

## 3 層アーキテクチャ (v0.4)

| 層 | パッケージ | 用途 |
| :--- | :--- | :--- |
| **AgentChat** | `autogen-agentchat` | 会話型エージェント API (最多利用) |
| **AutoGen Core** | `autogen-core` | Actor Model / 分散エージェント / 非同期 |
| **AutoGen Studio** | `autogen-studio` | ノーコードビジュアルビルダー (Web UI) |
| **Extensions** | `autogen-ext` | LLM クライアント / ツール / メモリ拡張 |

## 対応 LLM

OpenAI GPT-4o / Anthropic Claude / Google Gemini / Azure OpenAI /
AWS Bedrock / Ollama (ローカル) / Mistral / Groq / HuggingFace

## 採用規模

- **GitHub Stars**: 40,000+
- **PyPI DL**: 週次数百万件
- **採用組織**: Microsoft 社内 / Fortune 500 各社 / 学術研究機関
$md$,
  'https://microsoft.github.io/autogen/',
  '2026-04-24',
  1
),

(
  'autogen',
  'models',
  'AutoGen AgentChat アーキテクチャ & エージェント種別 (v0.4)',
  $md$
## AgentChat の主要コンセプト

### エージェント種別

| エージェント | 説明 |
| :--- | :--- |
| **AssistantAgent** | LLM を使ってタスクを実行する汎用エージェント |
| **UserProxyAgent** | 人間の代理 / コード実行 / 人間承認フロー |
| **CodeExecutorAgent** | コードを安全に実行する専用エージェント |
| **SocietyOfMindAgent** | 内部にチームを持つ再帰的エージェント |

### グループチャット種別

| チャットモード | 説明 |
| :--- | :--- |
| **RoundRobinGroupChat** | エージェントが順番に発話 |
| **SelectorGroupChat** | LLM が次の発話者を選択 |
| **Swarm** | ハンドオフによる動的エージェント選択 |
| **MagenticOneGroupChat** | Microsoft MagneticOne 統合 |

### Human-in-the-Loop

- `MaxMessageTermination` — メッセージ数上限で自動終了
- `TextMentionTermination` — "TERMINATE" キーワードで終了
- `HandoffTermination` — 人間へのハンドオフで一時停止

## AutoGen Core — Actor Model

- 分散・非同期エージェント実行
- メッセージパッシングによるエージェント間通信
- スケーラブルなマルチホスト構成をサポート

## AutoGen Studio (ノーコード)

- Web UI でエージェントチームをビジュアル設計
- ドラッグ & ドロップでワークフロー構築
- テスト実行・ログ閲覧がブラウザから可能
$md$,
  'https://microsoft.github.io/autogen/stable/user-guide/agentchat-user-guide/',
  '2026-04-24',
  2
),

(
  'autogen',
  'api',
  'AutoGen API 入門 — マルチエージェント構築 (v0.4)',
  $md$
## AutoGen の始め方

### インストール

```bash
pip install autogen-agentchat autogen-ext[openai,anthropic]
```

### AI 大学リサーチチームを構築

```python
import asyncio
from autogen_agentchat.agents import AssistantAgent
from autogen_agentchat.teams import RoundRobinGroupChat
from autogen_agentchat.conditions import MaxMessageTermination
from autogen_ext.models.anthropic import AnthropicChatCompletionClient

# Anthropic Claude クライアント
claude_client = AnthropicChatCompletionClient(
    model="claude-opus-4-7",
)

# エージェント 1: リサーチャー
researcher = AssistantAgent(
    name="Researcher",
    model_client=claude_client,
    system_message="""あなたは AI 業界のリサーチャーです。
    最新の AI プロバイダーについて詳しく調査・報告してください。""",
)

# エージェント 2: ライター
writer = AssistantAgent(
    name="Writer",
    model_client=claude_client,
    system_message="""あなたはテクニカルライターです。
    リサーチャーの成果を日本語の読みやすい記事に仕上げてください。
    完成したら 'TERMINATE' と出力してください。""",
)

# チームを組成
team = RoundRobinGroupChat(
    [researcher, writer],
    termination_condition=MaxMessageTermination(max_messages=6),
)

async def main():
    result = await team.run(
        task="AutoGen の主要機能と CrewAI との違いを調査・記事化してください"
    )
    print(result.messages[-1].content)

asyncio.run(main())
```

### Swarm — ハンドオフによる動的ルーティング

```python
from autogen_agentchat.agents import AssistantAgent
from autogen_agentchat.teams import Swarm
from autogen_agentchat.messages import HandoffMessage

# トリアージエージェント
triage = AssistantAgent(
    name="Triage",
    model_client=claude_client,
    handoffs=["TechAgent", "BizAgent"],
    system_message="""質問の種類を判断して適切なエージェントにハンドオフしてください。
    技術的な質問 → TechAgent へ
    ビジネス的な質問 → BizAgent へ""",
)

tech_agent = AssistantAgent(name="TechAgent", model_client=claude_client,
    system_message="技術的な質問に詳しく答えてください。完了後 'TERMINATE'")
biz_agent = AssistantAgent(name="BizAgent", model_client=claude_client,
    system_message="ビジネス的な質問に答えてください。完了後 'TERMINATE'")

swarm = Swarm([triage, tech_agent, biz_agent])

async def route():
    result = await swarm.run(task="AutoGen の月額コストはどれくらいですか？")
    print(result.messages[-1].content)
```

### コード実行エージェント

```python
from autogen_agentchat.agents import CodeExecutorAgent
from autogen_ext.code_executors.local import LocalCommandLineCodeExecutor

# コードを安全に実行
executor = CodeExecutorAgent(
    name="CodeRunner",
    code_executor=LocalCommandLineCodeExecutor(work_dir="/tmp/autogen"),
)
```

## クイックスタート

1. `pip install autogen-agentchat autogen-ext[anthropic]` でインストール
2. `AssistantAgent` に `model_client` と `system_message` を設定
3. `RoundRobinGroupChat` でチームを組み `team.run(task="...")` で実行
4. `MaxMessageTermination` または `TextMentionTermination("TERMINATE")` で終了制御
5. 本格運用: AutoGen Studio でビジュアル設計 → `autogen-studio ui --port 8081`
$md$,
  'https://microsoft.github.io/autogen/stable/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
