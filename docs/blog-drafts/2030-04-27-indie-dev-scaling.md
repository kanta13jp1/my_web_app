---
title: "インディー開発者のスケーリング戦略 — 1人で10万ユーザーを支える設計と運用"
tags: 個人開発,flutter,supabase,AI
published: true
---

# インディー開発者のスケーリング戦略 — 1人で10万ユーザーを支える設計と運用

「作れたけど、成長したら壊れる」— これがインディー開発者の最大の恐怖です。1人のエンジニアが10万ユーザーを捌くには、最初から「スケール前提の手抜き」が必要です。

## フェーズ別スケーリング戦略

### フェーズ1: 0〜1,000ユーザー (プロダクト検証期)

この段階でスケーラビリティを心配するのは早計。スピードを優先:

```dart
// ❌ 過剰設計: 最初から CQRS + Event Sourcing
class TaskCommandHandler {
  final TaskCommandBus _bus;
  Future<void> handle(CreateTaskCommand cmd) async { ... }
}

// ✅ 最初はシンプルに
class TaskRepository {
  Future<void> createTask(String title) async {
    await supabase.from('tasks').insert({'title': title});
  }
}
```

**チェックリスト**:
- Supabase 無料枠 で十分 (500MB DB / 2GB 転送)
- Firebase Hosting 無料枠 で十分
- 監視は Supabase Dashboard + Firebase Console だけ

### フェーズ2: 1,000〜10,000ユーザー (PMF確認期)

ボトルネックが見え始める段階:

```sql
-- N+1 クエリを防ぐ: JOIN で一括取得
-- ❌ N+1 問題
SELECT * FROM tasks WHERE user_id = $1;
-- ループ内で
SELECT * FROM projects WHERE id = $task.project_id;

-- ✅ JOIN で解決
SELECT
  t.*,
  p.name AS project_name,
  p.color AS project_color
FROM tasks t
LEFT JOIN projects p ON t.project_id = p.id
WHERE t.user_id = $1
ORDER BY t.created_at DESC;
```

```sql
-- 適切なインデックスを追加
CREATE INDEX idx_tasks_user_created
ON tasks(user_id, created_at DESC);

CREATE INDEX idx_tasks_project
ON tasks(project_id) WHERE project_id IS NOT NULL;
```

### フェーズ3: 10,000〜100,000ユーザー (スケール期)

インフラの見直しが必要になる段階:

```typescript
// Edge Function でバックグラウンド処理
// supabase/functions/process-heavy-task/index.ts
Deno.serve(async (req) => {
  const { taskId } = await req.json();
  
  // Supabase の pg_background で非同期実行
  await supabase.rpc('process_task_async', { task_id: taskId });
  
  // レスポンスはすぐ返す (202 Accepted)
  return new Response(
    JSON.stringify({ status: 'processing', taskId }),
    { status: 202 }
  );
});
```

## データベース最適化

### コネクションプーリング

Supabase は pgBouncer を内蔵しているが、設定の理解が重要:

```
// .env
SUPABASE_DB_URL=postgresql://...?pgbouncer=true&connection_limit=1

// Edge Functions から接続する場合は connection_limit=1 必須
// サーバーレスの同時実行で接続が枯渇するのを防ぐ
```

### 読み取りレプリカの活用

```typescript
// supabase/functions/analytics-hub/index.ts
// 読み取り専用クエリはレプリカへ (Supabase Pro 以上)
const readOnlyClient = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  {
    db: { schema: 'public' },
    // read replica endpoint
    global: { headers: { 'x-read-replica': 'true' } },
  }
);
```

### パーティショニング

大量データのテーブルはパーティショニングで管理:

```sql
-- 月次パーティション例 (activity_logs)
CREATE TABLE activity_logs (
  id         UUID DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL,
  action     TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
) PARTITION BY RANGE (created_at);

CREATE TABLE activity_logs_2026_01
PARTITION OF activity_logs
FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

CREATE TABLE activity_logs_2026_02
PARTITION OF activity_logs
FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');

-- 古いパーティションを自動削除 (pg_partman 推奨)
```

## AI を活用したオートスケーリング監視

```typescript
// GHA schedule: 毎時インフラチェック
// .github/workflows/infra-health-check.yml
name: Infra Health Check
on:
  schedule:
    - cron: '0 * * * *'
  workflow_dispatch:

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - name: Check Supabase health
        run: |
          STATUS=$(curl -s "$SUPABASE_URL/health" | jq -r '.status')
          if [ "$STATUS" != "ok" ]; then
            echo "::error::Supabase health check failed: $STATUS"
            # Slack 通知や GitHub Issue 自動作成
          fi
```

## キャッシュ戦略

### Flutter クライアントサイドキャッシュ

```dart
class CachedTaskRepository {
  final Map<String, List<Task>> _cache = {};
  final Map<String, DateTime> _cacheTime = {};
  static const _ttl = Duration(minutes: 5);

  Future<List<Task>> getTasks(String userId) async {
    final key = 'tasks_$userId';
    final cached = _cache[key];
    final cacheAt = _cacheTime[key];

    if (cached != null &&
        cacheAt != null &&
        DateTime.now().difference(cacheAt) < _ttl) {
      return cached; // キャッシュヒット
    }

    // キャッシュミス: DB から取得
    final data = await supabase
        .from('tasks')
        .select()
        .order('created_at', ascending: false);

    _cache[key] = data.map(Task.fromJson).toList();
    _cacheTime[key] = DateTime.now();
    return _cache[key]!;
  }

  void invalidate(String userId) {
    _cache.remove('tasks_$userId');
    _cacheTime.remove('tasks_$userId');
  }
}
```

### Supabase サーバーサイドキャッシュ

```sql
-- マテリアライズドビューで集計クエリをキャッシュ
CREATE MATERIALIZED VIEW user_stats AS
SELECT
  user_id,
  COUNT(*) AS task_count,
  COUNT(*) FILTER (WHERE completed_at IS NOT NULL) AS completed_count,
  MAX(created_at) AS last_activity
FROM tasks
GROUP BY user_id;

-- インデックス
CREATE UNIQUE INDEX idx_user_stats_user_id ON user_stats(user_id);

-- 1時間ごとにリフレッシュ (GHA cron から呼び出し)
REFRESH MATERIALIZED VIEW CONCURRENTLY user_stats;
```

## コスト管理

### 段階的なプランアップグレード

```
フェーズ1 (〜1K ユーザー): Supabase Free + Firebase Free
  → 月0円

フェーズ2 (〜10K ユーザー): Supabase Pro ($25/月) + Firebase Spark
  → 月約3,500円

フェーズ3 (〜100K ユーザー): Supabase Pro + Add-ons + Firebase Blaze
  → 月約15,000〜50,000円 (使用量次第)

フェーズ4 (100K+ ユーザー): Supabase Team ($599/月~) + 専用インフラ
  → 月100,000円〜
```

### コスト警告アラート設定

```bash
# Firebase Budget Alert (GCP Console で設定)
# 月予算: $50
# アラート閾値: 50%, 90%, 100%

# Supabase Usage Alert (Dashboard → Settings → Billing)
# DB サイズ: 80% で通知
# API リクエスト: 80% で通知
```

## まとめ: 1人スケーリングの鉄則

```
✅ 最初はシンプルに作り、ボトルネックが現れてから最適化する
✅ N+1 クエリだけは最初から防ぐ (JOIN とインデックス)
✅ キャッシュはクライアント + サーバー両側で
✅ AI (GHA + Claude) に監視を任せて人間はプロダクト開発に集中
✅ コストは段階的に増やす (過剰投資しない)
✅ マネタイズより先にスケールアップしない
```

1人で10万ユーザーは現実的な目標です。正しい設計とAI補助の運用で、チームなしに達成できます。

---

*自分株式会社では Flutter + Supabase + GHA でスケーラブルなAIライフマネジメントアプリを1人で開発・運用中 → [@kanta13jp1](https://x.com/kanta13jp1)*
