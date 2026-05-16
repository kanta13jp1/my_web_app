-- 資産管理 第2弾 A1 — 月次資産レポート schema (Issue #2460)
-- Win Claude #132 part 218 (2026-05-16 JST) / user 直接 ask (= 7-step Full 強行)
-- 関連: #2460 (A1 schema) / #2461 (A2 EF ai_hub.monthly_asset_report) / #2462 (A3 GHA cron)

BEGIN;

CREATE TABLE IF NOT EXISTS public.monthly_asset_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  year_month date NOT NULL,
  total_assets bigint NOT NULL DEFAULT 0,
  total_liabilities bigint NOT NULL DEFAULT 0,
  net_worth bigint NOT NULL DEFAULT 0,
  ai_summary text,
  ai_model text,
  generated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT monthly_asset_reports_year_month_first_day CHECK (
    extract(day from year_month) = 1
  ),
  CONSTRAINT monthly_asset_reports_unique_user_month UNIQUE (user_id, year_month)
);

CREATE INDEX IF NOT EXISTS monthly_asset_reports_user_month_idx
  ON public.monthly_asset_reports (user_id, year_month DESC);

COMMENT ON TABLE public.monthly_asset_reports IS
  '資産管理 第2弾 A: 月次資産レポート (= AI要約 + KPI snapshot). Issue #2460. user毎 (year_month) unique.';
COMMENT ON COLUMN public.monthly_asset_reports.year_month IS
  '対象月の月初日付 (= YYYY-MM-01). CHECK 制約で第 1 日に固定.';
COMMENT ON COLUMN public.monthly_asset_reports.total_assets IS
  '当月末時点の総資産額 (= 円). deterministic Repository 層で計算.';
COMMENT ON COLUMN public.monthly_asset_reports.total_liabilities IS
  '当月末時点の総負債額 (= 円).';
COMMENT ON COLUMN public.monthly_asset_reports.net_worth IS
  '純資産 (= total_assets - total_liabilities).';
COMMENT ON COLUMN public.monthly_asset_reports.ai_summary IS
  'AI要約文 (= ai-hub provider.chat 結果). feature flag OFF 時は NULL.';
COMMENT ON COLUMN public.monthly_asset_reports.ai_model IS
  'AI要約生成 model 名 (= claude-opus-4-7 等). feature flag OFF 時は NULL.';

ALTER TABLE public.monthly_asset_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS monthly_asset_reports_select_own ON public.monthly_asset_reports;
CREATE POLICY monthly_asset_reports_select_own
  ON public.monthly_asset_reports
  FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS monthly_asset_reports_service_role_write ON public.monthly_asset_reports;
CREATE POLICY monthly_asset_reports_service_role_write
  ON public.monthly_asset_reports
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- updated_at auto-touch trigger (= 既存パターン準拠 = table-specific function 命名)
CREATE OR REPLACE FUNCTION public.set_monthly_asset_reports_updated_at()
  RETURNS trigger
  LANGUAGE plpgsql
  AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS monthly_asset_reports_set_updated_at
  ON public.monthly_asset_reports;

CREATE TRIGGER monthly_asset_reports_set_updated_at
  BEFORE UPDATE ON public.monthly_asset_reports
  FOR EACH ROW
  EXECUTE FUNCTION public.set_monthly_asset_reports_updated_at();

COMMIT;
