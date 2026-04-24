-- Session PS#3-S40: AI大学 175社化 — CrewAI 追加
-- ロールプレイ型自律 AI エージェントのオーケストレーションフレームワーク。
-- 2024-11 Series A $12.4M (Insight Partners 主導 / boldstart / Craft / Dharmesh Shah) / 累計 $24.5M / 評価額 $76M。
-- Fortune 500 の 60% が採用 / 月 4.5 億回のエージェントワークフロー / 週 4,000+ 新規登録 / 10 万+ 認定開発者。
-- Crews (役割ベースマルチエージェント) + Flows (プロセス制御) + CrewAI AMP (エンタープライズプラットフォーム)。
-- 顧客: DocuSign (営業リードデータ統合) / PwC (コード生成精度向上)。
-- Step 0: 9/9 (Fortune 500 60% / 4.5億workflows / 10万+認定 / Insight Partners / DocuSign PwC採用)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'crewai',
  'overview',
  'CrewAI — マルチエージェントオーケストレーション (Fortune 500 60% 採用 / 月 4.5 億ワークフロー)',
  $md$
# CrewAI — The Leading Multi-Agent Platform

**ロールプレイ型の自律 AI エージェント**を協調させる OSS フレームワーク。
複数のエージェントに「役割・目標・ツール・記憶」を割り当て、
チームとして複雑なタスクを自律的に解決する。

2024 年 11 月、**Series A $12.4M** (Insight Partners 主導 / boldstart Ventures /
Craft Ventures / Dharmesh Shah) 完了。累計 **$24.5M** / 評価額 **$76M**。

## 採用規模 (2026 時点)

| 指標 | 数値 |
| :--- | :--- |
| **Fortune 500 採用率** | **60%** |
| **月次ワークフロー実行数** | **4.5 億回** |
| **認定開発者数** | **10 万人以上** |
| **週次新規登録** | 4,000+ |
| **GitHub Stars** | 30,000+ |

## 3 つのコアコンセプト

### Crews — ロールベースチームエージェント
複数のエージェントを「役割・目標・ツール・記憶」を持つチームとして編成。
各エージェントが専門分野を担当し、協調して複雑タスクを解決。

### Flows — プロセスとデータの精密制御
エージェントのアクション・状態・分岐を細かく制御するワークフローエンジン。
Crews の自律性と Flows の制御を組み合わせて本番グレードのシステムを構築。

### CrewAI AMP — エンタープライズプラットフォーム
- ビジュアルエディタでコードなしにエージェントチームを設計
- AI コパイロットがワークフロー設計を補助
- リアルタイム観測・ログ・RBAC / セキュアインテグレーション
- サーバーレスコンテナ / 24/7 専任エンタープライズサポート

## 採用事例

| 企業 | 用途 |
| :--- | :--- |
| **DocuSign** | 営業リードデータ統合の自動化 → 営業プロセス高速化 |
| **PwC** | ロール駆動マルチエージェントでコード生成精度を大幅向上 |
$md$,
  'https://crewai.com/',
  '2026-04-24',
  1
),

(
  'crewai',
  'models',
  'CrewAI アーキテクチャ & 料金 (2026)',
  $md$
## CrewAI の 3 層アーキテクチャ

```
CrewAI AMP (Enterprise)
    ↑ ビジュアルエディタ / 観測 / RBAC
Flows (精密制御)
    ↑ 条件分岐 / 状態管理 / イベント駆動
Crews (マルチエージェント)
    ↑ Agent (役割・ツール・記憶) の協調
```

## エージェントの設計要素

| 要素 | 説明 |
| :--- | :--- |
| **Role** | エージェントの職責 (例: "シニアリサーチャー") |
| **Goal** | 達成目標 (例: "最新 AI ニュースを調査・要約") |
| **Backstory** | コンテキスト (専門性・制約を自然言語で記述) |
| **Tools** | 使えるツール (Web 検索 / DB / API / カスタム) |
| **Memory** | 短期・長期・エンティティ記憶 |

## 対応 LLM

OpenAI / Anthropic (Claude) / Google Gemini / Meta Llama /
Groq / Mistral / Cohere / HuggingFace / Ollama (ローカル) 等

## 料金 (2026)

| プラン | 価格 | 概要 |
| :--- | :--- | :--- |
| **OSS** | 完全無料 | self-host / GitHub Apache 2.0 |
| **CrewAI AMP Starter** | $99/月 | 小チーム向けホスティング |
| **Enterprise** | カスタム | SSO / RBAC / SLA / 専任サポート |
$md$,
  'https://docs.crewai.com/',
  '2026-04-24',
  2
),

(
  'crewai',
  'api',
  'CrewAI API 入門 — マルチエージェント構築',
  $md$
## CrewAI の始め方

### インストール

```bash
pip install crewai crewai-tools
```

### AI 大学リサーチチームを構築

```python
from crewai import Agent, Task, Crew, Process
from crewai_tools import SerperDevTool

search_tool = SerperDevTool()

# エージェント 1: リサーチャー
researcher = Agent(
    role="AI 大学リサーチャー",
    goal="最新の AI プロバイダーに関する詳細情報を収集する",
    backstory="""あなたは AI 業界のエキスパートで、
    新興スタートアップから大企業まで幅広く調査できます。""",
    tools=[search_tool],
    llm="claude-opus-4-7",  # Claude を使用
    verbose=True,
)

# エージェント 2: ライター
writer = Agent(
    role="AI 大学コンテンツライター",
    goal="リサーチ結果を日本語でわかりやすく要約する",
    backstory="""技術的な内容を初心者にも理解できる
    平易な日本語で説明するのが得意です。""",
    llm="claude-opus-4-7",
    verbose=True,
)

# タスク定義
research_task = Task(
    description="CrewAI の最新機能・採用事例・競合優位性を調査してください",
    expected_output="箇条書きの詳細リサーチレポート",
    agent=researcher,
)

write_task = Task(
    description="リサーチ結果を AI 大学向けに日本語で要約記事を書いてください",
    expected_output="500字程度の日本語要約記事",
    agent=writer,
    context=[research_task],  # researcher の出力を入力として受け取る
)

# Crew を組成して実行
crew = Crew(
    agents=[researcher, writer],
    tasks=[research_task, write_task],
    process=Process.sequential,  # または Process.hierarchical
    verbose=True,
)

result = crew.kickoff()
print(result)
```

### Flows — 条件分岐ワークフロー

```python
from crewai.flow.flow import Flow, listen, start
from pydantic import BaseModel

class AIUniversityState(BaseModel):
    provider: str = ""
    research: str = ""
    published: bool = False

class AIUniversityFlow(Flow[AIUniversityState]):

    @start()
    def select_provider(self):
        self.state.provider = "CrewAI"
        return self.state.provider

    @listen(select_provider)
    def research_provider(self, provider: str):
        # researcher agent を起動
        self.state.research = f"{provider} のリサーチ結果..."
        return self.state.research

    @listen(research_provider)
    def publish_content(self, research: str):
        # コンテンツを Supabase に保存
        print(f"公開: {research[:50]}...")
        self.state.published = True

flow = AIUniversityFlow()
flow.kickoff()
```

## クイックスタート

1. `pip install crewai crewai-tools` でインストール
2. Agent に role / goal / backstory / llm を設定
3. Task で agent と期待する出力を定義
4. Crew で agents と tasks を組み合わせて `kickoff()`
5. 本番環境: [CrewAI AMP](https://www.crewai.com/crewai-amp) でホスティング・監視
$md$,
  'https://docs.crewai.com/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
