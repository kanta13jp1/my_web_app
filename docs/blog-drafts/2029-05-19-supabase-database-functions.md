---
title: "Supabase Database Functions 完全ガイド — RPC・PL/pgSQL でサーバーレスロジックを実装する"
tags: flutter,supabase,個人開発,AI
published: true
---

# Supabase Database Functions 完全ガイド — RPC・PL/pgSQL でサーバーレスロジックを実装する

Supabase の Database Functions (PostgreSQL 関数) を使うと、複雑なビジネスロジックをデータベース側に移動し、Edge Function を書かずにサーバーレスで実行できます。Flutter クライアントから `rpc()` で呼び出せます。

## なぜ Database Functions を使うか

- **原子性**: 複数テーブルの更新をトランザクションで一括実行
- **パフォーマンス**: ネットワーク往復を減らしてレイテンシを削減
- **セキュリティ**: RLS をバイパスせずにロジックをカプセル化
- **シンプルさ**: Edge Function の Deno デプロイが不要

## 基本的な関数の作成

```sql
-- シンプルな計算関数
CREATE OR REPLACE FUNCTION calculate_streak(user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  streak_count INTEGER := 0;
  check_date DATE := CURRENT_DATE;
  has_entry BOOLEAN;
BEGIN
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM journal_entries
      WHERE user_id = $1
        AND DATE(created_at) = check_date
    ) INTO has_entry;

    EXIT WHEN NOT has_entry;
    streak_count := streak_count + 1;
    check_date := check_date - INTERVAL '1 day';
  END LOOP;

  RETURN streak_count;
END;
$$;
```

## Flutter から RPC 呼び出し

```dart
final result = await supabase
    .rpc('calculate_streak', params: {'user_id': userId});
final streak = result as int;
```

## テーブルを返す関数

```sql
CREATE OR REPLACE FUNCTION get_leaderboard(limit_count INT DEFAULT 10)
RETURNS TABLE (
  user_id UUID,
  display_name TEXT,
  total_points INTEGER,
  rank BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.id,
    u.display_name,
    COALESCE(SUM(p.points), 0)::INTEGER AS total_points,
    ROW_NUMBER() OVER (ORDER BY SUM(p.points) DESC) AS rank
  FROM auth.users u
  LEFT JOIN points p ON p.user_id = u.id
  GROUP BY u.id, u.display_name
  ORDER BY total_points DESC
  LIMIT limit_count;
END;
$$;
```

```dart
final leaderboard = await supabase
    .rpc('get_leaderboard', params: {'limit_count': 20});
```

## トランザクション関数 — 複数テーブル更新

```sql
CREATE OR REPLACE FUNCTION complete_task(
  p_task_id UUID,
  p_user_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  task_points INTEGER;
  new_total INTEGER;
BEGIN
  -- タスク完了マーク
  UPDATE tasks
  SET completed_at = NOW(), is_completed = TRUE
  WHERE id = p_task_id AND user_id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'task_not_found';
  END IF;

  -- ポイント取得
  SELECT points INTO task_points FROM tasks WHERE id = p_task_id;

  -- ポイント加算
  INSERT INTO user_points (user_id, points, source_id, source_type)
  VALUES (p_user_id, task_points, p_task_id, 'task');

  -- 合計取得
  SELECT COALESCE(SUM(points), 0) INTO new_total
  FROM user_points WHERE user_id = p_user_id;

  RETURN json_build_object(
    'success', true,
    'points_earned', task_points,
    'total_points', new_total
  );
END;
$$;
```

## RLS との組み合わせ

```sql
-- SECURITY DEFINER = 関数の所有者権限で実行 (RLS バイパス可)
-- SECURITY INVOKER = 呼び出し元の権限で実行 (RLS 適用)

-- RLS を保ちながら集計だけ特権で行う例
CREATE OR REPLACE FUNCTION get_public_stats()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER  -- 統計は全ユーザーデータが必要
SET search_path = public
AS $$
BEGIN
  RETURN (
    SELECT json_build_object(
      'total_users', COUNT(DISTINCT user_id),
      'total_entries', COUNT(*)
    )
    FROM journal_entries
  );
END;
$$;
```

## 自分株式会社での活用例

- `calculate_streak(user_id)` — 連続記録日数のリアルタイム計算
- `get_dashboard_summary(user_id)` — ホーム画面の KPI を 1 RPC で集約
- `award_achievement(user_id, achievement_id)` — 重複防止付き実績付与

Edge Function でやっていた処理を Database Function に移すと、レイテンシが平均 40% 削減できました。

---

Supabase の RPC を使ってみたことがありますか？ Edge Function との使い分けをコメントで聞かせてください！
