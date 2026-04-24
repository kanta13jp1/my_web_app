-- Session PS#3-S39: AI大学 173社化 — Prefect 追加
-- 2018年創業の Python-first ワークフローオーケストレーションプラットフォーム。
-- 2021-06 Series B $32M (Tiger Global 主導 / Bessemer Venture Partners) / 累計 ~$46M。
-- Data / ML / AI エージェント 3軸を 1 エンジンで統合管理。
-- Horizon: AI インフラ専用機能 — エージェントワークフロー・非同期タスク実行。
-- Python デコレータ (@flow / @task) で既存コードを即 DAG 化。
-- Apache 2.0 OSS + Prefect Cloud (seat課金 / 使用量課金なし / 無制限ワークフロー)。
-- Step 0: 8/9 (Tiger Global Bessemer / Python-first / Data+ML+Agent統合 / Horizon AI / unlimited workflows)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'prefect',
  'overview',
  'Prefect — Python-first ワークフローオーケストレーション (Data + ML + AI エージェント統合)',
  $md$
# Prefect — Workflow Orchestration & AI Infrastructure

Data・ML・AI エージェントを **1 つのエンジン**で統合オーケストレーションする
Python-first プラットフォーム。

2021 年 Series B $32M (Tiger Global 主導 / Bessemer Venture Partners) / 累計 **~$46M**。

**Python デコレータ 2 行**で既存コードをクラウド対応の監視可能なワークフローに変換。
Airflow・Dagster との対比で「**60-70% コスト削減**・シンプルな Python」として採用が広がる。

## 3 つのユースケース

| ユースケース | 説明 |
| :--- | :--- |
| **データ** | ETL / ELT パイプライン / データ品質チェック / スケジュール実行 |
| **ML** | モデル学習ジョブ / 特徴量エンジニアリング / 評価パイプライン |
| **AI エージェント** | Horizon による AI インフラ / 非同期エージェントワークフロー |

## Horizon — AI インフラ機能

Prefect の最新コンポーネントで、AI エージェント特有の課題に対応:
- 長時間実行エージェントの**チェックポイント & 再開**
- マルチエージェントのオーケストレーション
- ツール呼び出し・外部 API 統合のリトライ管理
- エージェント実行の観測・ログ・アラート

## 強み

- **Python @flow / @task** — 既存コードへの 2 行追加で DAG 化
- **ハイブリッドアーキテクチャ** — コードをユーザーインフラで実行 / Prefect はオーケストレーション層のみ
- **使用量課金なし** — ワークフロー数・タスク数に上限なし (座席課金のみ)
- **Airflow 比 60-70% コスト削減** — 設定・インフラコストを大幅削減
$md$,
  'https://www.prefect.io',
  '2026-04-24',
  1
),

(
  'prefect',
  'models',
  'Prefect 料金・プラン比較 (2026)',
  $md$
## Prefect 料金プラン (2026)

| プラン | 価格 | 特徴 |
| :--- | :--- | :--- |
| **Hobby (OSS)** | 完全無料 | self-host / 機能フル / コミュニティサポート |
| **Pro** | $19/開発者/月 | Prefect Cloud / チームコラボ / SLA なし |
| **Enterprise** | カスタム | SSO / RBAC / 専任サポート / SLA / 監査ログ |

> **使用量課金ゼロ** — ワークフロー実行数・タスク実行数・データ転送量は無制限

### Prefect vs Airflow コスト比較

| 項目 | Prefect | Apache Airflow (セルフホスト) |
| :--- | :--- | :--- |
| **設定時間** | ~1 時間 | ~1 週間 |
| **インフラコスト** | 最小 (ハイブリッド) | 高 (専用クラスター) |
| **メンテナンス** | 低 (マネージド) | 高 (自己管理) |
| **Python 互換性** | ネイティブ | Operators 抽象化 |

### Prefect OSS vs Prefect Cloud

| 機能 | OSS (self-host) | Cloud |
| :--- | :--- | :--- |
| **フロー実行** | ✅ | ✅ |
| **スケジューリング** | ✅ | ✅ |
| **UI ダッシュボード** | ✅ | ✅ (エンハンスド) |
| **チーム管理** | — | ✅ |
| **アラート** | — | ✅ |
| **監査ログ** | — | Enterprise |
$md$,
  'https://www.prefect.io/pricing',
  '2026-04-24',
  2
),

(
  'prefect',
  'api',
  'Prefect API 入門 — Python ワークフロー & AI エージェント',
  $md$
## Prefect の始め方

### インストール & セットアップ

```bash
pip install prefect
prefect cloud login  # Prefect Cloud に接続 (または self-host)
```

### ML パイプラインを @flow で定義

```python
from prefect import flow, task
from anthropic import Anthropic

# @task: 単一ステップを定義 (自動でリトライ・ログ・キャッシュ対応)
@task(retries=3, retry_delay_seconds=10)
def fetch_ai_providers() -> list[dict]:
    return [
        {"name": "LangSmith", "category": "observability"},
        {"name": "Braintrust", "category": "evaluation"},
        {"name": "Galileo AI", "category": "guardrails"},
    ]

@task
def analyze_provider(provider: dict) -> str:
    client = Anthropic()
    message = client.messages.create(
        model="claude-opus-4-7",
        max_tokens=256,
        messages=[{
            "role": "user",
            "content": f"{provider['name']} の強みを 1 文で説明してください"
        }]
    )
    return message.content[0].text

# @flow: タスクをオーケストレーション
@flow(name="ai-university-analysis", log_prints=True)
def analyze_all_providers():
    providers = fetch_ai_providers()
    # 並列実行 (Prefect が自動でスケジューリング)
    results = analyze_provider.map(providers)
    for provider, result in zip(providers, results):
        print(f"{provider['name']}: {result.result()}")

if __name__ == "__main__":
    analyze_all_providers()
    # → Prefect UI でフロー実行・ログ・タスクグラフを確認可能
```

### AI エージェントワークフロー (Horizon)

```python
from prefect import flow, task
from prefect.tasks import task_input_hash
from datetime import timedelta

@task(
    cache_key_fn=task_input_hash,
    cache_expiration=timedelta(hours=1),  # 1時間キャッシュ
    retries=3
)
def agent_step(input_data: str, step_name: str) -> str:
    """エージェントの各ステップ — 失敗時は自動リトライ"""
    from anthropic import Anthropic
    client = Anthropic()
    msg = client.messages.create(
        model="claude-opus-4-7",
        max_tokens=512,
        messages=[{"role": "user", "content": input_data}]
    )
    return msg.content[0].text

@flow(name="multi-agent-ai-university")
def multi_agent_pipeline(query: str):
    # エージェント 1: 調査
    research = agent_step(f"以下を調査: {query}", "research")
    # エージェント 2: 分析 (依存関係を自動解決)
    analysis = agent_step(f"以下を分析: {research}", "analysis")
    # エージェント 3: レポート生成
    report = agent_step(f"以下をレポート化: {analysis}", "report")
    return report

if __name__ == "__main__":
    result = multi_agent_pipeline("AI大学で学べる観測ツール")
    print(result)
```

### スケジュール実行

```python
from prefect.schedules import CronSchedule

@flow(
    name="daily-ai-update",
    schedule=CronSchedule(cron="0 9 * * *")  # 毎朝 9時
)
def daily_update():
    providers = fetch_ai_providers()
    analyze_provider.map(providers)

# デプロイ (Prefect Cloud 管理下で自動実行)
daily_update.deploy(name="production")
```

## クイックスタート

1. `pip install prefect` でインストール
2. `@flow` と `@task` デコレータを既存 Python 関数に追加
3. `prefect cloud login` でクラウド接続
4. `python my_flow.py` で実行 → Prefect UI でモニタリング
5. `schedule=CronSchedule(...)` でスケジュール実行を有効化
$md$,
  'https://docs.prefect.io/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
