-- PS#3 S113: AI大学 320→321社化 — Semantic Kernel (Microsoft/C#+Python/AI Orchestration)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'semantic-kernel', 'overview',
  'Semantic Kernel — Microsoft AI Orchestration・C#+Python・Plugins・Planners (GitHub 22k+ / 9/9)',
  $$## Semantic Kernel とは

**Semantic Kernel (SK)** は **Microsoft が開発するエンタープライズ向け AI Orchestration フレームワーク**。GitHub 22,000+ スター。**C# / Python / Java** の 3 言語で提供される数少ない LLM フレームワーク。Azure OpenAI・Claude・Gemini を統一 API で扱え、**Microsoft 365・Azure との統合**が強み。

「**Kernel (カーネル)** に Plugin を追加し、Planner が自動でタスクを分解・実行する」思想。ChatGPT Plugins と互換のある OpenAPI ベースの Plugin 定義もサポート。**Microsoft Copilot Stack** の中核を担う。

## Semantic Kernel のアーキテクチャ

```
Semantic Kernel アーキテクチャ:

  Kernel (コア):
    ・AI サービス登録 (Claude / Azure OpenAI / OpenAI)
    ・Plugin 管理
    ・Memory 管理
    ・Dependency Injection 対応

  Plugin (機能単位):
    ・KernelFunction: Python 関数 / C# メソッド
    ・@kernel_function デコレータで登録
    ・OpenAPI Plugin (REST API を自動 Plugin 化)
    ・Native Plugin (独自実装)

  Planner (自動タスク分解):
    ・FunctionCallingStepwisePlanner: ステップ毎に LLM が判断
    ・SequentialPlanner: DAG 形式でタスクを計画
    ・HandlebarsPlanner: Handlebars テンプレートで計画

  Memory (ベクター記憶):
    ・TextMemory Plugin
    ・Azure AI Search / Chroma / Qdrant / pgvector
    ・Volatile Memory (インメモリ)
```

## 主要機能

```
AI サービス:
  ・Azure OpenAI (GPT-4o / Embeddings)
  ・OpenAI (GPT-4o)
  ・Anthropic Claude (claude-sonnet-4-6 / claude-haiku-4-5)
  ・Google Gemini
  ・Ollama (ローカル)
  ・HuggingFace

エンタープライズ統合:
  ・Microsoft 365 (Teams / Outlook / Word)
  ・Azure Active Directory 認証
  ・Azure Cosmos DB / Azure AI Search
  ・Copilot Studio 連携

Filters (フィルター):
  ・IFunctionInvocationFilter: 関数実行前後フック
  ・IPromptRenderFilter: プロンプトレンダリングフック
  ・ログ / テレメトリ / コスト監視
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬予想プラグイン** | 競馬 API を OpenAPI Plugin として登録 → Planner が自動利用 | 宣言的に予想ロジックを組む |
| **Azure 統合** | Azure AI Search で ai_university_content を検索 | エンタープライズグレード RAG |
| **C# バックエンド** | .NET アプリに Claude を組み込む | 型安全な AI 統合 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'semantic-kernel', 'api',
  'Semantic Kernel 実践 — インストール/Kernel設定/Plugin/Claude統合/Planner/Memory/Python実装',
  $$## インストール (Python)

```bash
pip install semantic-kernel
pip install semantic-kernel[anthropic]  # Claude 統合
pip install semantic-kernel[chromadb]   # Chroma ベクターストア
```

## Kernel 設定 + Claude

```python
import asyncio
from semantic_kernel import Kernel
from semantic_kernel.connectors.ai.anthropic import AnthropicChatCompletion
from semantic_kernel.connectors.ai.anthropic import AnthropicChatPromptExecutionSettings

# Kernel 初期化
kernel = Kernel()

# Claude を AI サービスとして登録
kernel.add_service(
    AnthropicChatCompletion(
        ai_model_id="claude-haiku-4-5",
        api_key="YOUR_ANTHROPIC_API_KEY",
    )
)

# シンプルなチャット
from semantic_kernel.contents import ChatHistory

chat_history = ChatHistory()
chat_history.add_system_message("あなたは日本競馬の専門AIアシスタントです。")
chat_history.add_user_message("天皇賞春の距離を教えてください")

async def main():
    chat_service = kernel.get_service(type=AnthropicChatCompletion)
    settings = AnthropicChatPromptExecutionSettings(max_tokens=200)
    result = await chat_service.get_chat_message_content(
        chat_history=chat_history,
        settings=settings,
    )
    print(result)

asyncio.run(main())
```

## Plugin (カーネル関数) 定義

```python
from semantic_kernel import Kernel
from semantic_kernel.functions import kernel_function
from semantic_kernel.connectors.ai.anthropic import AnthropicChatCompletion

kernel = Kernel()
kernel.add_service(AnthropicChatCompletion(ai_model_id="claude-haiku-4-5", api_key="YOUR_KEY"))

# Plugin クラス
class KeibaPlugin:
    """競馬データプラグイン"""

    @kernel_function(name="get_race_info", description="レース情報を取得する")
    def get_race_info(self, race_name: str) -> str:
        """指定レースの基本情報を返す"""
        # Supabase から取得するロジック
        return f"{race_name}: 距離=3200m, 開催=阪神, G1"

    @kernel_function(name="get_horse_record", description="馬の戦績を取得する")
    def get_horse_record(self, horse_name: str) -> str:
        """馬の直近5走を返す"""
        return f"{horse_name}: 1着, 1着, 2着, 1着, 3着 (直近5走)"

    @kernel_function(name="calculate_score", description="馬の総合スコアを計算する")
    def calculate_score(self, horse_name: str) -> str:
        """馬の予想スコアを算出"""
        return f"{horse_name}: 総合スコア 87/100"

# Plugin を Kernel に登録
kernel.add_plugin(KeibaPlugin(), plugin_name="KeibaPlugin")

# 関数を直接呼び出す
async def call_plugin():
    result = await kernel.invoke(
        kernel.plugins["KeibaPlugin"]["get_race_info"],
        race_name="天皇賞春",
    )
    print(result)

asyncio.run(call_plugin())
```

## Prompt Template Function

```python
from semantic_kernel.prompt_template import PromptTemplateConfig

# Semantic Function (プロンプトテンプレート)
prompt = """
あなたは競馬予想の専門家です。

レース情報:
{{$race_info}}

馬の戦績:
{{$horse_record}}

上記の情報を元に、このレースの予想を立ててください。
本命・対抗・穴馬の順で、根拠も含めて説明してください。
"""

prompt_config = PromptTemplateConfig(
    template=prompt,
    name="racing_prediction",
    template_format="semantic-kernel",
)

prediction_function = kernel.add_function(
    function_name="predict_race",
    plugin_name="RacingPlugin",
    prompt_template_config=prompt_config,
)

async def predict():
    result = await kernel.invoke(
        prediction_function,
        race_info="天皇賞春2026: 15頭出走, 3200m, 阪神競馬場",
        horse_record="シャフリヤール: 直近4走 1着・1着・2着・1着",
    )
    print(result)

asyncio.run(predict())
```

## Memory (ベクター記憶)

```python
from semantic_kernel.memory.semantic_text_memory import SemanticTextMemory
from semantic_kernel.connectors.memory.chroma import ChromaMemoryStore
from semantic_kernel.connectors.ai.open_ai import OpenAITextEmbedding

# Embedding + Memory Store
embedding_service = OpenAITextEmbedding(ai_model_id="text-embedding-3-small", api_key="YOUR_KEY")
memory_store = ChromaMemoryStore(persist_directory="./chroma_sk")

memory = SemanticTextMemory(storage=memory_store, embeddings_generator=embedding_service)

async def use_memory():
    # 競馬知識を記憶に保存
    await memory.save_information(
        collection="racing_knowledge",
        id="tennoushoshun",
        text="天皇賞春は3200mの長距離G1。スタミナが最重要。過去10年で4番人気以内が8勝。",
    )

    # 類似検索
    results = await memory.search(
        collection="racing_knowledge",
        query="天皇賞春の攻略法",
        limit=3,
    )
    for r in results:
        print(f"Score: {r.relevance:.2f} | {r.text[:100]}")

asyncio.run(use_memory())
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 320→321社化: Semantic Kernel 追加',
  'PS#3 S113。Semantic Kernel (Microsoft製/C#+Python+Java/Kernel+Plugin+Planner/AnthropicChatCompletion/FunctionCallingPlanner/SemanticTextMemory/Azure統合/Microsoft Copilot Stack/GitHub 22k+/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
