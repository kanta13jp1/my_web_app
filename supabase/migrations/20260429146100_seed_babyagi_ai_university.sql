-- PS#3 S136: AI大学 366→367社化 — BabyAGI (Yohei Nakajima / タスク管理型自律エージェント / 2023年AGI先駆者)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'babyagi', 'overview',
  'BabyAGI (Yohei Nakajima) — タスク管理型自律エージェント・AGI先駆者・140行のAI革命 (9/9)',
  $$## BabyAGI とは

**BabyAGI** は VC (ベンチャーキャピタリスト) の **Yohei Nakajima** が 2023年4月に公開した、わずか **140行の Python コード**で実装された自律的タスク管理 AI エージェント。

「目標を与えれば、タスクを自分で作り、実行し、評価して、次のタスクを考え続ける」という**タスク駆動型の自律ループ**を最初に明確に定義した作品として、AI エージェント設計の歴史に残る。

## BabyAGI の動作原理

```
BabyAGI の無限ループ (4ステップ):

  1. タスク実行 (Execution Agent):
     ・タスクリストの先頭タスクを取り出す
     ・LLM でタスクを実行して結果を得る
     ・結果をベクトル DB に保存

  2. 結果エンリッチ (Enrichment):
     ・実行結果を記録
     ・次ステップに文脈として渡す

  3. タスク生成 (Creation Agent):
     ・実行結果と目標を踏まえて
     ・LLM で新しいタスクを生成
     ・タスクリストに追加

  4. タスク優先付け (Prioritization Agent):
     ・全タスクリストを目標に沿って並べ替え
     ・重複・無関係タスクを削除
     ・ループの先頭に戻る

  繰り返す ∞
```

## 実際のコード (概念的に)

```python
import openai
import pinecone
from collections import deque

# 設定
OBJECTIVE = "Supabaseを使ったTodoアプリの開発計画を立てる"
INITIAL_TASK = "最初のタスクリストを作成する"

task_list = deque([{"task_id": 1, "task_name": INITIAL_TASK}])

def execution_agent(objective: str, task: str, context: str) -> str:
    """タスクを実行して結果を返す"""
    response = openai.ChatCompletion.create(
        model="gpt-4",
        messages=[
            {"role": "system", "content": f"You are a helpful assistant. Objective: {objective}"},
            {"role": "user", "content": f"Context: {context}\nTask: {task}\nResponse:"}
        ]
    )
    return response.choices[0].message.content

def task_creation_agent(objective: str, result: str, task_description: str, task_list: list) -> list:
    """実行結果から新しいタスクを生成する"""
    response = openai.ChatCompletion.create(
        model="gpt-4",
        messages=[{
            "role": "user",
            "content": f"""
            Objective: {objective}
            Completed task: {task_description}
            Result: {result}
            Existing tasks: {[t["task_name"] for t in task_list]}

            Create new tasks to complete the objective. Return a numbered list.
            """
        }]
    )
    # レスポンスをパースしてタスクリストに変換
    new_tasks = response.choices[0].message.content.strip().split('\n')
    return [{"task_name": t.strip()} for t in new_tasks if t.strip()]

# メインループ
while task_list:
    task = task_list.popleft()

    # コンテキスト取得 (ベクトル検索で関連する過去結果を取得)
    context = get_relevant_context(task["task_name"])

    # タスク実行
    result = execution_agent(OBJECTIVE, task["task_name"], context)

    # 結果を保存
    store_result(task["task_id"], result)

    # 新しいタスクを生成
    new_tasks = task_creation_agent(OBJECTIVE, result, task["task_name"], list(task_list))

    # 優先付けして追加
    task_list = prioritization_agent(task_list + new_tasks, OBJECTIVE)
```

## BabyAGI が与えた影響

```
2023年4月 → AI エージェント革命:

  公開直後の反響:
    ・Twitter で瞬く間にバイラル
    ・1週間で 10k+ stars
    ・「AGI への道筋が見えた」と話題

  後継プロジェクトへの影響:
    ・AutoGPT (2023-04): 同時期公開、BabyAGI と並んで話題
    ・SuperAGI (2023-05): BabyAGI のプロダクション化
    ・AgentVerse / MetaGPT: マルチエージェント化
    ・LangChain Agents: フレームワーク化
    ・Devin (2024): 専門特化版として進化

  概念的貢献:
    ・「タスク生成 → 実行 → 評価 → 再生成」ループの明文化
    ・ベクトル DB による長期記憶の標準化
    ・「140行でAGIの原型」= シンプルさの価値を証明
```

## BabyAGI の限界と学び

```
BabyAGI の課題 (=次世代が解決):

  終了条件なし:
    ・目標達成を判定できない
    ・無限ループで止まらない
    → SuperAGI / AgentVerse が改善

  ハルシネーション:
    ・実行結果を検証しない
    ・間違ったタスクが増殖
    → Generator-Verifier パターンが解決

  並列実行なし:
    ・タスクを1つずつ処理
    → CrewAI / AutoGen が並列化

  コスト管理なし:
    ・API コールが無制限に増加
    → tools-hub の task_budget が解決策

  これらは全て「最初のプロトタイプ」として許容される
  BabyAGI の価値は 完成度 ではなく 概念の先行提示
```

## BabyAGI と Yohei Nakajima

```
Yohei Nakajima (中嶋洋介) について:

  背景:
    ・日系アメリカ人 VC
    ・Untapped Capital パートナー
    ・スタートアップ投資家としての視点

  BabyAGI 公開の動機:
    ・"AI が自律的にタスクを管理できたら"
    ・個人の生産性向上ツールとして作成
    ・「公開したら反響があった」= Build in Public

  現在:
    ・BabyAGI の発展版を継続開発
    ・AI エージェント分野のオピニオンリーダー
    ・日本とシリコンバレーをつなぐ存在
```

## 自分株式会社との関連

BabyAGI の「目標設定 → タスク自動生成 → 実行ループ」アーキテクチャは、自分株式会社の `daily-judgment` EF と直結する。現在の判定 EF は単発実行だが、BabyAGI パターンを応用すれば「今日の目標 → 達成に必要なタスクを自動生成 → 各タスクをEF経由で実行 → 進捗評価 → 翌日目標の再設定」という真の自律ライフマネジメントに進化できる。また `task_budget` (PS#3 と Win版#132 で設計中) は BabyAGI の「コスト管理なし」問題への直接回答。
$$,
  'https://github.com/yoheinakajima/babyagi',
  NOW(),
  367
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
