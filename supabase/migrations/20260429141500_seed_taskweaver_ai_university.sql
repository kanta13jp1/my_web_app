-- PS#3 S135: AI大学 364→365社化 — TaskWeaver (Microsoft Research / コードファーストAIエージェント / Python実行 / データ分析)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'taskweaver', 'overview',
  'TaskWeaver (Microsoft Research) — コードファーストAIエージェント・Python実行・データ分析特化 (9/9)',
  $$## TaskWeaver とは

**TaskWeaver** は Microsoft Research が開発した**コードファーストの AI エージェントフレームワーク**。テキストベースの命令ではなく、**Python コードを実行単位**としてタスクを処理する設計が最大の特徴。

2023年11月に公開され、特に**データ分析・データ処理タスク**に強みを持つ。

## TaskWeaver のコアコンセプト

```
TaskWeaver の設計哲学:

  コードファーストアプローチ:
    ・LLM がテキストではなく Python コードを生成
    ・コードを実行して結果を得る
    ・エラーが発生したら自動修正して再実行
    ・テキスト生成より確実性が高い

  通常の LLM エージェント vs TaskWeaver:
    通常: LLM → テキスト回答 → ユーザーが解釈
    TaskWeaver: LLM → コード生成 → 実行 → 確実な結果
```

## TaskWeaver のアーキテクチャ

```
TaskWeaver の 2 コンポーネント構成:

  Planner (計画者):
    ・ユーザーのタスクを受け取る
    ・サブタスクに分解する
    ・CodeInterpreter に指示を出す
    ・最終回答をまとめる

  CodeInterpreter (コード実行者):
    ・Planner の指示を Python コードに変換
    ・コードを安全な環境で実行
    ・実行結果を Planner に返す
    ・エラー時は自動修正して再試行

  Plugin System (拡張機能):
    ・外部ツール・API を Plugin として定義
    ・yaml ファイルで Plugin を宣言
    ・LLM が適切な Plugin を選択して呼び出す
```

## 実際の動作例

```python
# TaskWeaver の基本的な使用
import taskweaver

# エージェントの初期化
agent = taskweaver.AppContext("./config")
session = agent.get_session()

# タスクを送信 (自然言語)
result = session.send_message(
    "sales_data.csv を読み込んで、"
    "月別売上をグラフにして、"
    "前月比を計算してください"
)

# TaskWeaver が内部で実行するコード (自動生成):
# import pandas as pd
# import matplotlib.pyplot as plt
# df = pd.read_csv('sales_data.csv')
# monthly = df.groupby('month')['sales'].sum()
# monthly.plot(kind='bar')
# plt.savefig('monthly_sales.png')
# df['growth'] = df['sales'].pct_change() * 100

print(result.message)
# "月別売上グラフを生成しました。前月比: 1月→2月: +15.2%, ..."
```

## Plugin 定義の例

```yaml
# plugin/sql_query.yaml
name: sql_query
enabled: true
required: false
description: >
  Execute SQL queries on the connected database.
  Use this when the user wants to query data from the database.

parameters:
  - name: query
    type: str
    required: true
    description: The SQL query to execute

returns:
  - name: result
    type: DataFrame
    description: The query result as a pandas DataFrame

examples:
  - query: "SELECT * FROM users WHERE active = TRUE"
```

```python
# plugin/sql_query.py
import pandas as pd
import sqlalchemy

def sql_query(query: str) -> pd.DataFrame:
    engine = sqlalchemy.create_engine(os.environ["DATABASE_URL"])
    return pd.read_sql(query, engine)
```

## TaskWeaver の強み

```
TaskWeaver が得意なタスク:

  データ分析:
    ・CSV/Excel の読み込み・加工
    ・統計計算・集計
    ・グラフ生成 (matplotlib/plotly)
    ・機械学習モデルの実行

  データ処理:
    ・複雑な変換パイプライン
    ・複数データソースの統合
    ・クレンジング・正規化

  コード実行が必要なタスク:
    ・数値計算
    ・文字列処理
    ・ファイル操作
    ・API 呼び出し (Plugin 経由)

  苦手なタスク:
    ・純粋な会話・Q&A
    ・コード実行が不要な検索
    → CrewAI / AutoGen の方が適切
```

## 他フレームワークとの比較

```
TaskWeaver vs 他エージェントフレームワーク:

  TaskWeaver (Microsoft Research):
    ・コードファースト設計
    ・データ分析特化
    ・Plugin ベース拡張
    ・確実性重視

  LangChain / LangGraph:
    ・汎用ワークフロー構築
    ・多数のツール統合
    ・コミュニティ最大

  AutoGen (Microsoft):
    ・マルチエージェント会話
    ・Human-in-the-Loop
    ・より対話的

  CrewAI:
    ・役割ベースチーム
    ・商用サポート
    ・ビジネス向け

  → TaskWeaver = データサイエンス・分析 領域で最適
```

## Microsoft エコシステムとの統合

```
TaskWeaver × Microsoft スタック:

  Azure OpenAI:
    ・GPT-4 / GPT-4o をバックエンドに使用
    ・Azure AD 認証対応
    ・エンタープライズセキュリティ

  Azure ML:
    ・ML パイプラインの一部として組み込み
    ・モデルトレーニング・推論の自動化

  Power BI / Excel:
    ・データ可視化 Plugin
    ・Excel ファイル操作

  GitHub Copilot:
    ・VS Code 拡張との親和性高
```

## 自分株式会社との関連

TaskWeaver の「コードファーストでデータ分析を自動化」アプローチは、自分株式会社の Supabase (PostgreSQL) に蓄積されたユーザーデータの分析自動化に直接応用できる。特に ai-hub EF の分析系 action (ダッシュボードデータ集計 / 競合モニタリング結果分析 / 開発実績トレンド計算) を TaskWeaver の Plugin パターンで設計することで、SQL クエリ → データ加工 → レポート生成の一連を自動化できる。
$$,
  'https://github.com/microsoft/TaskWeaver',
  NOW(),
  365
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
