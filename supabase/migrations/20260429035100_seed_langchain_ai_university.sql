-- PS#3 S110: AI大学 315→316社化 — LangChain (LLMオーケストレーション/AIエージェント/チェーン構築)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'langchain', 'overview',
  'LangChain — LLMオーケストレーション・AIエージェント・LCEL パイプライン (GitHub 94k+ / 9/9)',
  $$## LangChain とは

**LangChain** は **LLM を使ったアプリケーション構築のための最大のフレームワーク**。GitHub 94,000+ スター (AI フレームワーク最多)。**LLM の呼び出しをチェーンとして組み合わせ**、プロンプト管理・メモリ・ツール実行・エージェント・RAG を統一 API で扱える。

**LCEL (LangChain Expression Language)** という宣言的パイプライン構文が核心。`|` 演算子でコンポーネントを繋ぐだけで、並列実行・ストリーミング・非同期・再試行が自動で動く。**LangGraph** でマルチエージェントワークフローも構築できる。

## LangChain エコシステム

```
langchain-core:
  ・基本インターフェース (LLM / Chain / Tool / Memory 等)
  ・LCEL パイプライン構文

langchain:
  ・コア機能の実装 (Agent / Retriever / RAG Chain 等)

langchain-community:
  ・300+ インテグレーション (DB / VectorStore / Tool 等)

langchain-anthropic / langchain-openai / langchain-google:
  ・各 LLM プロバイダー公式パッケージ

LangGraph:
  ・マルチエージェント / ステートマシン
  ・循環グラフ対応 (LLM → Tool → LLM ループ)

LangSmith:
  ・デバッグ・トレース・評価・プロンプト管理 SaaS
  ・トークン消費・レイテンシ・コストの可視化
```

## LCEL (LangChain Expression Language) の設計思想

```python
# LCEL の核心: | 演算子でチェーンを組む
chain = prompt | llm | output_parser

# 自動で以下を提供:
# ・ストリーミング: chain.stream(input)
# ・非同期: await chain.ainvoke(input)
# ・並列実行: RunnableParallel で複数チェーンを並列実行
# ・バッチ処理: chain.batch([input1, input2, ...])
# ・フォールバック: chain.with_fallbacks([fallback_chain])
# ・再試行: chain.with_retry(stop_after_attempt=3)
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬AIエージェント** | Tool (競馬API / DB検索) + Claude で自律的に予想を生成 | 多段推論による高精度予想 |
| **RAG パイプライン** | ai_university_content を Retriever として ChatBot 化 | AI大学コンテンツへの Q&A |
| **マルチエージェント** | LangGraph で「調査→分析→予想→検証」の自律ワークフロー | ヒト介在なしで予想サイクル |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'langchain', 'api',
  'LangChain 実践 — LCEL/Claude統合/RAG Chain/AIエージェント/LangGraph/LangSmith/Supabase統合',
  $$## インストール

```bash
pip install langchain langchain-anthropic langchain-community
pip install langchain-chroma   # Chroma ベクターストア
pip install langgraph          # マルチエージェント
pip install langsmith           # トレーシング (オプション)
```

## LCEL 基本チェーン (Claude)

```python
from langchain_anthropic import ChatAnthropic
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser

# Claude モデル
llm = ChatAnthropic(
    model="claude-haiku-4-5",
    api_key="YOUR_ANTHROPIC_API_KEY",
    max_tokens=500,
)

# プロンプトテンプレート
prompt = ChatPromptTemplate.from_messages([
    ("system", "あなたは日本競馬の専門アドバイザーです。"),
    ("human", "{question}"),
])

# LCEL でチェーンを組む
chain = prompt | llm | StrOutputParser()

# 実行
response = chain.invoke({"question": "天皇賞春の歴史を教えてください"})
print(response)

# ストリーミング
for chunk in chain.stream({"question": "今週の重賞レースの見どころは？"}):
    print(chunk, end="", flush=True)
print()
```

## RAG Chain (Retrieval-Augmented Generation)

```python
from langchain_anthropic import ChatAnthropic
from langchain_community.vectorstores import Chroma
from langchain_community.embeddings import HuggingFaceEmbeddings
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import RunnablePassthrough
from langchain_core.output_parsers import StrOutputParser
from langchain_community.document_loaders import PyPDFLoader
from langchain.text_splitter import RecursiveCharacterTextSplitter

# ドキュメントの読み込みと分割
loader = PyPDFLoader("./data/keiba_rules.pdf")
docs = loader.load()

text_splitter = RecursiveCharacterTextSplitter(
    chunk_size=1000,
    chunk_overlap=200,
)
splits = text_splitter.split_documents(docs)

# ベクターストア作成 (HuggingFace 埋め込み = 無料)
embeddings = HuggingFaceEmbeddings(model_name="BAAI/bge-small-en-v1.5")
vectorstore = Chroma.from_documents(splits, embeddings)
retriever = vectorstore.as_retriever(search_kwargs={"k": 3})

# RAG プロンプト
template = """以下のコンテキストを参考に質問に答えてください。

コンテキスト:
{context}

質問: {question}
"""
prompt = ChatPromptTemplate.from_template(template)

# RAG Chain
llm = ChatAnthropic(model="claude-haiku-4-5")

def format_docs(docs):
    return "\n\n".join(doc.page_content for doc in docs)

rag_chain = (
    {"context": retriever | format_docs, "question": RunnablePassthrough()}
    | prompt
    | llm
    | StrOutputParser()
)

response = rag_chain.invoke("レースで落馬した場合のルールは？")
print(response)
```

## AI エージェント (Tool 使用)

```python
from langchain_anthropic import ChatAnthropic
from langchain_core.tools import tool
from langchain.agents import create_tool_calling_agent, AgentExecutor
from langchain_core.prompts import ChatPromptTemplate

# カスタムツール定義
@tool
def get_race_results(race_name: str, year: int) -> str:
    """指定したレースの結果を取得する"""
    # 実際は Supabase から取得
    return f"{year}年 {race_name}: 1着=シャフリヤール, 騎手=デムーロ, タイム=1:57.8"

@tool
def get_horse_info(horse_name: str) -> str:
    """馬の基本情報と最近の戦績を取得する"""
    return f"{horse_name}: 父=ディープインパクト, 馬齢=5歳, 戦績=12戦7勝"

@tool
def calculate_odds(horse_name: str, race_id: str) -> str:
    """オッズを計算する"""
    return f"{horse_name}の単勝オッズ: 3.2倍 (人気2番)"

# エージェント作成
llm = ChatAnthropic(model="claude-sonnet-4-6")
tools = [get_race_results, get_horse_info, calculate_odds]

prompt = ChatPromptTemplate.from_messages([
    ("system", "あなたは競馬予想の専門AIエージェントです。ツールを使って予想を立ててください。"),
    ("human", "{input}"),
    ("placeholder", "{agent_scratchpad}"),
])

agent = create_tool_calling_agent(llm, tools, prompt)
agent_executor = AgentExecutor(agent=agent, tools=tools, verbose=True)

# エージェントを実行
result = agent_executor.invoke({
    "input": "今週の天皇賞春でシャフリヤールの予想を立ててください"
})
print(result["output"])
```

## LangGraph マルチエージェント

```python
from langgraph.graph import StateGraph, END
from langchain_anthropic import ChatAnthropic
from typing import TypedDict, Annotated
import operator

# 状態定義
class RacingState(TypedDict):
    messages: Annotated[list, operator.add]
    race_info: str
    horse_data: str
    prediction: str

llm = ChatAnthropic(model="claude-haiku-4-5")

# ノード (各エージェントの役割)
def research_agent(state: RacingState):
    """レース情報収集エージェント"""
    response = llm.invoke(
        f"天皇賞春2026のレース情報を収集してください"
    )
    return {"race_info": response.content}

def analysis_agent(state: RacingState):
    """データ分析エージェント"""
    response = llm.invoke(
        f"以下のレース情報を分析: {state['race_info']}"
    )
    return {"horse_data": response.content}

def prediction_agent(state: RacingState):
    """予想生成エージェント"""
    response = llm.invoke(
        f"分析結果に基づいて予想: {state['horse_data']}"
    )
    return {"prediction": response.content}

# グラフ構築
workflow = StateGraph(RacingState)
workflow.add_node("research", research_agent)
workflow.add_node("analysis", analysis_agent)
workflow.add_node("prediction", prediction_agent)

workflow.set_entry_point("research")
workflow.add_edge("research", "analysis")
workflow.add_edge("analysis", "prediction")
workflow.add_edge("prediction", END)

app = workflow.compile()

# 実行
result = app.invoke({"messages": [], "race_info": "", "horse_data": "", "prediction": ""})
print(result["prediction"])
```

## LangSmith トレーシング

```python
import os

# LangSmith でトレース開始 (デバッグ・コスト可視化)
os.environ["LANGCHAIN_TRACING_V2"] = "true"
os.environ["LANGCHAIN_API_KEY"] = "YOUR_LANGSMITH_API_KEY"
os.environ["LANGCHAIN_PROJECT"] = "horse-racing-ai"

# 以降の全チェーン実行が自動でトレースされる
chain = prompt | llm | StrOutputParser()
response = chain.invoke({"question": "G1レースの的中のコツは？"})
# → https://smith.langchain.com でトークン数・レイテンシ・コストを確認
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 315→316社化: LangChain 追加',
  'PS#3 S110。LangChain (LLMオーケストレーション/LCEL宣言的パイプライン/RAG Chain/Tool使用エージェント/LangGraph マルチエージェント/LangSmith トレーシング/300+ インテグレーション/GitHub 94k+/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
