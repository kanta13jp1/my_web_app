-- Session PS#3-S32: AI大学 159社化 — Tavily 追加
-- Assaf Elovic (元 LangChain) が 2024 年に創業した AI エージェント・RAG 専用リアルタイム検索 API。
-- 2026-02 Nebius (元 Yandex Cloud AI 部門・NASDAQ 上場) に買収。
-- Free 1,000 クレジット/月 → Researcher $30/月 (10K) → Startup $100/月 → PAYG $0.008/クレジット。
-- LangChain・LlamaIndex・CrewAI・AutoGen の公式パートナー統合で AI エージェントのデファクト検索 API。
-- 既存 158 社 (Exa が近い空白) とは異なる「RAG/エージェント最適化リアルタイム Web 検索」軸を強化。
-- Step 0: 8.5/9 (LangChain 公式統合・無料 API・RAG 業界標準 / Nebius 買収で不確実性あり -0.5)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'tavily',
  'overview',
  'Tavily — AI エージェント・RAG 向けリアルタイム Web 検索 API',
  $md$
# Tavily — The Search API for AI Agents

2024 年創業。**Assaf Elovic** (元 LangChain) が「LLM のハルシネーションを削減し、
AI エージェントがリアルタイムの Web 情報にアクセスできる」検索 API を開発。

一般的な検索 API が返す生の HTML や長大なスニペットと異なり、Tavily は
**LLM のコンテキストウィンドウに最適化された簡潔で構造化されたスニペット** を返す。

2026 年 2 月に **Nebius** (元 Yandex Cloud の AI 部門として NASDAQ 上場) に買収され、
より大規模なインフラとエンタープライズ顧客基盤を獲得。

**LangChain・LlamaIndex・CrewAI・AutoGen・Mastra** の公式パートナー統合として採用され、
AI エージェント開発における **デファクトスタンダード検索 API** の地位を確立。

## 主要 API
- **Search API** — クエリに最適化されたスニペットを返すリアルタイム Web 検索
- **Extract API** — URL 指定で特定ページのコンテンツを LLM 向けに抽出
- **Map API** — サイトの URL 構造をマッピング
- **Crawl API** — 深層クロールと継続的データ収集

## 強み
- **RAG 最適化** — LLM が直接使えるクリーンなスニペット形式で返答
- **リアルタイム** — 最新の Web 情報をハルシネーションなしで取得
- LangChain / LlamaIndex との **1 行統合** — エコシステム最大統合数を誇る
- 無料 1,000 クレジット/月でプロトタイプ開始可能
$md$,
  'https://tavily.com/',
  '2026-04-24',
  1
),

(
  'tavily',
  'models',
  'Tavily API エンドポイント・プラン一覧 (2026)',
  $md$
## Tavily API エンドポイント

| エンドポイント | 説明 | クレジット消費 |
| :--- | :--- | :--- |
| **Search (basic)** | 基本 Web 検索・LLM 最適化スニペット | 1 クレジット/リクエスト |
| **Search (advanced)** | より深い検索・より多くのソース | 2 クレジット/リクエスト |
| **Extract** | URL → LLM 向けコンテンツ抽出 | 1 クレジット/5 URL |
| **Map** | サイト URL 構造のマッピング | 1 クレジット/リクエスト |
| **Crawl** | 深層クロール (複数ページ) | 1 クレジット/ページ |

## プラン比較

| プラン | 月額 | クレジット |
| :--- | :--- | :--- |
| **Researcher** (無料) | $0 | 1,000 クレジット/月 |
| **Researcher** (有料) | $30 | 10,000 クレジット/月 |
| **Startup** | $100 | 50,000 クレジット/月 |
| **Pay As You Go** | 従量 | $0.008/クレジット |
| **Enterprise** | 要相談 | カスタム |

> クレジットは翌月に繰り越しなし

## フレームワーク統合

| フレームワーク | 統合方法 |
| :--- | :--- |
| **LangChain** | `TavilySearchResults` ツール (公式) |
| **LlamaIndex** | `TavilyToolSpec` (公式) |
| **CrewAI** | `TavilySearchTool` |
| **AutoGen** | カスタムツールとして統合 |
| **OpenAI Function Calling** | JSON スキーマで直接統合 |
$md$,
  'https://docs.tavily.com/',
  '2026-04-24',
  2
),

(
  'tavily',
  'api',
  'Tavily API 入門',
  $md$
## Tavily API の始め方

```python
# pip install tavily-python

from tavily import TavilyClient

client = TavilyClient(api_key="your-tavily-api-key")

# 基本検索 (RAG 向け最適化スニペット)
response = client.search(
    query="Claude Sonnet 4.6 の最新情報",
    search_depth="basic",       # "basic" or "advanced"
    max_results=5,
    include_answer=True,        # LLM による要約回答も含める
    include_images=False
)

# 回答の取得
print(response["answer"])       # LLM 生成の要約回答
for result in response["results"]:
    print(f"{result['title']}: {result['url']}")
    print(f"スニペット: {result['content'][:200]}")

# URL からコンテンツ抽出
extract = client.extract(urls=["https://anthropic.com/claude"])
```

## LangChain との統合

```python
from langchain_community.tools.tavily_search import TavilySearchResults
from langchain_openai import ChatOpenAI
from langchain.agents import create_openai_functions_agent, AgentExecutor
from langchain import hub

# Tavily ツールを LangChain エージェントに統合
tools = [TavilySearchResults(max_results=3)]
llm = ChatOpenAI(model="gpt-4o")
prompt = hub.pull("hwchase17/openai-functions-agent")

agent = create_openai_functions_agent(llm, tools, prompt)
agent_executor = AgentExecutor(agent=agent, tools=tools, verbose=True)

result = agent_executor.invoke({
    "input": "2026年の最新 AI ニュースを教えて"
})
```

## 料金 (2026年4月時点)

| プラン | 月額 | 用途 |
| :--- | :--- | :--- |
| **Researcher (無料)** | $0 | 個人・プロトタイプ |
| **Researcher** | $30 | 小規模エージェント |
| **Startup** | $100 | プロダクション |
| **PAYG** | $0.008/クレジット | スケール |

## クイックスタート

1. [tavily.com](https://tavily.com) でアカウント作成 → 無料 API キー取得
2. `pip install tavily-python` または `npm install tavily`
3. `TAVILY_API_KEY` を環境変数に設定
4. `client.search(query=...)` でリアルタイム検索開始
$md$,
  'https://docs.tavily.com/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
