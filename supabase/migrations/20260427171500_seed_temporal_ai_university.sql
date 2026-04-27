-- PS#3 S75: AI大学 245→246社化 — Temporal.io 追加
-- Temporal.io: 耐久性ワークフローエンジン / AIエージェントオーケストレーション / Uber/Airbnb採用 / Python/TypeScript SDK

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'temporal',
  'overview',
  'Temporal.io — 耐久性ワークフローエンジン (AIエージェントオーケストレーション / Uber Cadence後継 / Python/Go/TS SDK)',
  $$## Temporal.io — Durable Workflow Orchestration Engine

**カテゴリ**: Workflow Orchestration / Distributed Systems / AI Agent Infrastructure / DevOps
**開発元**: Temporal Technologies, Inc.
**本社**: San Francisco, California
**設立**: 2019年 (Uber の Cadence プロジェクトを基に創業)
**創業者**: Maxim Fateev (元 AWS SQS / Uber Cadence) + Samar Abbas
**調達額**: $120M+ (Series B / Sequoia Capital 参加)
**採用企業**: Uber / Airbnb / Netflix / Stripe / Snap / HashiCorp / Coinbase
**ライセンス**: MIT (OSS コア) + Temporal Cloud (マネージドSaaS)
**SDK**: Go / Java / Python / TypeScript / PHP / .NET
**評価**: 8/9

### 概要
Temporal.io は **「長時間実行・障害に強いビジネスロジックをコードで書く」** ためのワークフローオーケストレーションエンジン。もともと Uber で開発された Cadence を基に、2019年に独立プロジェクトとして誕生。

**AI時代での重要性**: 2024年以降、**AIエージェントのオーケストレーション基盤** として急速に注目を集めている。LangGraph / CrewAI などのエージェントフレームワークが「複数ステップの自律実行」を目指す一方、Temporal は「**本番環境での耐障害性**」という企業ニーズを満たす。

### Temporal が解決する問題

```
[なぜ通常のコードでは不十分か]

問題シナリオ: 「ユーザー登録 → メール送信 → ウェルカムボーナス付与 → 管理者通知」

通常の実装:
  async function registerUser(user) {
    await db.createUser(user);    // ← サーバークラッシュで失敗？
    await sendEmail(user.email);  // ← メールサービスがダウンで失敗？
    await grantBonus(user.id);    // ← DBタイムアウトで失敗？
    await notifyAdmin(user.id);   // ← 3ステップ成功したのに失敗？
  }
  → どこで失敗したか不明 / 重複実行の危険 / リトライ実装が複雑

Temporal の実装:
  @workflow.defn
  class UserRegistrationWorkflow:
    @workflow.run
    async def run(self, user: UserInput) -> str:
        await workflow.execute_activity(create_user, user)
        await workflow.execute_activity(send_email, user.email)
        await workflow.execute_activity(grant_bonus, user.id)
        await workflow.execute_activity(notify_admin, user.id)
        return "完了"
  → 任意のステップで失敗してもそこから再開 / 重複実行なし / 状態を自動管理
```

### 主な特徴

**1. Durable Execution (耐久性実行)**
- ワークフローの状態をサーバー側で永続化
- サーバークラッシュ後も自動で再開
- タイムアウト (hours/days) でのウェイト可能
- Exactly-Once 実行保証 (重複なし)

**2. タイムアウトとリトライ**
```python
from temporalio import activity, workflow
from datetime import timedelta

@workflow.defn
class LongRunningAIWorkflow:
    @workflow.run
    async def run(self, prompt: str) -> str:
        # 最大10分待ち / 指数バックオフでリトライ / 最大5回
        result = await workflow.execute_activity(
            call_ai_api,
            prompt,
            start_to_close_timeout=timedelta(minutes=10),
            retry_policy=RetryPolicy(
                maximum_attempts=5,
                initial_interval=timedelta(seconds=1),
                backoff_coefficient=2.0,
            ),
        )
        return result
```

**3. Human-in-the-Loop**
```python
@workflow.defn
class ContentModerationWorkflow:
    @workflow.run
    async def run(self, content: str) -> str:
        # AIで一次判定
        ai_result = await workflow.execute_activity(ai_moderate, content)

        if ai_result == "UNCERTAIN":
            # 人間の承認を最大24時間待つ
            approval = await workflow.wait_condition(
                lambda: self._approved is not None,
                timeout=timedelta(hours=24),
            )
            return "approved" if self._approved else "rejected"

        return ai_result

    @workflow.signal
    def approve(self) -> None:
        self._approved = True

    @workflow.signal
    def reject(self) -> None:
        self._approved = False
```

**4. AI エージェント統合 (2024〜)**
- LangChain / LangGraph エージェントを Temporal ワークフローでラップ
- エージェントの各ステップが Temporal Activity として記録
- 長時間実行エージェント (数時間〜数日) でも安全に実行可能
- エージェント実行の監査ログが自動生成

### ユースケース例

| ユースケース | 内容 |
|------------|------|
| ユーザーオンボーディング | 登録→メール→チュートリアル→7日後フォロー |
| 注文処理 | 注文→決済→在庫→配送→完了 (各ステップ独立保証) |
| AIコンテンツ生成 | プロンプト→LLM→検証→承認→公開 |
| バッチデータ処理 | 大量データを並列処理 + 失敗した部分だけリトライ |
| 自律 AI エージェント | 複数ツール呼び出し→判断→次のアクションを繰り返す |

### 自分株式会社での活用可能性
- **Claude Schedule の代替/補完**: GHA cron → Temporal ワークフローに移行することで失敗時の自動リトライと状態管理が強化
- **AI大学コンテンツ**: 「AIエージェントを本番環境で動かすためのワークフロー設計」テーマで高い検索需要
- **競合分析**: Zapier/Make.com/n8n と Temporal の棲み分け (ノーコード vs エンジニア向けコードファースト)$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'temporal',
  'api',
  'Temporal.io API — Python/TypeScript SDK / Activity定義 / Supabase Edge Function連携 / AIエージェント統合',
  $$## Temporal.io API / 統合ガイド

### セットアップ
```bash
# Temporal サーバーをローカルで起動
brew install temporal  # macOS
temporal server start-dev  # 開発サーバー (localhost:7233)

# または Docker
docker run --network=host temporalio/auto-setup:latest

# Python SDK
pip install temporalio

# TypeScript SDK
npm install @temporalio/client @temporalio/worker @temporalio/workflow @temporalio/activity
```

### Python SDK 基本実装
```python
# activities.py — 実際の処理 (冪等性を保証)
import httpx
from temporalio import activity

@activity.defn
async def call_openai(prompt: str) -> str:
    """OpenAI API を呼び出す Activity (タイムアウト・リトライは Workflow が管理)"""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://api.openai.com/v1/chat/completions",
            headers={"Authorization": f"Bearer {OPENAI_API_KEY}"},
            json={
                "model": "gpt-4o-mini",
                "messages": [{"role": "user", "content": prompt}],
            },
        )
        return response.json()["choices"][0]["message"]["content"]

@activity.defn
async def save_to_supabase(user_id: str, content: str) -> None:
    """Supabase にデータを保存する Activity"""
    async with httpx.AsyncClient() as client:
        await client.post(
            f"{SUPABASE_URL}/rest/v1/ai_outputs",
            headers={
                "apikey": SUPABASE_KEY,
                "Authorization": f"Bearer {SUPABASE_KEY}",
                "Content-Type": "application/json",
            },
            json={"user_id": user_id, "content": content},
        )

# workflows.py — ビジネスロジック (決定論的コードのみ)
from datetime import timedelta
from temporalio import workflow
from temporalio.common import RetryPolicy
import activities

@workflow.defn
class AIContentGenerationWorkflow:
    @workflow.run
    async def run(self, user_id: str, prompt: str) -> str:
        # Step 1: AI コンテンツ生成 (失敗時5回まで自動リトライ)
        content = await workflow.execute_activity(
            activities.call_openai,
            prompt,
            start_to_close_timeout=timedelta(minutes=2),
            retry_policy=RetryPolicy(maximum_attempts=5),
        )

        # Step 2: Supabase に保存
        await workflow.execute_activity(
            activities.save_to_supabase,
            user_id,
            content,
            start_to_close_timeout=timedelta(seconds=30),
        )

        return content

# worker.py — Worker プロセス
import asyncio
from temporalio.client import Client
from temporalio.worker import Worker
import workflows, activities

async def main():
    client = await Client.connect("localhost:7233")
    worker = Worker(
        client,
        task_queue="ai-content-queue",
        workflows=[workflows.AIContentGenerationWorkflow],
        activities=[activities.call_openai, activities.save_to_supabase],
    )
    await worker.run()

asyncio.run(main())
```

### ワークフロー起動 (クライアント)
```python
# main.py — ワークフローを起動
import asyncio
from temporalio.client import Client
from workflows import AIContentGenerationWorkflow

async def trigger_workflow(user_id: str, prompt: str) -> str:
    client = await Client.connect("localhost:7233")

    # ワークフロー起動 (非同期)
    handle = await client.start_workflow(
        AIContentGenerationWorkflow.run,
        args=[user_id, prompt],
        id=f"ai-content-{user_id}-{int(time.time())}",
        task_queue="ai-content-queue",
    )

    # 完了まで待機
    result = await handle.result()
    return result
```

### TypeScript SDK
```typescript
// worker.ts
import { NativeConnection, Worker } from "@temporalio/worker";
import * as activities from "./activities";

const worker = await Worker.create({
  connection: await NativeConnection.connect({ address: "localhost:7233" }),
  taskQueue: "ai-tasks",
  workflowsPath: require.resolve("./workflows"),
  activities,
});
await worker.run();

// workflows.ts
import { proxyActivities } from "@temporalio/workflow";
import type * as activities from "./activities";

const { callOpenAI, saveToSupabase } = proxyActivities<typeof activities>({
  startToCloseTimeout: "2 minutes",
  retry: { maximumAttempts: 5 },
});

export async function aiWorkflow(userId: string, prompt: string): Promise<string> {
  const content = await callOpenAI(prompt);
  await saveToSupabase(userId, content);
  return content;
}
```

### Temporal Cloud (マネージドSaaS)
```bash
# Temporal Cloud への接続
# (本番環境では Temporal Cloud を使用してインフラを省略)
temporal server start --namespace=my-app.xxxxx.tmprl.cloud:7233 \
  --tls-cert-path=client.pem \
  --tls-key-path=client.key
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'temporal',
  'models',
  'Temporal.io 技術詳細 — Event Sourcing / Cadence後継 / AIエージェント設計パターン / GHA代替としての評価',
  $$## Temporal.io 技術詳細

### Event Sourcing アーキテクチャ

Temporal の耐久性実行の仕組みは **Event Sourcing** による:

```
[Temporal の状態管理]

Workflow 実行 = イベントの列として記録
  Event 1: WorkflowExecutionStarted (入力データ)
  Event 2: ActivityScheduled (call_openai)
  Event 3: ActivityStarted
  Event 4: ActivityCompleted (OpenAI の回答)
  Event 5: ActivityScheduled (save_to_supabase)
  ...
  Event N: WorkflowExecutionCompleted

→ サーバークラッシュ時: イベント列を再生してワークフローを復元
→ 重複実行防止: 同一ワークフローIDは1度しか実行されない
→ デバッグ: Web UI でイベント列を確認 (http://localhost:8080)
```

### Cadence (Uber) との関係

```
[歴史]
2017: Uber が内部で Cadence を開発
      → マイクロサービス間の長時間実行ワークフローを管理
      → Uber の配車ロジック / ドライバーオンボーディング等で使用

2019: Cadence の中心開発者2人が Uber を退職
      → Temporal Technologies を創業
      → Cadence を fork して Temporal として再設計

2020: Temporal OSS リリース
      Cadence との主な違い:
        ✅ gRPC (vs Thrift)
        ✅ 強化された SDK (Python/TypeScript 追加)
        ✅ Temporal Cloud (マネージドSaaS)
        ✅ アクティブなOSS開発 (Temporal主導)

現状:
  Temporal: アクティブ開発 / 商業サポート / Temporal Cloud
  Cadence:  Uber社内継続 / OSSも維持 / ゆっくりした開発
```

### AIエージェント設計パターン

```
[パターン1: Sequential Agent]
ユーザー入力
  → Step 1: 検索 (Activity)
  → Step 2: 要約 (Activity)
  → Step 3: 評価 (Activity)
  → Step 4: 出力 (Activity)
各ステップが失敗しても前のステップから再開

[パターン2: Parallel Agent (Fan-out/Fan-in)]
ユーザー入力
  → 並列実行: [検索A, 検索B, 検索C] (3つのActivity同時実行)
  → 全完了を待つ
  → 結果を統合して回答
→ Temporal の execute_activity を並列で呼ぶだけ

[パターン3: Human-in-the-Loop]
ユーザーが内容を入力
  → AIが下書きを生成
  → 人間が確認 (Temporal がウェイト / 最大24時間)
  → 承認 or 修正シグナルを受信
  → 公開処理を実行
→ Temporal の Signal/Query 機能を使用

[パターン4: Long-Running Research Agent]
リサーチ依頼を受信
  → サブエージェントA: Web検索 (複数回)
  → サブエージェントB: 文書要約 (並列)
  → サブエージェントC: 事実確認
  → 最終レポート生成
  → メール送信 (数時間後)
→ Temporal の Child Workflow で各サブエージェントを管理
```

### 競合比較

| 項目 | Temporal | GHA (cron) | Celery | Airflow | n8n |
|------|---------|-----------|--------|---------|-----|
| 耐久性 | ✅ 最強 | △ | △ | ✅ | △ |
| 長時間実行 | ✅ 無制限 | △ 6h上限 | △ | ✅ | △ |
| Human-in-Loop | ✅ Signal | ❌ | ❌ | ✅ | ✅ |
| AI統合 | ✅ 成長中 | △ | △ | △ | ✅ |
| デプロイ | 要サーバー | ✅ 不要 | 要Broker | 要DB | ✅ |
| 学習コスト | 高 | 低 | 中 | 高 | 低 |

### 自分株式会社との関連性

```
現在の自分株式会社の自動化基盤:
  GHA cron (cs-check / daily-report / ai-university-update)
  → 短時間タスクには最適 / 長時間AIエージェントには不向き

Temporal が有効なシナリオ:
  1. 複数AIエージェントが協調する長時間タスク
     例: 「競合21社を毎日自動調査 → 要約 → 人間が承認 → SNS投稿」
     → 各ステップが数分〜数時間かかっても安全に実行

  2. ユーザーオンボーディングフロー
     例: 登録 → メール → 3日後チュートリアル → 7日後フォロー
     → Temporal の Sleep (await workflow.sleep(timedelta(days=3)))

  3. バッチAI処理
     例: 全ユーザーの週次レポートをAI生成 → 失敗したユーザーのみリトライ

AI大学コンテンツとしての価値:
  「AIエージェントを本番環境に持ち込む時に必要なもの」
  「Temporal で耐障害性のある AI パイプラインを構築する方法」
  → 企業エンジニア向けの高度なコンテンツ / SEO価値高
```$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 245→246社化: Temporal.io 追加',
  'PS#3 S75。Temporal.io (耐久性ワークフローエンジン/Uber Cadence後継/AIエージェントオーケストレーション/Durable Execution/Event Sourcing/Human-in-Loop/Uber+Airbnb+Netflix採用/Python+TypeScript+Go SDK/$120M調達/8/9) を ai_university_content に追加。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
