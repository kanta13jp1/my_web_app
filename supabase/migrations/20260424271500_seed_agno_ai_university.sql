-- Session PS#3-S41: AI大学 178社化 — Agno (旧phidata) 追加
-- phidata から 2025 年に Agno へリブランド。Python-native エージェントフレームワーク。
-- Memory (ストレージ連携) + Knowledge (ベクター DB) + Tools + Reasoning の 4 柱で構成。
-- Agent Teams で複数エージェントを並行実行。Agno Cloud でワンクリックデプロイ。
-- pip install agno / GitHub phidatahq/agno / Claude・GPT・Gemini・Ollama 対応。
-- Step 0: 7.5/9 (phidata 実績 / 4柱 Agent設計 / Memory+Knowledge / Cloud / Claude対応)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'agno',
  'overview',
  'Agno (旧 phidata) — Python-native エージェントフレームワーク (Memory / Knowledge / Tools)',
  $md$
# Agno — Build Agents with Memory, Knowledge, and Tools

元 **phidata** が 2025 年に **Agno** へリブランド。
Python-native のエージェントフレームワークで、
**Memory・Knowledge・Tools・Reasoning** の 4 柱でエージェントを構成するのが特徴。

複数エージェントを組み合わせる **Agent Teams** と、
ノーコードで管理できる **Agno Platform (旧 phidata Cloud)** も提供。

## 4 つのコア機能

| 機能 | 説明 |
| :--- | :--- |
| **Memory** | ユーザーの会話・好みをストレージ (PostgreSQL / SQLite / Redis) に永続保存 |
| **Knowledge** | PDF・URL・テキストをベクター DB (pgvector / ChromaDB / Pinecone) に格納して RAG |
| **Tools** | Web 検索 / コード実行 / API 呼び出し / ファイル操作など 100+ 組み込みツール |
| **Reasoning** | Chain-of-Thought / 問題分解 / 自己検証ループによる複雑タスク対応 |

## 対応 LLM

OpenAI GPT / Anthropic Claude / Google Gemini / Meta Llama /
Mistral / Groq / Cohere / Ollama (ローカル) / AWS Bedrock / Azure OpenAI

## Agent Teams

- 複数エージェントを並行または順次で実行
- 各エージェントが専門ロール (Researcher / Writer / Reviewer) を担当
- リーダーエージェントがサブエージェントを委任・統括するパターンも対応

## Agno Platform

- Web UI でエージェントを管理・テスト・監視
- ワンクリックデプロイ (クラウドホスティング)
- ユーザー別 Memory の管理 UI
$md$,
  'https://www.agno.com/',
  '2026-04-24',
  1
),

(
  'agno',
  'models',
  'Agno エージェント設計パターン & 料金 (2026)',
  $md$
## エージェントの構成要素

```python
from agno.agent import Agent
from agno.models.anthropic import Claude
from agno.memory.v2.db.sqlite import SqliteMemoryDb
from agno.memory.v2.memory import Memory
from agno.knowledge.pdf import PDFKnowledgeBase
from agno.vectordb.pgvector import PgVector
from agno.tools.duckduckgo import DuckDuckGoTools

agent = Agent(
    model=Claude(id="claude-opus-4-7"),
    # Memory: 会話を永続保存
    memory=Memory(db=SqliteMemoryDb(db_file="agent_memory.db")),
    # Knowledge: RAG ベース知識
    knowledge=PDFKnowledgeBase(
        path="docs/",
        vector_db=PgVector(table_name="ai_university_docs"),
    ),
    # Tools: Web 検索など
    tools=[DuckDuckGoTools()],
    # Reasoning: 思考ステップを可視化
    reasoning=True,
    markdown=True,
)
```

## Agent Teams パターン

| パターン | 用途 |
| :--- | :--- |
| **Coordinate** | リーダーがサブエージェントにタスクを委任 |
| **Route** | 入力種別に応じてエージェントをルーティング |
| **Collaborate** | 全エージェントが並行作業して結果をマージ |

## 組み込みツール (一部)

| カテゴリ | ツール |
| :--- | :--- |
| 検索 | DuckDuckGo / Tavily / Exa / Perplexity |
| コード | Python / Shell / Jupyter |
| ファイル | CSV / PDF / JSON 読み書き |
| API | Slack / Gmail / GitHub / Stripe |

## 料金 (2026)

| プラン | 価格 | 概要 |
| :--- | :--- | :--- |
| **OSS** | 完全無料 | self-host / Apache 2.0 |
| **Agno Platform** | カスタム | ホスティング・監視・管理 UI |
$md$,
  'https://docs.agno.com/',
  '2026-04-24',
  2
),

(
  'agno',
  'api',
  'Agno API 入門 — Memory × Knowledge × Tools エージェント構築',
  $md$
## Agno の始め方

### インストール

```bash
pip install agno
```

### シンプルエージェント (Claude 使用)

```python
from agno.agent import Agent
from agno.models.anthropic import Claude

agent = Agent(
    model=Claude(id="claude-opus-4-7"),
    description="AI 大学のリサーチを担当するエキスパートエージェントです。",
    instructions=[
        "最新の AI プロバイダー情報を調査・要約する",
        "日本語で回答する",
        "数字・資金調達額は必ず出典付きで記載する",
    ],
    markdown=True,
)

agent.print_response("CrewAI と AutoGen の主な違いを教えて")
```

### Memory 付きエージェント (会話履歴を永続保存)

```python
from agno.agent import Agent
from agno.models.anthropic import Claude
from agno.memory.v2.db.sqlite import SqliteMemoryDb
from agno.memory.v2.memory import Memory
from agno.storage.sqlite import SqliteStorage

agent = Agent(
    model=Claude(id="claude-opus-4-7"),
    # ユーザー記憶: 長期保存
    memory=Memory(
        model=Claude(id="claude-haiku-4-5"),
        db=SqliteMemoryDb(db_file="memory.db"),
    ),
    # セッション保存
    storage=SqliteStorage(table_name="sessions", db_file="storage.db"),
    add_history_to_messages=True,
    num_history_runs=3,
    enable_user_memories=True,
)

# セッション 1
agent.print_response(
    "私は AI 大学の開発者で LLM 評価ツールに興味があります",
    user_id="kanta",
    session_id="session_1",
)

# セッション 2 (記憶を引き継ぐ)
agent.print_response(
    "私の興味に合うプロバイダーを推薦して",
    user_id="kanta",
    session_id="session_2",
)
# → 前回の「LLM 評価ツール」情報を記憶して推薦
```

### Agent Teams (マルチエージェント協調)

```python
from agno.agent import Agent
from agno.models.anthropic import Claude
from agno.team.team import Team
from agno.tools.duckduckgo import DuckDuckGoTools

researcher = Agent(
    name="AI リサーチャー",
    role="AI プロバイダーの最新情報を調査する",
    model=Claude(id="claude-opus-4-7"),
    tools=[DuckDuckGoTools()],
)

writer = Agent(
    name="コンテンツライター",
    role="調査結果を日本語の記事にまとめる",
    model=Claude(id="claude-opus-4-7"),
)

# チームを組成 (リーダーが調整)
team = Team(
    members=[researcher, writer],
    model=Claude(id="claude-opus-4-7"),
    mode="coordinate",  # または "route" / "collaborate"
    markdown=True,
)

team.print_response("Agno の主要機能と競合他社との差別化点を記事にして")
```

### Knowledge ベース (RAG)

```python
from agno.agent import Agent
from agno.models.anthropic import Claude
from agno.knowledge.url import URLKnowledgeBase
from agno.vectordb.pgvector import PgVector

# URL から知識ベースを構築
kb = URLKnowledgeBase(
    urls=["https://docs.agno.com/", "https://docs.crewai.com/"],
    vector_db=PgVector(table_name="agent_kb", db_url="postgresql://..."),
)
kb.load()  # ベクターインデックス作成

agent = Agent(
    model=Claude(id="claude-opus-4-7"),
    knowledge=kb,
    search_knowledge=True,  # 自動 RAG
)

agent.print_response("Agno と CrewAI の主な違いは？")
# → ドキュメントを参照して回答
```

## クイックスタート

1. `pip install agno` でインストール
2. `Agent(model=Claude(...), tools=[...])` で即座にエージェント作成
3. `memory=Memory(db=SqliteMemoryDb(...))` で会話永続化
4. `knowledge=URLKnowledgeBase(...)` で RAG ナレッジベース追加
5. 本番: `Team` で複数エージェント協調 / `Agno Platform` でクラウド管理
$md$,
  'https://docs.agno.com/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
