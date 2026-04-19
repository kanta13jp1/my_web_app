-- PS版#3 Session 7: LangChain — LLM アプリケーション構築の事実上の標準フレームワーク
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'langchain',
  'overview',
  'LangChain — LLM アプリ構築の事実上の標準フレームワーク',
  E'## LangChain とは\n\nLangChain は 2022 年末に Harrison Chase が個人プロジェクトとして公開した\n**LLM アプリケーション構築フレームワーク**。わずか数ヶ月で GitHub スター数 8 万超を達成し、\nAI アプリ開発のデファクトスタンダードとなった。\n\n現在は LangChain Inc. として累計 $35M+ を調達。\nPython / JavaScript 両対応、100+ のモデル・ツール統合を提供。\n\n## 主な特徴\n\n- **Chains**: 複数の LLM 呼び出し・ツールを連結するパイプライン\n- **Agents**: LLM がツールを自律的に選択・実行するエージェント\n- **RAG サポート**: Document Loader → Splitter → Embeddings → VectorStore → Retriever の標準フロー\n- **Memory**: 会話履歴管理（Buffer / Summary / Vector）\n- **LangSmith**: 本番 LLM アプリのデバッグ・評価・監視プラットフォーム\n\n## 活用事例\n\n- **RAG チャットボット**: PDF・Web サイトを読み込んで Q&A\n- **AI エージェント**: Web 検索・コード実行・DB 参照を自律的に組み合わせ\n- **マルチステップパイプライン**: 要約 → 翻訳 → 品質評価の連鎖処理\n- **社内ドキュメント検索**: Pinecone + LangChain で企業知識ベース構築',
  '2026-04-20'
),
(
  'langchain',
  'models',
  'LangChain エコシステム一覧',
  E'## LangChain コンポーネント\n\n### モデル統合 (Chat Models)\n```python\nfrom langchain_anthropic import ChatAnthropic\nfrom langchain_openai import ChatOpenAI\nfrom langchain_google_genai import ChatGoogleGenerativeAI\n\n# 同一インターフェースで複数モデルを切替\nllm = ChatAnthropic(model="claude-sonnet-4-6")\n```\n\n### RAG フロー\n| ステップ | コンポーネント | 例 |\n|----------|--------------|----|\n| **読み込み** | Document Loaders | PDF / Web / DB |\n| **分割** | Text Splitters | RecursiveCharacter |\n| **埋め込み** | Embeddings | OpenAI / Cohere |\n| **保存** | Vector Stores | Pinecone / Chroma / FAISS |\n| **検索** | Retrievers | Similarity / MMR |\n\n### エージェント\n- **ReAct**: Reasoning + Acting の繰り返しループ\n- **Tool Calling**: Claude / GPT-4 のネイティブツール呼び出し\n- **LangGraph**: 状態管理グラフで複雑なワークフローを構築\n\n## LangSmith\n\n- LLM 呼び出しトレース・可視化\n- プロンプトバージョン管理\n- A/B 評価・アノテーション\n- 本番エラーの原因追跡\n\n## 料金\n\n- **LangChain**: OSS・無料\n- **LangSmith**: 無料枠あり（月 1 万トレース）→ $39/月〜\n- **LangGraph Cloud**: マネージドエージェントホスティング',
  '2026-04-20'
),
(
  'langchain',
  'api',
  'LangChain 使い方',
  E'## インストール\n\n```bash\npip install langchain langchain-anthropic langchain-openai\npip install langchain-community chromadb  # RAG 用\n```\n\n## シンプルな RAG パイプライン\n\n```python\nfrom langchain_anthropic import ChatAnthropic\nfrom langchain_openai import OpenAIEmbeddings\nfrom langchain_community.document_loaders import WebBaseLoader\nfrom langchain.text_splitter import RecursiveCharacterTextSplitter\nfrom langchain_community.vectorstores import Chroma\nfrom langchain.chains import RetrievalQA\n\n# 1. ドキュメント読み込み\nloader = WebBaseLoader("https://my-web-app-b67f4.web.app/")\ndocs = loader.load()\n\n# 2. テキスト分割\nsplitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200)\nchunks = splitter.split_documents(docs)\n\n# 3. ベクターストア作成\nvectorstore = Chroma.from_documents(chunks, OpenAIEmbeddings())\n\n# 4. RAG チェーン構築\nllm = ChatAnthropic(model="claude-sonnet-4-6")\nqa_chain = RetrievalQA.from_chain_type(\n    llm=llm,\n    retriever=vectorstore.as_retriever(search_kwargs={"k": 3})\n)\n\n# 5. 質問応答\nanswer = qa_chain.invoke("このサービスの主な機能は？")\nprint(answer["result"])\n```\n\n## ツール利用エージェント\n\n```python\nfrom langchain.agents import AgentExecutor, create_tool_calling_agent\nfrom langchain_core.tools import tool\nfrom langchain_core.prompts import ChatPromptTemplate\n\n@tool\ndef search_ai_providers(query: str) -> str:\n    """AI大学のプロバイダー情報を検索します"""\n    return vectorstore.similarity_search(query, k=3)\n\n@tool  \ndef get_current_date() -> str:\n    """現在の日付を返します"""\n    from datetime import date\n    return str(date.today())\n\nllm = ChatAnthropic(model="claude-sonnet-4-6")\nprompt = ChatPromptTemplate.from_messages([\n    ("system", "あなたは AI 大学のアシスタントです。"),\n    ("human", "{input}"),\n    ("placeholder", "{agent_scratchpad}"),\n])\nagent = create_tool_calling_agent(llm, [search_ai_providers, get_current_date], prompt)\nexecutor = AgentExecutor(agent=agent, tools=[search_ai_providers, get_current_date])\nresult = executor.invoke({"input": "最新の音声 AI プロバイダーを教えて"})\n```\n\n## 活用シーン\n\n- **AI 大学 Q&A 強化**: プロバイダー情報を RAG で動的参照\n- **EF エージェント化**: Edge Function 内でツール呼び出し LLM を使う\n- **競合分析自動化**: Web → RAG → 比較レポート生成パイプライン',
  '2026-04-20'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
