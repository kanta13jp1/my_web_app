---
title: "Supabase pg_cron 完全ガイド — PostgreSQL でスケジュールジョブを自動化する"
tags: supabase,postgresql,個人開発,AI
published: true
---

# Supabase pg_cron 完全ガイド — PostgreSQL でスケジュールジョブを自動化する

Supabase は pg_cron 拡張を標準サポートしており、PostgreSQL の中でスケジュールジョブを実行できます。Edge Function を外部トリガーする必要なく、DB 内で定期処理を完結させられます。

## pg_cron とは

PostgreSQL の拡張機能で、cron 形式のスケジュールでSQL/関数を定期実行。

**メリット**:
- DB 内で完結 → 外部インフラ不要
- PostgreSQL の全機能が使える
- トランザクション安全
- Supabase ダッシュボードから設定可能

## 有効化

Supabase ダッシュボード → Database → Extensions → `pg_cron` を有効化:

```sql
-- または SQL エディターから直接有効化
CREATE EXTENSION IF NOT EXISTS pg_cron;
```

## 基本的な使い方

```sql
-- 毎分実行
SELECT cron.schedule('every-minute-job', '* * * * *', $$
  UPDATE counters SET value = value + 1 WHERE name = 'tick';
$$);

-- 毎日深夜0時 (UTC) に実行
SELECT cron.schedule('daily-cleanup', '0 0 * * *', $$
  DELETE FROM temp_data WHERE created_at < NOW() - INTERVAL '24 hours';
$$);

-- 毎週月曜 9:00 UTC に実行
SELECT cron.schedule('weekly-report', '0 9 * * 1', $$
  INSERT INTO weekly_reports (week_start, total_users)
  SELECT DATE_TRUNC('week', NOW()), COUNT(*) FROM users WHERE is_active = TRUE;
$$);

-- 登録済みジョブ一覧
SELECT * FROM cron.job;

-- ジョブ削除
SELECT cron.unschedule('daily-cleanup');
```

## cron 構文

```
┌───────── 分 (0-59)
│ ┌───────── 時 (0-23)
│ │ ┌───────── 日 (1-31)
│ │ │ ┌───────── 月 (1-12)
│ │ │ │ ┌───────── 曜日 (0=日, 1=月 ... 7=日)
│ │ │ │ │
* * * * *

例:
0 9 * * 1-5   → 平日 9:00 UTC
*/15 * * * *  → 15分ごと
0 0 1 * *     → 毎月1日 深夜
```

## 実践例: 古いセッションのクリーンアップ

```sql
-- 30日以上経過したセッションを削除
SELECT cron.schedule(
  'cleanup-old-sessions',
  '0 2 * * *',  -- 毎日 2:00 UTC
  $$
    DELETE FROM user_sessions
    WHERE last_active < NOW() - INTERVAL '30 days';
  $$
);
```

## 実践例: 日次レポート生成

```sql
-- 前日の統計を集計してレポートテーブルに保存
CREATE OR REPLACE FUNCTION generate_daily_report()
RETURNS void AS $$
DECLARE
  report_date DATE := CURRENT_DATE - 1;
BEGIN
  INSERT INTO daily_reports (report_date, new_users, active_users, total_events)
  SELECT
    report_date,
    COUNT(*) FILTER (WHERE DATE(created_at) = report_date) AS new_users,
    COUNT(DISTINCT user_id) FILTER (
      WHERE DATE(last_active) = report_date
    ) AS active_users,
    (
      SELECT COUNT(*) FROM events
      WHERE DATE(created_at) = report_date
    ) AS total_events
  FROM users;

  RAISE LOG 'Daily report generated for %', report_date;
END;
$$ LANGUAGE plpgsql;

-- 毎日 1:00 UTC に実行
SELECT cron.schedule(
  'generate-daily-report',
  '0 1 * * *',
  'SELECT generate_daily_report()'
);
```

## 実践例: Edge Function を HTTP で呼び出す

```sql
-- pg_net 拡張と組み合わせて Edge Function をトリガー
SELECT cron.schedule(
  'trigger-weekly-digest',
  '0 9 * * 1',  -- 毎週月曜 9:00 UTC
  $$
    SELECT net.http_post(
      url := 'https://<project>.supabase.co/functions/v1/growth-weekly-digest',
      headers := '{"Authorization": "Bearer <anon_key>", "Content-Type": "application/json"}'::jsonb,
      body := '{"trigger": "pg_cron"}'::jsonb
    );
  $$
);
```

## 実行ログの確認

```sql
-- 直近10件の実行履歴
SELECT
  jobname,
  runid,
  job_pid,
  database,
  username,
  command,
  status,
  return_message,
  start_time,
  end_time
FROM cron.job_run_details
ORDER BY start_time DESC
LIMIT 10;

-- 失敗したジョブのみ
SELECT jobname, status, return_message, start_time
FROM cron.job_run_details
WHERE status = 'failed'
ORDER BY start_time DESC;
```

## JST (日本標準時) での運用

pg_cron は UTC で動作する。JST = UTC+9 のため:

```sql
-- JST 9:00 = UTC 0:00
SELECT cron.schedule('morning-job-jst', '0 0 * * *', $$
  -- JST 9:00 に実行したい処理
  SELECT generate_morning_report();
$$);

-- JST 17:00 = UTC 8:00
SELECT cron.schedule('evening-job-jst', '0 8 * * *', $$
  SELECT generate_evening_summary();
$$);
```

## まとめ

pg_cron で:

- **DB 内完結**の定期処理 → 外部スケジューラー不要
- **cron 構文**で柔軟なスケジュール設定
- **pg_net 連携**で Edge Function のトリガーも可能
- **実行ログ**でジョブの健全性を監視

Supabase のインフラをフル活用した自動化を実現できます。

---

自分株式会社では Flutter × Supabase でAIライフマネジメントアプリを開発中。個人開発の知見を毎週発信しています。
