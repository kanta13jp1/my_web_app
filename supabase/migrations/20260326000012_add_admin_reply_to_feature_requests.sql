-- Session 22: CS自動返信対応 — feature_requests に admin_reply カラム追加

ALTER TABLE public.feature_requests
  ADD COLUMN IF NOT EXISTS admin_reply text,
  ADD COLUMN IF NOT EXISTS admin_replied_at timestamptz;

COMMENT ON COLUMN public.feature_requests.admin_reply IS 'Claude Schedule が自動生成した返信文、または管理者の手動返信';
COMMENT ON COLUMN public.feature_requests.admin_replied_at IS '返信日時';

CREATE INDEX IF NOT EXISTS feature_requests_admin_replied_idx
  ON public.feature_requests (admin_replied_at)
  WHERE admin_replied_at IS NULL;
