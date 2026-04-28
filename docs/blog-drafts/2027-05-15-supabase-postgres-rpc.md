---
title: "Supabase Postgres 関数・RPC — Edge Function を減らす最強パターン"
tags: supabase,postgresql,個人開発,AI
published: true
---

# Supabase Postgres 関数・RPC — Edge Function を減らす最強パターン

Edge Function の数が増えると管理コストが上がる。Postgres 関数 (RPC) を使えば、DB 側で完結できるロジックが多くある。実際に Edge Function を削減した例を紹介する。

## Postgres 関数とは

```sql
-- 基本構文
CREATE OR REPLACE FUNCTION function_name(param1 type1, param2 type2)
RETURNS return_type
LANGUAGE plpgsql
SECURITY DEFINER  -- RLS を bypass して実行
AS $$
BEGIN
  -- ロジック
  RETURN result;
END;
$$;
```

Flutter から呼ぶ:

```dart
final result = await supabase.rpc('function_name', params: {
  'param1': value1,
  'param2': value2,
});
```

**SECURITY DEFINER**: 関数の所有者権限で実行 → RLS を bypass できる。管理操作に使う。
**SECURITY INVOKER** (デフォルト): 呼び出し元のユーザー権限 → RLS が適用される。

## パターン1: 集計クエリを RPC に移す

Before (Flutter 側でフィルタ):

```dart
// Flutter: 全件取得 → クライアントで集計
final data = await supabase.from('development_achievements').select('*');
final total = data.length;
final thisWeek = data.where((e) => isThisWeek(e['completed_at'])).length;
```

After (DB 側で集計):

```sql
CREATE OR REPLACE FUNCTION get_achievement_stats()
RETURNS json
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  result json;
BEGIN
  SELECT json_build_object(
    'total', COUNT(*),
    'this_week', COUNT(*) FILTER (WHERE completed_at >= NOW() - INTERVAL '7 days'),
    'this_month', COUNT(*) FILTER (WHERE completed_at >= NOW() - INTERVAL '30 days')
  ) INTO result
  FROM development_achievements
  WHERE user_id = auth.uid();

  RETURN result;
END;
$$;
```

```dart
final stats = await supabase.rpc('get_achievement_stats');
```

ネットワーク転送量: 全件 → 1 JSON オブジェクト。

## パターン2: トランザクションが必要な処理

```sql
-- 複数テーブルをアトミックに更新
CREATE OR REPLACE FUNCTION transfer_points(
  from_user uuid,
  to_user uuid,
  amount int
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- トランザクション内で2テーブルを更新
  UPDATE user_points SET points = points - amount WHERE user_id = from_user;
  UPDATE user_points SET points = points + amount WHERE user_id = to_user;

  -- 履歴を記録
  INSERT INTO point_transfers (from_user, to_user, amount, transferred_at)
  VALUES (from_user, to_user, amount, NOW());
END;
$$;
```

Edge Function でトランザクションを実現しようとすると複雑になる。DB 関数なら1ステップ。

## パターン3: 複雑な JOIN を隠蔽

```sql
CREATE OR REPLACE FUNCTION get_user_dashboard(target_user_id uuid DEFAULT auth.uid())
RETURNS json
LANGUAGE sql
SECURITY INVOKER
AS $$
  SELECT json_build_object(
    'profile', (SELECT row_to_json(p) FROM profiles p WHERE p.id = target_user_id),
    'recent_achievements', (
      SELECT json_agg(a ORDER BY a.completed_at DESC)
      FROM (SELECT * FROM development_achievements
            WHERE user_id = target_user_id
            ORDER BY completed_at DESC LIMIT 5) a
    ),
    'stats', (
      SELECT json_build_object(
        'total_achievements', COUNT(*),
        'streak_days', MAX(streak_days)
      )
      FROM development_achievements
      WHERE user_id = target_user_id
    )
  );
$$;
```

Flutter 側: `supabase.rpc('get_user_dashboard')` の1行で完結。

## Edge Function が必要なケース vs RPC で十分なケース

```
RPC で十分:
  ✅ 集計・統計クエリ
  ✅ 複数テーブルのトランザクション
  ✅ 複雑な JOIN を隠蔽
  ✅ RLS を bypass した管理操作

Edge Function が必要:
  ✅ 外部 API 呼び出し (Resend / Anthropic / Stripe)
  ✅ Cron タスク (schedule-hub)
  ✅ Webhook 受信処理
  ✅ 重い計算処理 (Deno Worker)
```

## 実際の削減効果

うちのプロジェクトで RPC に移行した結果:

```
Before: Edge Function 45本
After:  Edge Function 28本 (-38%)

集計系 EF 8本 → RPC
トランザクション系 EF 5本 → RPC
JOIN 複合系 EF 4本 → RPC
```

EF 管理コスト (deploy 時間・Deno 依存・コールドスタート) が削減された。

## まとめ

Supabase では「DB でできることは DB で」が原則。RPC は SQL で書けて、Supabase クライアントから1行で呼べる。EF を作る前に「これ Postgres 関数で書けないか」を確認する習慣をつける。
