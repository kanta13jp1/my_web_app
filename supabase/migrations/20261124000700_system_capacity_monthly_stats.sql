-- Monthly system usage statistics & capacity report table, aggregation RPC,
-- strict admin-only RLS, and pg_cron monthly schedule (#2745).

CREATE TABLE IF NOT EXISTS public.system_capacity_monthly_stats (
  report_month text PRIMARY KEY CHECK (report_month ~ '^\d{4}-\d{2}$'),
  user_access_count integer NOT NULL DEFAULT 0 CHECK (user_access_count >= 0),
  batch_job_count integer NOT NULL DEFAULT 0 CHECK (batch_job_count >= 0),
  error_count integer NOT NULL DEFAULT 0 CHECK (error_count >= 0),
  error_rate_percent numeric(6, 2) NOT NULL DEFAULT 0
    CHECK (error_rate_percent >= 0 AND error_rate_percent <= 100),
  notified_at timestamptz,
  summary_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_system_capacity_monthly_stats_updated_at
  ON public.system_capacity_monthly_stats (updated_at DESC);

ALTER TABLE public.system_capacity_monthly_stats ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.system_capacity_monthly_stats FROM PUBLIC, anon;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.system_capacity_monthly_stats
  FROM anon, authenticated;
GRANT SELECT ON TABLE public.system_capacity_monthly_stats TO authenticated;
GRANT ALL ON TABLE public.system_capacity_monthly_stats TO service_role;

DROP POLICY IF EXISTS "admin_select_system_capacity_monthly_stats"
  ON public.system_capacity_monthly_stats;
CREATE POLICY "admin_select_system_capacity_monthly_stats"
  ON public.system_capacity_monthly_stats
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = (SELECT auth.uid())
        AND (up.is_admin = true OR up.role = 'admin')
    )
  );

DROP POLICY IF EXISTS "deny_client_insert"
  ON public.system_capacity_monthly_stats;
CREATE POLICY "deny_client_insert"
  ON public.system_capacity_monthly_stats
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (false);

DROP POLICY IF EXISTS "deny_client_update"
  ON public.system_capacity_monthly_stats;
CREATE POLICY "deny_client_update"
  ON public.system_capacity_monthly_stats
  FOR UPDATE
  TO anon, authenticated
  USING (false)
  WITH CHECK (false);

DROP POLICY IF EXISTS "deny_client_delete"
  ON public.system_capacity_monthly_stats;
CREATE POLICY "deny_client_delete"
  ON public.system_capacity_monthly_stats
  FOR DELETE
  TO anon, authenticated
  USING (false);

DROP POLICY IF EXISTS "service_role_all_system_capacity_monthly_stats"
  ON public.system_capacity_monthly_stats;
CREATE POLICY "service_role_all_system_capacity_monthly_stats"
  ON public.system_capacity_monthly_stats
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

COMMENT ON TABLE public.system_capacity_monthly_stats IS
  'Monthly system access, batch execution, error rate, and notification status (#2745).';

CREATE OR REPLACE FUNCTION public.aggregate_monthly_system_capacity(
  p_month text DEFAULT NULL
)
RETURNS public.system_capacity_monthly_stats
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_month text;
  v_start_date date;
  v_end_date date;
  v_start_ts timestamptz;
  v_end_ts timestamptz;
  v_landing_views integer := 0;
  v_conversions integer := 0;
  v_ai_requests integer := 0;
  v_ai_errors integer := 0;
  v_schedule_runs integer := 0;
  v_schedule_errors integer := 0;
  v_async_jobs integer := 0;
  v_async_errors integer := 0;
  v_ef_invocations integer := 0;
  v_ef_errors integer := 0;
  v_auto_error_reports integer := 0;
  v_user_access_count integer := 0;
  v_batch_job_count integer := 0;
  v_error_count integer := 0;
  v_total_operations integer := 0;
  v_error_rate_percent numeric(6, 2) := 0;
  v_summary jsonb;
  v_result public.system_capacity_monthly_stats;
BEGIN
  v_month := COALESCE(
    NULLIF(btrim(p_month), ''),
    to_char((timezone('Asia/Tokyo', now()))::date, 'YYYY-MM')
  );

  IF v_month !~ '^\d{4}-(0[1-9]|1[0-2])$' THEN
    RAISE EXCEPTION 'Invalid p_month format (%): expected YYYY-MM', v_month;
  END IF;

  v_start_date := to_date(v_month || '-01', 'YYYY-MM-DD');
  v_end_date := (v_start_date + interval '1 month')::date;
  v_start_ts := (v_start_date::timestamp AT TIME ZONE 'Asia/Tokyo');
  v_end_ts := (v_end_date::timestamp AT TIME ZONE 'Asia/Tokyo');

  IF to_regclass('public.app_analytics') IS NOT NULL THEN
    EXECUTE format(
      'SELECT COALESCE(SUM(landing_views), 0)::integer, COALESCE(SUM(conversions), 0)::integer
       FROM public.app_analytics
       WHERE date >= %L::date AND date < %L::date',
      v_start_date,
      v_end_date
    )
      INTO v_landing_views, v_conversions;
  END IF;

  IF to_regclass('public.ai_hub_chat_logs') IS NOT NULL THEN
    EXECUTE format(
      'SELECT COUNT(*)::integer, COUNT(*) FILTER (WHERE success = false)::integer
       FROM public.ai_hub_chat_logs
       WHERE created_at >= %L::timestamptz AND created_at < %L::timestamptz',
      v_start_ts,
      v_end_ts
    )
      INTO v_ai_requests, v_ai_errors;
  END IF;

  IF to_regclass('public.schedule_task_runs') IS NOT NULL THEN
    EXECUTE format(
      'SELECT COUNT(*)::integer, COUNT(*) FILTER (WHERE status = ''error'')::integer
       FROM public.schedule_task_runs
       WHERE started_at >= %L::timestamptz AND started_at < %L::timestamptz',
      v_start_ts,
      v_end_ts
    )
      INTO v_schedule_runs, v_schedule_errors;
  END IF;

  IF to_regclass('public.async_jobs') IS NOT NULL THEN
    EXECUTE format(
      'SELECT COUNT(*)::integer, COUNT(*) FILTER (WHERE status = ''failed'')::integer
       FROM public.async_jobs
       WHERE created_at >= %L::timestamptz AND created_at < %L::timestamptz',
      v_start_ts,
      v_end_ts
    )
      INTO v_async_jobs, v_async_errors;
  END IF;

  IF to_regclass('public.edge_function_runtime_invocations') IS NOT NULL THEN
    EXECUTE format(
      'SELECT COUNT(*)::integer, COUNT(*) FILTER (WHERE response_status >= 500)::integer
       FROM public.edge_function_runtime_invocations
       WHERE invoked_at >= %L::timestamptz AND invoked_at < %L::timestamptz',
      v_start_ts,
      v_end_ts
    )
      INTO v_ef_invocations, v_ef_errors;
  END IF;

  IF to_regclass('public.hub_data') IS NOT NULL THEN
    EXECUTE format(
      'SELECT COUNT(*)::integer
       FROM public.hub_data
       WHERE source = ''user_feedback''
         AND metadata->>''source'' = ''auto_error_report''
         AND created_at >= %L::timestamptz AND created_at < %L::timestamptz',
      v_start_ts,
      v_end_ts
    )
      INTO v_auto_error_reports;
  END IF;

  v_user_access_count := GREATEST(v_landing_views, 0) + GREATEST(v_ai_requests, 0);
  v_batch_job_count := GREATEST(v_schedule_runs, 0) + GREATEST(v_async_jobs, 0);
  v_error_count := GREATEST(v_schedule_errors, 0)
    + GREATEST(v_async_errors, 0)
    + GREATEST(v_ef_errors, 0)
    + GREATEST(v_ai_errors, 0)
    + GREATEST(v_auto_error_reports, 0);
  v_total_operations := v_user_access_count + v_batch_job_count + GREATEST(v_ef_invocations, 0);

  IF v_total_operations > 0 THEN
    v_error_rate_percent := LEAST(
      ROUND((v_error_count::numeric / v_total_operations::numeric) * 100.0, 2),
      100.00
    );
  ELSE
    v_error_rate_percent := 0.00;
  END IF;

  v_summary := jsonb_build_object(
    'report_month', v_month,
    'timezone', 'Asia/Tokyo',
    'landing_views', v_landing_views,
    'conversions', v_conversions,
    'ai_requests', v_ai_requests,
    'ai_errors', v_ai_errors,
    'schedule_runs', v_schedule_runs,
    'schedule_errors', v_schedule_errors,
    'async_jobs', v_async_jobs,
    'async_errors', v_async_errors,
    'ef_invocations', v_ef_invocations,
    'ef_errors', v_ef_errors,
    'auto_error_reports', v_auto_error_reports,
    'total_operations', v_total_operations,
    'aggregated_at', now()
  );

  INSERT INTO public.system_capacity_monthly_stats (
    report_month,
    user_access_count,
    batch_job_count,
    error_count,
    error_rate_percent,
    summary_payload,
    updated_at
  )
  VALUES (
    v_month,
    v_user_access_count,
    v_batch_job_count,
    v_error_count,
    v_error_rate_percent,
    v_summary,
    now()
  )
  ON CONFLICT (report_month) DO UPDATE
  SET
    user_access_count = EXCLUDED.user_access_count,
    batch_job_count = EXCLUDED.batch_job_count,
    error_count = EXCLUDED.error_count,
    error_rate_percent = EXCLUDED.error_rate_percent,
    summary_payload = EXCLUDED.summary_payload,
    updated_at = now()
  RETURNING * INTO v_result;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.aggregate_monthly_system_capacity(text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.aggregate_monthly_system_capacity(text)
  TO service_role;

COMMENT ON FUNCTION public.aggregate_monthly_system_capacity(text) IS
  'Aggregates monthly user access, batch jobs, errors, and error rate into system_capacity_monthly_stats (#2745).';

DO $$
DECLARE
  v_job_id bigint;
BEGIN
  BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_cron;
  EXCEPTION
    WHEN others THEN
      RAISE NOTICE 'pg_cron extension is not available in this environment.';
      RETURN;
  END;

  SELECT jobid INTO v_job_id
  FROM cron.job
  WHERE jobname = 'monthly_system_capacity_aggregate';

  IF v_job_id IS NOT NULL THEN
    PERFORM cron.unschedule(v_job_id);
  END IF;

  -- Run on the 1st of every month at 00:15 UTC (09:15 JST), aggregating the previous JST month.
  PERFORM cron.schedule(
    'monthly_system_capacity_aggregate',
    '15 0 1 * *',
    $cmd$SELECT public.aggregate_monthly_system_capacity(to_char((timezone('Asia/Tokyo', now()) - interval '1 day')::date, 'YYYY-MM'));$cmd$
  );
END $$;
