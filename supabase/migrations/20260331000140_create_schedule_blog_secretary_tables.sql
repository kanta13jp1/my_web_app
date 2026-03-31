-- No-op compatibility migration.
-- The schedule/blog/secretary tables in the original draft were already created
-- by earlier migrations:
--   20260304000000_create_agent_org_tables.sql
--   20260326000018_create_blog_posts.sql
--   20260327000001_create_schedule_task_runs.sql
--   20260328000008_create_edge_function_ui_status.sql
--
-- Keeping this migration as a no-op preserves migration history without trying
-- to recreate incompatible tables, indexes, or policies.

DO $$
BEGIN
  RAISE NOTICE 'Skipping superseded schedule/blog/secretary compatibility migration';
END
$$;
