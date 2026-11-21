-- ホーム初期ロード周辺テーブルの複合インデックス補強 & RLS InitPlan 最適化
-- supabase-postgres-best-practices 準拠 (query-composite-indexes / security-rls-performance)

DO $$
BEGIN
  IF to_regclass('public.someday_tasks') IS NOT NULL THEN
    CREATE INDEX IF NOT EXISTS idx_someday_tasks_user_is_completed
      ON public.someday_tasks (user_id, is_completed);
    CREATE INDEX IF NOT EXISTS idx_someday_tasks_user_created_at_desc
      ON public.someday_tasks (user_id, created_at DESC);
  END IF;

  IF to_regclass('public.cfo_assets') IS NOT NULL THEN
    CREATE INDEX IF NOT EXISTS idx_cfo_assets_user_created_at
      ON public.cfo_assets (user_id, created_at);
  END IF;

  IF to_regclass('public.user_pinned_features') IS NOT NULL THEN
    CREATE INDEX IF NOT EXISTS idx_user_pinned_features_user_sort_order
      ON public.user_pinned_features (user_id, sort_order);

    DROP POLICY IF EXISTS "users can manage own pinned features"
      ON public.user_pinned_features;
    CREATE POLICY "users can manage own pinned features"
      ON public.user_pinned_features
      FOR ALL
      USING ((SELECT auth.uid()) = user_id)
      WITH CHECK ((SELECT auth.uid()) = user_id);
  END IF;

  IF to_regclass('public.user_feature_usage') IS NOT NULL THEN
    DROP POLICY IF EXISTS "users can manage own feature usage"
      ON public.user_feature_usage;
    CREATE POLICY "users can manage own feature usage"
      ON public.user_feature_usage
      FOR ALL
      USING ((SELECT auth.uid()) = user_id)
      WITH CHECK ((SELECT auth.uid()) = user_id);
  END IF;

  IF to_regclass('public.feature_releases') IS NOT NULL
     AND to_regclass('public.user_profiles') IS NOT NULL THEN
    DROP POLICY IF EXISTS "admins can manage feature releases"
      ON public.feature_releases;
    DROP POLICY IF EXISTS "admins can insert feature releases"
      ON public.feature_releases;
    CREATE POLICY "admins can insert feature releases"
      ON public.feature_releases
      FOR INSERT
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM public.user_profiles
          WHERE id = (SELECT auth.uid()) AND is_admin = true
        )
      );

    DROP POLICY IF EXISTS "admins can update feature releases"
      ON public.feature_releases;
    CREATE POLICY "admins can update feature releases"
      ON public.feature_releases
      FOR UPDATE
      USING (
        EXISTS (
          SELECT 1 FROM public.user_profiles
          WHERE id = (SELECT auth.uid()) AND is_admin = true
        )
      )
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM public.user_profiles
          WHERE id = (SELECT auth.uid()) AND is_admin = true
        )
      );

    DROP POLICY IF EXISTS "admins can delete feature releases"
      ON public.feature_releases;
    CREATE POLICY "admins can delete feature releases"
      ON public.feature_releases
      FOR DELETE
      USING (
        EXISTS (
          SELECT 1 FROM public.user_profiles
          WHERE id = (SELECT auth.uid()) AND is_admin = true
        )
      );
  END IF;

  IF to_regclass('public.feature_strategy_daily_snapshots') IS NOT NULL THEN
    DROP POLICY IF EXISTS feature_strategy_daily_snapshots_select_own
      ON public.feature_strategy_daily_snapshots;
    CREATE POLICY feature_strategy_daily_snapshots_select_own
      ON public.feature_strategy_daily_snapshots
      FOR SELECT
      TO authenticated
      USING ((SELECT auth.uid()) = user_id);

    DROP POLICY IF EXISTS feature_strategy_daily_snapshots_insert_own
      ON public.feature_strategy_daily_snapshots;
    CREATE POLICY feature_strategy_daily_snapshots_insert_own
      ON public.feature_strategy_daily_snapshots
      FOR INSERT
      TO authenticated
      WITH CHECK ((SELECT auth.uid()) = user_id);

    DROP POLICY IF EXISTS feature_strategy_daily_snapshots_update_own
      ON public.feature_strategy_daily_snapshots;
    CREATE POLICY feature_strategy_daily_snapshots_update_own
      ON public.feature_strategy_daily_snapshots
      FOR UPDATE
      TO authenticated
      USING ((SELECT auth.uid()) = user_id)
      WITH CHECK ((SELECT auth.uid()) = user_id);

    DROP POLICY IF EXISTS feature_strategy_daily_snapshots_delete_own
      ON public.feature_strategy_daily_snapshots;
    CREATE POLICY feature_strategy_daily_snapshots_delete_own
      ON public.feature_strategy_daily_snapshots
      FOR DELETE
      TO authenticated
      USING ((SELECT auth.uid()) = user_id);
  END IF;

  IF to_regclass('public.feature_strategy_focus_actions') IS NOT NULL THEN
    DROP POLICY IF EXISTS feature_strategy_focus_actions_select_own
      ON public.feature_strategy_focus_actions;
    CREATE POLICY feature_strategy_focus_actions_select_own
      ON public.feature_strategy_focus_actions
      FOR SELECT
      TO authenticated
      USING ((SELECT auth.uid()) = user_id);

    DROP POLICY IF EXISTS feature_strategy_focus_actions_insert_own
      ON public.feature_strategy_focus_actions;
    CREATE POLICY feature_strategy_focus_actions_insert_own
      ON public.feature_strategy_focus_actions
      FOR INSERT
      TO authenticated
      WITH CHECK ((SELECT auth.uid()) = user_id);

    DROP POLICY IF EXISTS feature_strategy_focus_actions_update_own
      ON public.feature_strategy_focus_actions;
    CREATE POLICY feature_strategy_focus_actions_update_own
      ON public.feature_strategy_focus_actions
      FOR UPDATE
      TO authenticated
      USING ((SELECT auth.uid()) = user_id)
      WITH CHECK ((SELECT auth.uid()) = user_id);

    DROP POLICY IF EXISTS feature_strategy_focus_actions_delete_own
      ON public.feature_strategy_focus_actions;
    CREATE POLICY feature_strategy_focus_actions_delete_own
      ON public.feature_strategy_focus_actions
      FOR DELETE
      TO authenticated
      USING ((SELECT auth.uid()) = user_id);
  END IF;
END
$$;
