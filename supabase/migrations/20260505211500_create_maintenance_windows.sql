CREATE TABLE IF NOT EXISTS public.maintenance_windows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scope text NOT NULL DEFAULT 'system'
    CHECK (scope IN ('system', 'feature')),
  affected_features text[] NOT NULL DEFAULT '{}',
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  notice_days_before int NOT NULL DEFAULT 3
    CHECK (notice_days_before >= 0 AND notice_days_before <= 30),
  message_ja text NOT NULL,
  message_en text,
  severity text NOT NULL DEFAULT 'info'
    CHECK (severity IN ('info', 'warning', 'critical')),
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (ends_at > starts_at),
  CHECK (
    scope = 'system'
    OR cardinality(affected_features) > 0
  )
);

CREATE INDEX IF NOT EXISTS maintenance_windows_lookup_idx
  ON public.maintenance_windows (starts_at, ends_at);

CREATE INDEX IF NOT EXISTS maintenance_windows_scope_idx
  ON public.maintenance_windows (scope);

CREATE OR REPLACE FUNCTION public.set_maintenance_windows_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS maintenance_windows_set_updated_at
  ON public.maintenance_windows;

CREATE TRIGGER maintenance_windows_set_updated_at
  BEFORE UPDATE ON public.maintenance_windows
  FOR EACH ROW
  EXECUTE FUNCTION public.set_maintenance_windows_updated_at();

ALTER TABLE public.maintenance_windows ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS maintenance_windows_public_read
  ON public.maintenance_windows;

CREATE POLICY maintenance_windows_public_read
  ON public.maintenance_windows
  FOR SELECT
  USING (true);
