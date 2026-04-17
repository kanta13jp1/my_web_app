-- Blog corrections proposal table (2026-04-17)
-- Stores AI-detected potential errors in past posts for human review.
-- Never auto-applies; admin must approve via UI.

CREATE TABLE IF NOT EXISTS blog_corrections (
  id              uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  platform        text        NOT NULL,  -- 'qiita' | 'devto'
  article_id      text        NOT NULL,
  title           text,
  url             text,
  confidence      text,                   -- 'high' | 'med' | 'low'
  errors_json     jsonb       NOT NULL,   -- [{location, issue, correction}]
  proposal_file   text,                   -- docs/blog-corrections/*.md
  approved        boolean     NOT NULL DEFAULT false,
  approved_by     uuid,                   -- auth.uid() of approver
  approved_at     timestamptz,
  applied_at      timestamptz,            -- when actually PATCHed to platform
  applied_result  jsonb,                  -- API response
  detected_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (platform, article_id)
);

CREATE INDEX IF NOT EXISTS idx_blog_corrections_status
  ON blog_corrections (approved, applied_at);

ALTER TABLE blog_corrections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "service_role_all_corrections" ON blog_corrections
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "admin_read_corrections" ON blog_corrections
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM user_profiles up WHERE up.user_id = auth.uid() AND up.is_admin = true)
  );

CREATE POLICY "admin_update_corrections" ON blog_corrections
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM user_profiles up WHERE up.user_id = auth.uid() AND up.is_admin = true)
  );

COMMENT ON TABLE blog_corrections IS
  'AI-detected potential factual errors in past Qiita/dev.to posts. Admin-approved before being applied via API PATCH/PUT.';
