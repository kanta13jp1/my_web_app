-- Session PS#3-S49: AI大学 195→196社化 — Semantic Kernel 追加
-- Microsoft 製 AI エージェント SDK。.NET / Python / Java 対応。
-- Planner (自動タスク分解) / Memory / Plugin を統合した軽量 OSS フレームワーク。
-- GitHub Copilot・Azure OpenAI と深く統合。MIT ライセンス / 21k+ Stars。
-- Step 0: 8/9 (MS公式 / .NET+Python+Java / Planner自動分解 / Azure統合 / MIT 21k+Stars)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'semantic_kernel',
  'overview',
  'Semantic Kernel — Microsoft 製 AI エージェント SDK (.NET / Python / Java 対応)',
  $md$
# Semantic Kernel — Microsoft の AI エージェント SDK

**Microsoft が開発するオープンソース AI エージェント SDK**。
.NET・Python・Java の 3 言語に対応し、**LLM + プラグイン + メモリ + プランナー**を
組み合わせた AI アプリケーションを構築できる。

GitHub **21,000+ Stars** / MIT ライセンス。
**GitHub Copilot・Azure OpenAI・Bing** と深く統合。

## LangChain / LlamaIndex との比較

| 機能 | Semantic Kernel | LangChain | LlamaIndex |
| :--- | :--- | :--- | :--- |
| **言語** | .NET / Python / Java | Python / JS | Python / JS |
| **Planner (自動タスク分解)** | ✅ ネイティブ | Agent | — |
| **Plugin エコシステム** | ✅ OpenAI Plugin 互換 | Tool | — |
| **Memory** | ✅ 複数バックエンド | ✅ | ✅ |
| **Azure 統合** | ✅ 最適化済 | 部分対応 | 部分対応 |
| **エンタープライズサポート** | ✅ MS公式 | コミュニティ | コミュニティ |
| **学習コスト** | 中 | 高 | 中 |

## コアコンセプト

### Kernel (中核)
- AI サービス・プラグイン・メモリを統合するオーケストレーター
- 依存性注入コンテナとして機能

### Plugin (ツール)
- LLM から呼び出せる関数の集合
- OpenAI Function Calling 互換

### Planner (自動タスク分解)
- ゴールを入力すると、利用可能プラグインからプランを自動生成
- Handlebars Planner / Stepwise Planner の 2 種類

### Memory (記憶)
- 会話履歴・ユーザー情報・ドキュメントをベクター検索
- Azure AI Search / Chroma / Pinecone / Supabase pgvector に対応

### Process Framework (ワークフロー)
- ステートマシンとしてのエージェントワークフロー
- イベント駆動の Step 実行
$md$,
  'https://learn.microsoft.com/ja-jp/semantic-kernel/',
  '2026-04-25',
  1
),

(
  'semantic_kernel',
  'api',
  'Semantic Kernel セットアップ — Python / C# インストール・Chat Completion・Plugin・Planner 実装',
  $md$
## インストール

```bash
# Python
pip install semantic-kernel

# C# / .NET
dotnet add package Microsoft.SemanticKernel

# Java
# Maven: com.microsoft.semantic-kernel:semantickernel-api
```

---

## 基本セットアップ (Python)

```python
import asyncio
from semantic_kernel import Kernel
from semantic_kernel.connectors.ai.open_ai import AzureChatCompletion, OpenAIChatCompletion
from semantic_kernel.connectors.ai.function_choice_behavior import FunctionChoiceBehavior

# Kernel 初期化
kernel = Kernel()

# Azure OpenAI を追加 (推奨)
kernel.add_service(AzureChatCompletion(
    deployment_name="gpt-4o",
    endpoint=os.environ["AZURE_OPENAI_ENDPOINT"],
    api_key=os.environ["AZURE_OPENAI_API_KEY"],
))

# または OpenAI を直接使用
kernel.add_service(OpenAIChatCompletion(
    ai_model_id="gpt-4o",
    api_key=os.environ["OPENAI_API_KEY"],
))
```

---

## Chat Completion

```python
from semantic_kernel.contents import ChatHistory

async def main():
    kernel = Kernel()
    kernel.add_service(AzureChatCompletion(deployment_name="gpt-4o", ...))

    chat_history = ChatHistory()
    chat_history.add_system_message("あなたは自分株式会社のAIアシスタントです。")
    chat_history.add_user_message("Semantic Kernel の主な特徴は何ですか？")

    response = await kernel.invoke_prompt(
        prompt="{{$chat_history}}",
        arguments=KernelArguments(chat_history=chat_history)
    )
    print(response)

asyncio.run(main())
```

---

## Plugin (ツール) の作成

```python
from semantic_kernel.functions import kernel_function
from typing import Annotated

class ProjectPlugin:
    """自分株式会社プロジェクト管理プラグイン"""

    @kernel_function(description="AI大学のプロバイダー数を取得する")
    async def get_provider_count(self) -> Annotated[str, "プロバイダー数"]:
        # Supabase から取得
        return "196社"

    @kernel_function(description="指定したプロバイダーの情報を取得する")
    async def get_provider_info(
        self,
        provider_id: Annotated[str, "プロバイダーID (例: openai, anthropic)"]
    ) -> Annotated[str, "プロバイダー情報"]:
        return f"{provider_id} の詳細情報..."

# Kernel にプラグインを登録
kernel.add_plugin(ProjectPlugin(), plugin_name="Project")
```

---

## Planner (自動タスク分解)

```python
from semantic_kernel.planners.handlebars_planner import HandlebarsPlanner, HandlebarsPlannerOptions

async def use_planner():
    kernel = Kernel()
    # ... サービスとプラグインを追加 ...

    planner = HandlebarsPlanner(kernel, HandlebarsPlannerOptions(
        allow_loops=True,
        max_iterations=10
    ))

    # ゴールを指定するだけで自動プラン生成
    plan = await planner.create_plan("AI大学の最新プロバイダーを調べて、Supabaseに登録してください")

    # プランを実行
    result = await plan.invoke(kernel)
    print(result)
```

---

## Memory (Vector Search)

```python
from semantic_kernel.memory import SemanticTextMemory
from semantic_kernel.connectors.memory.supabase import SupabaseMemoryStore

# Supabase pgvector をメモリバックエンドとして使用
memory = SemanticTextMemory(
    storage=SupabaseMemoryStore(
        connection_string=os.environ["SUPABASE_CONNECTION_STRING"]
    ),
    embeddings_generator=kernel.get_service(AzureTextEmbedding)
)

# ドキュメントを保存
await memory.save_information(
    collection="ai_university",
    id="openai_overview",
    text="OpenAI は GPT-4o, o1 など最先端 LLM を提供する企業。",
)

# セマンティック検索
results = await memory.search("最強の LLM プロバイダーは？", collection="ai_university", limit=5)
for result in results:
    print(f"Relevance: {result.relevance:.2f} | {result.text[:100]}")
```

---

## C# での実装例

```csharp
using Microsoft.SemanticKernel;
using Microsoft.SemanticKernel.Connectors.AzureOpenAI;

var builder = Kernel.CreateBuilder();
builder.AddAzureOpenAIChatCompletion(
    deploymentName: "gpt-4o",
    endpoint: Environment.GetEnvironmentVariable("AZURE_OPENAI_ENDPOINT")!,
    apiKey: Environment.GetEnvironmentVariable("AZURE_OPENAI_API_KEY")!
);

var kernel = builder.Build();

// プラグイン自動選択でチャット
var settings = new AzureOpenAIPromptExecutionSettings {
    FunctionChoiceBehavior = FunctionChoiceBehavior.Auto()
};

var response = await kernel.InvokePromptAsync(
    "今日の天気を教えて",
    new KernelArguments(settings)
);
Console.WriteLine(response);
```
$md$,
  'https://learn.microsoft.com/ja-jp/semantic-kernel/get-started/quick-start-guide',
  '2026-04-25',
  2
),

(
  'semantic_kernel',
  'models',
  'Semantic Kernel 本番活用 — AI エージェント設計パターン・Process Framework・このプロジェクトへの統合',
  $md$
## AI エージェント設計パターン

### パターン 1: シングルエージェント + Plugin

```python
# 最もシンプル: 1 つの LLM が複数プラグインを選択・実行
kernel = Kernel()
kernel.add_service(AzureChatCompletion(...))
kernel.add_plugin(SearchPlugin(), "Search")      # Bing Search
kernel.add_plugin(CalendarPlugin(), "Calendar")  # カレンダー操作
kernel.add_plugin(EmailPlugin(), "Email")        # メール送信

# ユーザーの入力に応じて自動的にプラグインを選択
response = await kernel.invoke_prompt(
    "明日の予定を確認して、参加者全員にリマインダーメールを送って",
    arguments=KernelArguments(
        settings=OpenAIPromptExecutionSettings(
            function_choice_behavior=FunctionChoiceBehavior.Auto()
        )
    )
)
```

### パターン 2: Multi-Agent (Agent Framework)

```python
from semantic_kernel.agents import ChatCompletionAgent, AgentGroupChat

# 複数エージェントが協調して問題を解く
research_agent = ChatCompletionAgent(
    kernel=kernel,
    name="Researcher",
    instructions="あなたはリサーチ専門エージェント。Web を検索して情報を収集してください。",
    plugins=[SearchPlugin()]
)

writer_agent = ChatCompletionAgent(
    kernel=kernel,
    name="Writer",
    instructions="あなたは日本語ライター。リサーチ結果をわかりやすくまとめてください。",
)

# グループチャットで協調
group_chat = AgentGroupChat(
    agents=[research_agent, writer_agent],
    termination_strategy=...,  # 終了条件
)

async for message in group_chat.invoke("Azure OpenAI の最新機能をまとめたレポートを作成して"):
    print(f"[{message.name}]: {message.content}")
```

### パターン 3: Process Framework (ステートマシン)

```python
from semantic_kernel.processes import ProcessBuilder, KernelProcess

# ステートマシンとして複雑なワークフローを定義
process = ProcessBuilder(name="AIUniversityUpdate")

# Step 定義
fetch_step = process.add_step(FetchProviderStep)
validate_step = process.add_step(ValidateProviderStep)
save_step = process.add_step(SaveToSupabaseStep)
notify_step = process.add_step(NotifySlackStep)

# フロー定義
process.on_input_event("start").send_event_to(fetch_step)
fetch_step.on_function_result("fetch").send_event_to(validate_step)
validate_step.on_function_result("valid").send_event_to(save_step)
save_step.on_function_result("saved").send_event_to(notify_step)
```

---

## このプロジェクト (自分株式会社) への統合

### AI 大学コンテンツ自動更新エージェント

```python
# tools-hub EF でエージェントを呼び出す設計
from semantic_kernel.agents import ChatCompletionAgent

class AIUniversityUpdateAgent:
    def __init__(self):
        self.kernel = Kernel()
        self.kernel.add_service(AzureChatCompletion(
            deployment_name="gpt-4o",
            endpoint=os.environ["AZURE_OPENAI_ENDPOINT"],
            api_key=os.environ["AZURE_OPENAI_API_KEY"],
        ))
        self.kernel.add_plugin(SupabasePlugin(), "Supabase")

    async def suggest_new_providers(self) -> list[dict]:
        agent = ChatCompletionAgent(
            kernel=self.kernel,
            name="AIUniversityResearcher",
            instructions="""
            あなたは AI プロバイダーのリサーチ専門家です。
            現在 AI 大学に登録されていない新しい AI 企業・ツールを提案してください。
            評価基準: GitHub Stars / 資金調達 / 実用性 / 日本市場での需要
            """,
        )
        result = await agent.invoke("2026年注目の新 AI ツールを5つ提案してください")
        return parse_suggestions(result)
```

### WBS タスク自動レビュー (既存機能の強化)

```python
# 既存の tools-hub:wbs.priority_for_instance を SK で強化
class WBSReviewAgent:
    @kernel_function(description="WBS タスクをレビューして優先度を提案する")
    async def review_task(self, task_description: str) -> str:
        # AI がタスクを分析して CLAUDE.md のルールに照らしてレビュー
        return f"レビュー結果: {task_description} — 優先度 High / 推定 2h"
```

---

## Azure OpenAI との組み合わせ (推奨構成)

```python
# 本番推奨: Semantic Kernel + Azure OpenAI + pgvector
kernel = Kernel()

# LLM: Azure OpenAI (エンタープライズ安全性)
kernel.add_service(AzureChatCompletion(deployment_name="gpt-4o", ...))

# Embedding: Azure text-embedding-3-small
kernel.add_service(AzureTextEmbedding(deployment_name="text-embedding-3-small", ...))

# Memory: Supabase pgvector
memory = SemanticTextMemory(
    storage=SupabaseMemoryStore(connection_string=...),
    embeddings_generator=kernel.get_service(AzureTextEmbedding)
)

# この構成で HIPAA/SOC2 準拠の AI エージェントが構築可能
```

## クイックスタート (3 ステップ)

1. `pip install semantic-kernel` でインストール
2. Azure OpenAI または OpenAI の API Key を環境変数に設定
3. `Kernel()` を作成してサービスとプラグインを追加 → `kernel.invoke_prompt()` で実行
$md$,
  'https://learn.microsoft.com/ja-jp/semantic-kernel/frameworks/agent/',
  '2026-04-25',
  3
)

ON CONFLICT DO NOTHING;
