-- PS#3 S111: AI大学 317→318社化 — CrewAI (マルチエージェントフレームワーク/Role-based/タスク分解)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'crewai', 'overview',
  'CrewAI — マルチエージェントフレームワーク・Role-based Agents・タスク分解 (GitHub 26k+ / 9/9)',
  $$## CrewAI とは

**CrewAI** は **Role-based なマルチエージェントフレームワーク**。GitHub 26,000+ スター。「**AI エージェントの チーム (Crew) を編成してタスクを協調実行する**」思想が核心。各エージェントに「役割 (Role)・目標 (Goal)・背景情報 (Backstory)」を与え、チームとして複雑なタスクを分解・解決する。

LangGraph よりも**人間に近い役割分担モデル**で、ビジネスユースケース (リサーチ・コンテンツ生成・分析・コーディング) への適用が容易。Claude を含む主要 LLM と統合できる。**CrewAI Flows** (2024年追加) でイベント駆動・条件分岐ワークフローも構築可能。

## CrewAI のアーキテクチャ

```
CrewAI コアコンセプト:

  Agent (エージェント):
    ・role: 専門役割 (例: "競馬データアナリスト")
    ・goal: このエージェントの目標
    ・backstory: 背景・専門知識・人格
    ・tools: 使えるツール一覧
    ・llm: 使用LLMモデル
    ・verbose: 思考プロセスの可視化

  Task (タスク):
    ・description: タスクの詳細説明
    ・expected_output: 期待する出力フォーマット
    ・agent: 担当エージェント
    ・context: 依存する他タスクの出力を参照

  Crew (チーム):
    ・agents: エージェント一覧
    ・tasks: タスク一覧
    ・process: 実行順序 (sequential / hierarchical)
    ・verbose: 実行ログ表示

  Process:
    ・sequential: タスクを順番に実行
    ・hierarchical: マネージャーがタスクを割り当て
```

## 主要機能

```
Tools (ツール統合):
  ・SerperDevTool (Google検索)
  ・WebsiteSearchTool (RAG)
  ・FileReadTool / FileWriteTool
  ・CodeInterpreterTool
  ・カスタムツール (@tool デコレータ)

LLM サポート:
  ・Claude (Anthropic) ← 推奨
  ・OpenAI GPT-4o
  ・Google Gemini
  ・Ollama (ローカル)
  ・Azure OpenAI

Memory (記憶):
  ・Short-term memory (タスク間)
  ・Long-term memory (セッション間 / RAG)
  ・Entity memory (エンティティ抽出)

CrewAI Flows:
  ・@start @listen でイベント駆動
  ・条件分岐・並列実行
  ・State 管理 (Pydantic)
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬予想チーム** | リサーチャー→アナリスト→予想師→検証者の4役構成 | 多角的な視点で高精度予想 |
| **コンテンツ生成** | リサーチャー+ライター+編集者でdev.to記事自動生成 | T-1タスクの自動化 |
| **AI大学拡充** | リサーチャーがAIプロバイダー調査→ライターがSQL生成 | provider追加の半自動化 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'crewai', 'api',
  'CrewAI 実践 — インストール/Agent定義/Task定義/Crew実行/Claude統合/カスタムツール/Flows',
  $$## インストール

```bash
pip install crewai
pip install crewai-tools  # 組み込みツール群
```

## 基本構成 (競馬予想チーム)

```python
from crewai import Agent, Task, Crew, Process
from crewai_tools import SerperDevTool
from langchain_anthropic import ChatAnthropic

# Claude LLM 設定
llm = ChatAnthropic(
    model="claude-haiku-4-5",
    anthropic_api_key="YOUR_ANTHROPIC_API_KEY",
)

search_tool = SerperDevTool()

# エージェント定義
researcher = Agent(
    role="競馬データリサーチャー",
    goal="今週のG1レースの最新情報・出走馬・騎手・調教師情報を収集する",
    backstory="""あなたは10年以上の競馬分析経験を持つリサーチャー。
    データの正確性を最重視し、信頼できる情報源からのみ収集する。""",
    tools=[search_tool],
    llm=llm,
    verbose=True,
)

analyst = Agent(
    role="競馬データアナリスト",
    goal="収集されたデータを分析し、各馬の勝率と注目ポイントを評価する",
    backstory="""統計分析の専門家。血統・コース適性・騎手相性・
    最近の調子など複合的な要素を数値化して評価する。""",
    llm=llm,
    verbose=True,
)

predictor = Agent(
    role="競馬予想師",
    goal="分析結果に基づいて具体的な予想を生成し、根拠を明示する",
    backstory="""元JRA厩舎スタッフ出身のベテラン予想師。
    現場感覚と数値分析を組み合わせた予想で高い的中率を誇る。""",
    llm=ChatAnthropic(model="claude-sonnet-4-6", anthropic_api_key="YOUR_ANTHROPIC_API_KEY"),
    verbose=True,
)

# タスク定義
research_task = Task(
    description="""今週の天皇賞春 (2026年) について以下を調査:
    - 出走馬一覧と基本情報 (馬齢・調教師・騎手)
    - 各馬の直近3走の成績
    - 天皇賞春での過去実績 (コース適性)
    - 調教の評価 (可能な場合)""",
    expected_output="出走馬ごとの詳細情報をMarkdown形式でまとめたレポート",
    agent=researcher,
)

analysis_task = Task(
    description="""リサーチャーの収集データを元に:
    - 各馬のスコアリング (コース適性・騎手相性・近走評価・血統)
    - 注目馬 Top 5 の選定と根拠
    - リスク要因の特定""",
    expected_output="各馬スコアリング表 + 注目馬Top5のMarkdownレポート",
    agent=analyst,
    context=[research_task],  # research_task の出力を参照
)

prediction_task = Task(
    description="""アナリストの評価を元に最終予想を作成:
    - 本命・対抗・単穴の選定
    - 推奨買い目 (単勝・馬連・三連複)
    - 自信度スコア (1-10)""",
    expected_output="競馬予想レポート (本命・対抗・穴馬・買い目・自信度)",
    agent=predictor,
    context=[analysis_task],
)

# Crew 実行
crew = Crew(
    agents=[researcher, analyst, predictor],
    tasks=[research_task, analysis_task, prediction_task],
    process=Process.sequential,
    verbose=True,
)

result = crew.kickoff()
print(result.raw)
```

## カスタムツール

```python
from crewai_tools import BaseTool
from pydantic import BaseModel, Field

class SupabaseRaceInput(BaseModel):
    race_id: str = Field(description="レースID")

class SupabaseRaceTool(BaseTool):
    name: str = "SupabaseRaceLookup"
    description: str = "Supabase から特定レースの詳細データを取得する"
    args_schema: type[BaseModel] = SupabaseRaceInput

    def _run(self, race_id: str) -> str:
        # Supabase から取得
        import requests
        response = requests.get(
            f"https://your-project.supabase.co/rest/v1/races?id=eq.{race_id}",
            headers={"apikey": "YOUR_SUPABASE_KEY"},
        )
        return response.json()

# エージェントに追加
researcher = Agent(
    role="競馬データリサーチャー",
    tools=[SupabaseRaceTool()],
    llm=llm,
)
```

## CrewAI Flows (イベント駆動ワークフロー)

```python
from crewai.flow.flow import Flow, listen, start
from pydantic import BaseModel

class RacingState(BaseModel):
    race_info: str = ""
    analysis: str = ""
    prediction: str = ""

class RacingPredictionFlow(Flow[RacingState]):

    @start()
    def fetch_race_data(self):
        """フロー開始: レースデータ取得"""
        self.state.race_info = "天皇賞春2026 出走15頭..."
        return self.state.race_info

    @listen(fetch_race_data)
    def analyze_data(self, race_info):
        """データ分析"""
        # AI で分析
        self.state.analysis = f"{race_info} を分析: 本命はA馬..."
        return self.state.analysis

    @listen(analyze_data)
    def generate_prediction(self, analysis):
        """最終予想生成"""
        self.state.prediction = f"予想: 本命A馬 / 対抗B馬 / 三連複 A-B-C"
        return self.state.prediction

# 実行
flow = RacingPredictionFlow()
result = flow.kickoff()
print(result)
```

## Hierarchical Process (マネージャー管理)

```python
from crewai import Agent, Crew, Process

# マネージャーが自動でタスクを割り当て
manager = Agent(
    role="競馬予想チームマネージャー",
    goal="チーム全体のアウトプット品質を管理する",
    llm=ChatAnthropic(model="claude-sonnet-4-6", ...),
)

crew = Crew(
    agents=[researcher, analyst, predictor],
    tasks=[research_task, analysis_task, prediction_task],
    process=Process.hierarchical,
    manager_agent=manager,  # マネージャーがタスク割り当てを管理
    verbose=True,
)
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 317→318社化: CrewAI 追加',
  'PS#3 S111。CrewAI (Role-based マルチエージェント/Agent+Task+Crew抽象化/Sequential+Hierarchical Process/カスタムツール/CrewAI Flows イベント駆動/Long-term Memory/Claude統合/GitHub 26k+/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
