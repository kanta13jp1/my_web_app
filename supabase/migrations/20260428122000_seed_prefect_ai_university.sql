-- PS#3 S90: AI大学 274→275社化 — Prefect (Pythonネイティブワークフロー / Airflow代替)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'prefect', 'overview',
  'Prefect — Pythonネイティブワークフロー・Airflow代替・動的パイプライン・クラウドオーケストレーション (GitHub 15k+ / 9/9)',
  $$## Prefect とは

**Prefect** は Python ファーストのワークフローオーケストレーションツール。2018年創業、Washington DC 拠点。Airflow の複雑さを解消するために設計された次世代ツール。

GitHub 15,000+ スター。Apache 2.0 ライセンス。Prefect Cloud (SaaS) とオープンソース版 Prefect Server 両方提供。ML/データエンジニアリング/自動化ワークフローで広く採用。

## Airflow との比較

```
"データサイエンティストに優しいオーケストレーター"

Airflow の課題:
  ✗ DAG ファイルを XML/YAML 的な Python で書く必要 (複雑)
  ✗ ローカルテストが困難
  ✗ 動的なタスク数が苦手
  ✗ インフラ管理が重い

Prefect の解決策:
  ✓ 普通の Python 関数に @flow / @task をつけるだけ
  ✓ ローカルでそのまま実行・デバッグ可能
  ✓ 動的なタスク数に対応 (map/submit)
  ✓ Prefect Cloud で UI・スケジュール・監視をゼロ設定
```

## コアコンセプト: Flow と Task

```python
from prefect import flow, task
from prefect.logging import get_run_logger

# Task: 再利用可能な処理単位 (自動リトライ・キャッシュ付き)
@task(retries=3, retry_delay_seconds=10, cache_key_fn=task_input_hash)
def fetch_data(source_url: str) -> list[dict]:
    import httpx
    response = httpx.get(source_url)
    return response.json()

@task
def process_record(record: dict) -> dict:
    return {
        "id": record["id"],
        "score": float(record["score"]) * 1.1,  # 変換処理
    }

@task
def save_results(results: list[dict]) -> int:
    # Supabase に保存する処理
    return len(results)

# Flow: Task を組み合わせるワークフロー
@flow(name="jibun-kaisha-data-pipeline", log_prints=True)
def jibun_kaisha_pipeline(source_url: str = "https://api.jibun-kaisha.com/data"):
    logger = get_run_logger()
    logger.info(f"Pipeline started: {source_url}")

    # データ取得
    raw_data = fetch_data(source_url)

    # 並列処理 (map で全件を並列 submit)
    futures = process_record.map(raw_data)
    processed = [f.result() for f in futures]

    # 保存
    count = save_results(processed)
    logger.info(f"Saved {count} records")
    return count

# ローカル実行 (そのまま Python として動く)
if __name__ == "__main__":
    jibun_kaisha_pipeline()
```

## 動的ワークフロー (Airflow が苦手な領域)

```python
from prefect import flow, task
from typing import Any

@task
def train_model(params: dict) -> dict:
    # ... 訓練処理 ...
    return {"params": params, "accuracy": 0.92}

@flow
def hyperparameter_search(param_grid: list[dict]) -> dict:
    # 動的な並列実行 (件数は実行時に決まる)
    futures = train_model.map(param_grid)
    results = [f.result() for f in futures]

    # 最良パラメータを選択
    best = max(results, key=lambda r: r["accuracy"])
    return best

# 実行
param_grid = [
    {"lr": 1e-5, "dropout": 0.1},
    {"lr": 1e-4, "dropout": 0.2},
    {"lr": 2e-5, "dropout": 0.15},
    {"lr": 5e-5, "dropout": 0.05},
]
best_params = hyperparameter_search(param_grid)
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **データパイプライン** | Supabase データ同期を Flow 化 | 障害時自動リトライ |
| **ML 実験** | ハイパーパラメータ並列探索 | 探索時間を 1/N に削減 |
| **スケジュール処理** | 毎日の集計・レポート生成 | cron より可観測性高い |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'prefect', 'api',
  'Prefect 実践 — デプロイ/スケジュール/Prefect Cloud/Worker/サブフロー/アーティファクト/通知',
  $$## インストール & セットアップ

```bash
pip install prefect

# バージョン確認
prefect version

# Prefect Cloud にログイン (無料プランあり)
prefect cloud login

# または Self-hosted Server を起動
prefect server start  # http://localhost:4200 で UI 起動
```

## デプロイ: Flow をスケジュール実行

```python
# pipeline.py
from prefect import flow, task
from prefect.deployments import DeploymentImage
import anthropic

@task
def summarize_content(text: str) -> str:
    client = anthropic.Anthropic()
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=500,
        messages=[{"role": "user", "content": f"要約してください: {text}"}]
    )
    return response.content[0].text

@flow(name="jibun-kaisha-daily-summary")
def daily_summary_flow():
    # 毎日のデータを取得して AI で要約
    from datetime import date
    today = date.today().isoformat()
    content = fetch_today_data(today)  # Supabase から取得
    summary = summarize_content(content)
    save_summary(summary)
    return summary

if __name__ == "__main__":
    # デプロイ作成 (Prefect Cloud/Server に登録)
    daily_summary_flow.serve(
        name="daily-summary-prod",
        cron="0 8 * * *",   # 毎日 AM8時
        tags=["production", "daily"],
        description="毎日のコンテンツを AI で要約して保存",
    )
```

```bash
# デプロイ起動
python pipeline.py

# または CLI でデプロイ確認
prefect deployment list
prefect deployment run "jibun-kaisha-daily-summary/daily-summary-prod"
```

## Worker: インフラで実行

```bash
# プロセス Worker (ローカル/サーバー)
prefect worker start --pool "jibun-kaisha-process-pool"

# Docker Worker
prefect worker start --pool "jibun-kaisha-docker-pool" --type docker

# Kubernetes Worker
prefect worker start --pool "jibun-kaisha-k8s-pool" --type kubernetes
```

```python
# Docker 環境でデプロイ
from prefect.deployments import Deployment
from prefect.infrastructure import DockerContainer

deployment = Deployment.build_from_flow(
    flow=daily_summary_flow,
    name="daily-summary-docker",
    infrastructure=DockerContainer(
        image="jibun-kaisha/prefect-worker:latest",
        env={"SUPABASE_URL": "$SUPABASE_URL"},
    ),
    schedule={"cron": "0 8 * * *", "timezone": "Asia/Tokyo"},
)
deployment.apply()
```

## サブフロー: Flow の入れ子構造

```python
from prefect import flow

@flow(name="fetch-subflow")
def fetch_and_validate(source: str) -> list:
    data = fetch_data(source)
    validated = [d for d in data if d.get("score") is not None]
    return validated

@flow(name="main-pipeline")
def main_pipeline():
    # サブフロー呼び出し (独立した実行として記録される)
    data_a = fetch_and_validate("source-a")
    data_b = fetch_and_validate("source-b")
    combined = data_a + data_b
    save_results(combined)
```

## Artifacts: 実行結果の可視化

```python
from prefect import flow, task
from prefect.artifacts import create_markdown_artifact, create_table_artifact

@task
def evaluate_model(model_path: str) -> dict:
    metrics = {"accuracy": 0.934, "f1": 0.921, "precision": 0.948}

    # Markdown アーティファクト (Prefect UI に表示される)
    create_markdown_artifact(
        key="evaluation-report",
        markdown=f"""
## モデル評価結果

| メトリクス | スコア |
|-----------|--------|
| Accuracy  | {metrics['accuracy']:.3f} |
| F1 Score  | {metrics['f1']:.3f} |
| Precision | {metrics['precision']:.3f} |
        """,
        description="jibun-kaisha-sentiment v3 評価",
    )

    return metrics

@task
def generate_comparison(results: list[dict]) -> None:
    # テーブルアーティファクト (複数実験の比較)
    create_table_artifact(
        key="experiment-comparison",
        table={"columns": ["run", "accuracy", "f1"], "data": results},
        description="実験比較表",
    )
```

## 通知: 失敗時に Slack 通知

```python
from prefect import flow
from prefect.blocks.notifications import SlackWebhook

@flow(name="critical-pipeline")
def critical_pipeline():
    try:
        run_critical_tasks()
    except Exception as e:
        # 失敗時に Slack 通知
        slack = SlackWebhook.load("jibun-kaisha-slack")
        slack.notify(f"🚨 Pipeline failed: {str(e)}")
        raise
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 274→275社化: Prefect 追加',
  'PS#3 S90。Prefect (Pythonネイティブ/@flow/@task/動的map並列/Prefect Cloud/Worker/Docker+K8s/サブフロー/Artifacts可視化/Slack通知/GitHub 15k+/Apache 2.0/9/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
