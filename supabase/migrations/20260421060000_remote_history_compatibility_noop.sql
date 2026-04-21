-- Compatibility no-op for production migration history.
--
-- A previous deploy recorded version 20260421060000 in Supabase's remote
-- schema_migrations table, but the local file was later superseded by
-- 20260421062000_wbs_web_performance_startup_optimization.sql before it was
-- committed to main. Supabase CLI refuses db push when a remote version is
-- missing locally, so keep this no-op to preserve history alignment.
--
-- Fresh databases should run the actual WBS update in 20260421062000.

SELECT 1;
