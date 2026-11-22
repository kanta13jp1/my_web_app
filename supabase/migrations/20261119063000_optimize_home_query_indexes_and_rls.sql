-- ホーム画面主要テーブルの複合インデックス追加と RLS InitPlan 最適化
-- supabase-postgres-best-practices 準拠 (query-composite-indexes / security-rls-performance)

DO $$
BEGIN
  IF to_regclass('public.daily_todos') IS NOT NULL THEN
    CREATE INDEX IF NOT EXISTS idx_daily_todos_user_task_date_order
      ON public.daily_todos (user_id, task_date, order_index);

    CREATE INDEX IF NOT EXISTS idx_daily_todos_user_completed_at_desc
      ON public.daily_todos (user_id, completed_at DESC)
      WHERE completed_at IS NOT NULL;
  END IF;

  IF to_regclass('public.mindless_tasks') IS NOT NULL THEN
    CREATE INDEX IF NOT EXISTS idx_mindless_tasks_user_task_date_slot
      ON public.mindless_tasks (user_id, task_date, hour_slot);
  END IF;

  IF to_regclass('public.wealth_struggles') IS NOT NULL THEN
    CREATE INDEX IF NOT EXISTS idx_wealth_struggles_user_occurred_at
      ON public.wealth_struggles (user_id, occurred_at);
  END IF;

  IF to_regclass('public.home_daily_status') IS NOT NULL THEN
    DROP POLICY IF EXISTS "Users manage own home_daily_status"
      ON public.home_daily_status;
    CREATE POLICY "Users manage own home_daily_status"
      ON public.home_daily_status
      FOR ALL
      TO authenticated
      USING ((SELECT auth.uid()) = user_id)
      WITH CHECK ((SELECT auth.uid()) = user_id);
  END IF;
END
$$;
