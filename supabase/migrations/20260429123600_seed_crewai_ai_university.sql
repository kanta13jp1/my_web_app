-- PS#3 S131: AI大学 356→357社化 — CrewAI (商用マルチエージェント / 役割定義 / タスク委譲 / 30k+ stars)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'crewai', 'overview',
  'CrewAI — 商用マルチエージェントフレームワーク・役割定義・タスク委譲・エンタープライズ対応 (9/9)',
  $$## CrewAI とは

**CrewAI** は AI エージェントの「チーム」を構成して複雑なタスクを分解・並列実行するマルチエージェントフレームワーク。MetaGPT の学術アプローチと異なり、**プロダクション利用を前提**に設計された商用グレードのフレームワーク。

2024年に急速に普及し、**GitHub 30,000+ stars**を獲得。LangChain エコシステムから独立して自社プラットフォームを展開している。

## CrewAI のコアコンセプト

```
CrewAI の構成要素:

  Agent (エージェント):
    ・role: "Senior Data Analyst" (役職)
    ・goal: "データから洞察を抽出する" (目標)
    ・backstory: "10年のデータ分析経験..." (背景)
    ・tools: [search_tool, csv_tool] (使えるツール)
    ・verbose: True (思考過程を表示)

  Task (タスク):
    ・description: "売上データを分析して..." (説明)
    ・expected_output: "レポート形式で..." (期待出力)
    ・agent: data_analyst (担当エージェント)

  Crew (チーム):
    ・agents: [analyst, writer, reviewer] (チームメンバー)
    ・tasks: [analyze, write, review] (タスクリスト)
    ・process: sequential | hierarchical (実行方式)
```

## 実際のコード例

```python
from crewai import Agent, Task, Crew, Process

# エージェント定義
researcher = Agent(
    role='AIリサーチアナリスト',
    goal='最新のAIトレンドを調査してレポートを書く',
    backstory='AI専門メディアのシニアアナリスト。正確さを重視。',
    tools=[search_tool, web_scraper],
    verbose=True
)

writer = Agent(
    role='テックライター',
    goal='技術的な内容を分かりやすく文章化する',
    backstory='ITメディアで5年の執筆経験。',
    verbose=True
)

# タスク定義
research_task = Task(
    description='2025年のAIコーディングツールトップ5を調査する',
    expected_output='各ツールの特徴・価格・対象ユーザーを含む箇条書きリスト',
    agent=researcher
)

write_task = Task(
    description='調査結果を日本語のブログ記事にまとめる',
    expected_output='見出し・本文・まとめを含む1500字の記事',
    agent=writer
)

# クルー (チーム) を構成して実行
crew = Crew(
    agents=[researcher, writer],
    tasks=[research_task, write_task],
    process=Process.sequential  # 順番に実行
)

result = crew.kickoff()
```

## Sequential vs Hierarchical

```
Sequential (順次実行):
  Task1 → Task2 → Task3
  ・シンプルなパイプライン
  ・前のタスクの出力が次の入力

Hierarchical (階層型):
  Manager Agent
  ├── Worker Agent 1 → Task A
  ├── Worker Agent 2 → Task B
  └── Worker Agent 3 → Task C
  ・マネージャーが判断・委譲
  ・より自律的な実行
```

## CrewAI Enterprise

```
CrewAI のプロダクト:

  CrewAI OSS: GitHub で無料公開 (Apache-2.0)
  CrewAI+:    有料プラットフォーム
    ・ビジュアルフロービルダー
    ・本番モニタリング
    ・チームコラボレーション
    ・エンタープライズサポート
```

## 自分株式会社との関連

CrewAI の「役割定義 (role/goal/backstory) → タスク委譲 → チーム実行」パターンは、自分株式会社の 12 インスタンスフリートの役割定義と同一構造。PS版#3 は「AI大学担当」という role を持ち、「AI大学コンテンツを追加する」という goal で動作している。CrewAI の Hierarchical モードは、Win版がアーキテクチャを決定し VSCode版/PS版が実装を担当する自分株式会社の階層型分業と同一パターン。
$$,
  'https://github.com/crewAIInc/crewAI',
  NOW(),
  357
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
