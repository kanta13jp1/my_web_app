-- Fix Supabase Security Advisor view errors (auth_users_exposed x3,
-- security_definer_view x15) and Performance Advisor duplicate_index x3.
-- Compliant with supabase-postgres-best-practices (PostgreSQL 15+ security_invoker,
-- InitPlan RLS wrapper, deterministic idempotent DDL).

-- ============================================================================
-- SECTION 1: SECURITY ERROR — auth_users_exposed (3 views)
-- ============================================================================

-- 1.1 public.user_stats_with_profiles
-- Remove `auth.users` join/email fallback and enforce caller RLS via security_invoker.
CREATE OR REPLACE VIEW public.user_stats_with_profiles
WITH (security_invoker = true) AS
SELECT
  us.user_id,
  us.total_points,
  us.current_level,
  us.notes_created,
  us.current_streak,
  us.longest_streak,
  us.categories_created,
  us.notes_shared,
  us.last_activity_date,
  us.created_at,
  us.updated_at,
  COALESCE(NULLIF(up.display_name, ''), 'User-' || LEFT(us.user_id::text, 8))::text AS user_name,
  up.avatar_url
FROM public.user_stats us
LEFT JOIN public.user_profiles up ON us.user_id = up.user_id;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.user_stats_with_profiles FROM anon, authenticated;
GRANT SELECT ON public.user_stats_with_profiles TO anon, authenticated;

COMMENT ON VIEW public.user_stats_with_profiles IS
  'Leaderboard view combining user_stats with user_profiles (security_invoker=true, no auth.users exposure).';

-- 1.2 public.user_follow_counts
-- Derive user IDs from public.user_profiles and public.user_follows without auth.users.
CREATE OR REPLACE VIEW public.user_follow_counts
WITH (security_invoker = true) AS
WITH known_users AS (
  SELECT user_id FROM public.user_profiles
  UNION
  SELECT following_id AS user_id FROM public.user_follows
  UNION
  SELECT follower_id AS user_id FROM public.user_follows
),
follower_counts AS (
  SELECT following_id, COUNT(*) AS count
  FROM public.user_follows
  GROUP BY following_id
),
following_counts AS (
  SELECT follower_id, COUNT(*) AS count
  FROM public.user_follows
  GROUP BY follower_id
)
SELECT
  u.user_id,
  COALESCE(fc.count, 0::bigint) AS followers_count,
  COALESCE(fgc.count, 0::bigint) AS following_count
FROM known_users u
LEFT JOIN follower_counts fc ON u.user_id = fc.following_id
LEFT JOIN following_counts fgc ON u.user_id = fgc.follower_id;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.user_follow_counts FROM anon, authenticated;
GRANT SELECT ON public.user_follow_counts TO anon, authenticated;

COMMENT ON VIEW public.user_follow_counts IS
  'Follower and following counts per user without auth.users exposure (security_invoker=true).';

-- 1.3 public.ai_university_leaderboard
-- Split ai_university_scores RLS so public leaderboard SELECT keeps working under
-- security_invoker = true while preserving owner-only writes with InitPlan wrapping.
DO $$
BEGIN
  IF to_regclass('public.ai_university_scores') IS NOT NULL THEN
    DROP POLICY IF EXISTS "users_own_scores" ON public.ai_university_scores;
    DROP POLICY IF EXISTS "ai_university_scores_public_select" ON public.ai_university_scores;
    DROP POLICY IF EXISTS "ai_university_scores_insert_own" ON public.ai_university_scores;
    DROP POLICY IF EXISTS "ai_university_scores_update_own" ON public.ai_university_scores;
    DROP POLICY IF EXISTS "ai_university_scores_delete_own" ON public.ai_university_scores;

    CREATE POLICY "ai_university_scores_public_select"
      ON public.ai_university_scores
      FOR SELECT
      TO anon, authenticated
      USING (true);

    CREATE POLICY "ai_university_scores_insert_own"
      ON public.ai_university_scores
      FOR INSERT
      TO authenticated
      WITH CHECK ((SELECT auth.uid()) = user_id);

    CREATE POLICY "ai_university_scores_update_own"
      ON public.ai_university_scores
      FOR UPDATE
      TO authenticated
      USING ((SELECT auth.uid()) = user_id)
      WITH CHECK ((SELECT auth.uid()) = user_id);

    CREATE POLICY "ai_university_scores_delete_own"
      ON public.ai_university_scores
      FOR DELETE
      TO authenticated
      USING ((SELECT auth.uid()) = user_id);
  END IF;
END
$$;

-- Preserve live column type varchar(255) on display_name to avoid SQLSTATE 42P16.
CREATE OR REPLACE VIEW public.ai_university_leaderboard
WITH (security_invoker = true) AS
SELECT
  s.user_id,
  COALESCE(NULLIF(up.display_name, ''), 'User-' || LEFT(s.user_id::text, 8))::varchar(255) AS display_name,
  COUNT(*) FILTER (WHERE s.quiz_correct)::integer AS total_correct,
  COUNT(DISTINCT s.provider_id) AS providers_studied,
  MAX(s.studied_at) AS last_studied_at,
  RANK() OVER (ORDER BY COUNT(*) FILTER (WHERE s.quiz_correct) DESC) AS rank
FROM public.ai_university_scores s
LEFT JOIN public.user_profiles up ON up.user_id = s.user_id
GROUP BY s.user_id, up.display_name
ORDER BY total_correct DESC;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.ai_university_leaderboard FROM anon, authenticated;
GRANT SELECT ON public.ai_university_leaderboard TO anon, authenticated;

COMMENT ON VIEW public.ai_university_leaderboard IS
  'AI University leaderboard combining ai_university_scores with user_profiles (security_invoker=true, no auth.users exposure).';

-- ============================================================================
-- SECTION 2: SECURITY ERROR — security_definer_view (remaining 15 views)
-- ============================================================================

ALTER VIEW IF EXISTS public.note_like_counts SET (security_invoker = true);
ALTER VIEW IF EXISTS public.abstinence_weekly_pattern SET (security_invoker = true);
ALTER VIEW IF EXISTS public.wasteful_spending_monthly_summary SET (security_invoker = true);
ALTER VIEW IF EXISTS public.horse_accuracy_stats SET (security_invoker = true);
ALTER VIEW IF EXISTS public.provider_health_view SET (security_invoker = true);
ALTER VIEW IF EXISTS public.provider_heatmap_view SET (security_invoker = true);
ALTER VIEW IF EXISTS public.session_trace_view SET (security_invoker = true);
ALTER VIEW IF EXISTS public.wbs_milestone_risk_view SET (security_invoker = true);
ALTER VIEW IF EXISTS public.wbs_delayed_tasks_view SET (security_invoker = true);
ALTER VIEW IF EXISTS public.wbs_project_overview_view SET (security_invoker = true);
ALTER VIEW IF EXISTS public.horse_provider_leaderboard SET (security_invoker = true);
ALTER VIEW IF EXISTS public.horse_bet_type_accuracy SET (security_invoker = true);
ALTER VIEW IF EXISTS public.horse_bet_type_provider_accuracy SET (security_invoker = true);
ALTER VIEW IF EXISTS public.horse_learning_daily_accuracy SET (security_invoker = true);
ALTER VIEW IF EXISTS public.horse_learning_backfill_status SET (security_invoker = true);

-- ============================================================================
-- SECTION 3: PERFORMANCE WARN — duplicate_index (3 redundant index pairs)
-- ============================================================================

DROP INDEX IF EXISTS public.abstinence_slips_user_slipped_idx;
DROP INDEX IF EXISTS public.categories_user_id_idx;
DROP INDEX IF EXISTS public.wealth_struggles_user_occurred_at_idx;
