-- Batch 63 (#2640): LLMを利用した週次パフォーマンスレポートの自動生成・配信システム
-- GitHub Actions の週次 schedule ワークフローから呼び出され、直近7日間の個人利用実績・
-- 異常検知・PII匿名化済みLLM要約・XSS対策済みHTMLレポートをユーザー境界付きで保全する。
-- 平文トークンや service_role キーを DB pg_cron / net.http_post へ埋め込まない設計とする。

CREATE TABLE IF NOT EXISTS public.weekly_performance_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  period_start date NOT NULL,
  period_end date NOT NULL CHECK (period_end >= period_start),
  metrics_summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  anomalies jsonb NOT NULL DEFAULT '[]'::jsonb,
  insight_markdown text NOT NULL DEFAULT '',
  rendered_html text NOT NULL DEFAULT '',
  delivery_status text NOT NULL DEFAULT 'draft' CHECK (
    delivery_status IN ('draft', 'dry_run', 'sent', 'failed')
  ),
  pii_redacted boolean NOT NULL DEFAULT true CHECK (pii_redacted = true),
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_weekly_performance_reports_user_period
  ON public.weekly_performance_reports (user_id, period_end DESC, period_start DESC);

ALTER TABLE public.weekly_performance_reports ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.weekly_performance_reports FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE public.weekly_performance_reports
  TO authenticated;
GRANT ALL ON TABLE public.weekly_performance_reports TO service_role;

DROP POLICY IF EXISTS weekly_performance_reports_owner_select
  ON public.weekly_performance_reports;
CREATE POLICY weekly_performance_reports_owner_select
  ON public.weekly_performance_reports
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS weekly_performance_reports_owner_insert
  ON public.weekly_performance_reports;
CREATE POLICY weekly_performance_reports_owner_insert
  ON public.weekly_performance_reports
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS weekly_performance_reports_owner_update
  ON public.weekly_performance_reports;
CREATE POLICY weekly_performance_reports_owner_update
  ON public.weekly_performance_reports
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS weekly_performance_reports_owner_delete
  ON public.weekly_performance_reports;
CREATE POLICY weekly_performance_reports_owner_delete
  ON public.weekly_performance_reports
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.guard_weekly_performance_report()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, auth
AS $guard$
DECLARE
  v_jwt_role text;
  v_is_service boolean;
BEGIN
  v_jwt_role := COALESCE(
    NULLIF(auth.jwt() ->> 'role', ''),
    NULLIF(auth.role(), ''),
    ''
  );
  v_is_service := (v_jwt_role = 'service_role')
    OR (
      v_jwt_role = ''
      AND session_user IN ('postgres', 'supabase_admin', 'supabase_auth_admin')
    );

  IF NOT v_is_service THEN
    IF auth.uid() IS NULL THEN
      RAISE EXCEPTION 'Authentication required for weekly_performance_reports';
    END IF;

    IF TG_OP = 'INSERT' THEN
      IF NEW.user_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'user_id must match authenticated caller';
      END IF;
    ELSE
      IF NEW.id IS DISTINCT FROM OLD.id
        OR NEW.user_id IS DISTINCT FROM OLD.user_id
        OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION 'Immutable columns id, user_id, created_at cannot be modified';
      END IF;
    END IF;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    NEW.updated_at := timezone('utc', now());
  END IF;
  RETURN NEW;
END;
$guard$;

DROP TRIGGER IF EXISTS trg_guard_weekly_performance_report
  ON public.weekly_performance_reports;
CREATE TRIGGER trg_guard_weekly_performance_report
  BEFORE INSERT OR UPDATE
  ON public.weekly_performance_reports
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_weekly_performance_report();
