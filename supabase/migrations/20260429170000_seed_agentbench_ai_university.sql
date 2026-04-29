-- PS#3 S141: AI大学 377→378社化 — AgentBench (清華大学 / マルチ環境エージェント評価 / 8環境統合ベンチマーク)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'agentbench', 'overview',
  'AgentBench (清華大学) — マルチ環境エージェント統合評価・8環境・LLM-as-Agentの標準BM (9/9)',
  $$## AgentBench とは

**AgentBench** は **清華大学** (Tsinghua University) の Xiao Liu, Hao Yu らが 2023年8月に発表した、**8つの異なる環境で LLM エージェントの性能を統合評価する**包括的なベンチマーク。

SWE-bench はコーディング、WebArena は Web 操作に特化しているのに対し、AgentBench は **「日常的なコンピュータ操作全般」**を評価する最も広範なベンチマーク。

## AgentBench の 8 環境

```
AgentBench が評価する 8 環境:

  1. OS (オペレーティングシステム):
     ・bash コマンドでファイル操作
     ・例: "Find all Python files modified today"
     → ls / find / grep などのコマンド実行

  2. DB (データベース):
     ・SQL クエリの生成・実行
     ・例: "Find the top 3 customers by revenue in Q1"
     → SELECT / JOIN / GROUP BY / ORDER BY

  3. KG (知識グラフ):
     ・Freebase / Wikidata のクエリ
     ・例: "Who is the director of the film that won Oscar 2023?"
     → SPARQL / 知識グラフナビゲーション

  4. HH (Household / 家庭環境):
     ・家庭用ロボットシミュレーション (ALFWorld)
     ・例: "Put the apple on the kitchen table"
     → テキスト環境でのオブジェクト操作

  5. WS (Web Shopping):
     ・EC サイトでの購買タスク
     ・例: "Find the cheapest laptop under $500"

  6. WA (Web Arena):
     ・WebArena と同様の Web ナビゲーション
     ・実際のブラウザ操作

  7. M2W (Mind2Web):
     ・多様な Web サイトのタスク
     ・137 サイト、2,000+ タスク

  8. LTP (Lateral Thinking Puzzles):
     ・推論・創造的問題解決
     ・はい/いいえの質問で謎を解く
```

## AgentBench のスコア分析

```
AgentBench のモデル別スコア (2023年時点):

  Overall Score (8環境平均):

  GPT-4:         ~3.79 (最高)
  GPT-3.5:       ~2.61
  Claude 2:      ~2.22
  Gemini Pro:    ~2.11
  Llama 2 70B:   ~0.89
  Open Source:   ~0.5 以下が多い

  注目ポイント:
    ・GPT-4 でも 3.79/10 程度
    ・「簡単そうに見えるタスクが難しい」を証明
    ・オープンソースモデルは商用に大きく劣る

  環境別の傾向:
    ・DB: LLM が最も得意 (SQL生成は既存スキル)
    ・OS: 中程度 (コマンド知識必要)
    ・HH: 苦手 (物理的直感が必要)
    ・WA: 苦手 (動的 Web 操作)
    ・LTP: GPT-4 が突出 (創造的推論)
```

## AgentBench のアーキテクチャ

```python
# AgentBench の評価フレームワーク (概念的)
from agentbench import AgentBenchEvaluator

# 評価する環境を選択
evaluator = AgentBenchEvaluator(
    environments=["os", "db", "web_shopping"],  # 任意の組み合わせ
    model="gpt-4",
    max_rounds=5  # 1タスクあたり最大5往復
)

# 評価実行
results = evaluator.evaluate(
    num_episodes=100  # 各環境100タスク
)

# 結果
for env, score in results.items():
    print(f"{env}: {score:.2f}/10")

# OS:           3.2/10
# DB:           5.8/10
# Web Shopping: 2.1/10
```

## AgentBench が明らかにしたこと

```
AgentBench の主要な発見:

  1. LLM はまだ "Agent" として弱い:
     ・最高でも GPT-4 が ~3.79/10
     ・「難しいタスク」よりも「複数ステップのタスク」が苦手
     ・エラーが蓄積するほど精度が落ちる

  2. 環境によって得意・不得意が大きく異なる:
     ・SQL: 既存の訓練データが豊富 → 得意
     ・ロボット操作: 物理直感なし → 苦手

  3. オープンソースモデルの課題:
     ・Llama 2 は商用モデルの 1/4 以下
     ・「エージェント能力は商用モデルの独壇場」(2023年時点)
     ・2024年以降: Mistral / Llama 3 で差が縮まる

  4. コンテキスト長が重要:
     ・長い会話履歴が必要なタスクで差がつく
     ・MemGPT のような長期記憶設計の重要性を裏付け
```

## WebArena / SWE-bench / AgentBench の位置づけ

```
主要エージェントベンチマーク比較:

  SWE-bench (Princeton, 2023-10):
    ・コーディング特化
    ・GitHub Issue 解決
    ・2,294 タスク
    → 「AIはコーダーになれるか？」

  WebArena (CMU, 2023-07):
    ・Web ナビゲーション特化
    ・ブラウザ操作
    ・812 タスク
    → 「AIはWebを使えるか？」

  AgentBench (清華大学, 2023-08):
    ・多環境統合評価
    ・OS/DB/Web/ゲーム/推論
    ・~2,000 タスク
    → 「AIは汎用コンピュータ操作ができるか？」

  → 3つ全部が揃って初めて「AI エージェントの総合評価」になる
```

## 自分株式会社との関連

AgentBench の「8環境統合評価」は、自分株式会社の ai-hub EF が担当する多様なアクション (CS返信 / 競合分析 / AI大学更新 / コード修正 / DB クエリ) の評価設計に直接応用できる。特に AgentBench の DB 環境 (SQL 生成) は schedule-hub EF の `digest.run` action の自動テストに、OS 環境 (bash コマンド) は GHA ワークフローの自動テストに活用できる。AgentBench のスコアがモデル選定 (Haiku vs Sonnet) の根拠データとしても使える。
$$,
  'https://github.com/THUDM/AgentBench',
  NOW(),
  378
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
