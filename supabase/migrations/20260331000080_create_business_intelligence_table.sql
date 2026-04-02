-- Business intelligence tracker for competitor and market monitoring

CREATE TABLE IF NOT EXISTS business_intelligence (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category text NOT NULL,
  competitor text NOT NULL,
  source text,
  market_size text,
  our_feature text,
  gap_analysis text,
  priority int NOT NULL DEFAULT 5,
  status text NOT NULL DEFAULT 'tracking',
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE business_intelligence ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated can read business_intelligence" ON business_intelligence;
CREATE POLICY "Authenticated can read business_intelligence"
  ON business_intelligence FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "service_role_business_intelligence" ON business_intelligence;
CREATE POLICY "service_role_business_intelligence"
  ON business_intelligence FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "admin_all_business_intelligence" ON business_intelligence;
CREATE POLICY "admin_all_business_intelligence"
  ON business_intelligence FOR ALL
  USING (
    EXISTS (
      SELECT 1
      FROM user_profiles up
      WHERE up.user_id = auth.uid() AND up.is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM user_profiles up
      WHERE up.user_id = auth.uid() AND up.is_admin = true
    )
  );

CREATE INDEX IF NOT EXISTS idx_business_intelligence_category
  ON business_intelligence(category);
CREATE INDEX IF NOT EXISTS idx_business_intelligence_priority
  ON business_intelligence(priority DESC);

INSERT INTO business_intelligence (
  category,
  competitor,
  source,
  market_size,
  our_feature,
  priority,
  status
) VALUES
  ('knowledge_management', 'Notion', 'direct', 'Global productivity software market', 'AI note + task + wiki', 10, 'competing'),
  ('knowledge_management', 'Evernote', 'direct', 'Japan productivity market', 'AI capture and organization', 8, 'competing'),
  ('finance', 'MoneyForward', 'direct', 'Japan fintech market', 'Personal finance automation', 9, 'competing'),
  ('sns', 'X (Twitter)', 'direct', 'Global SNS market', 'Public memo + social publishing', 8, 'competing'),
  ('ai_tools', 'Animaworks', 'direct', 'AI niche tools market', 'Multi-agent workflow system', 6, 'competing'),
  ('ai_dev_tools', 'Claude Code', 'direct', 'AI developer tools', 'Repository-aware autonomous coding', 9, 'competing'),
  ('ai_dev_tools', 'Codex', 'direct', 'AI developer tools', 'Coding assistant with task execution', 7, 'competing'),
  ('horse_racing', 'netkeiba', 'direct', 'Horse racing media market', 'AI prediction and race analysis', 5, 'tracking'),
  ('project_management', 'OpenClaw', 'direct', 'Project management tools', 'AI-driven execution workflows', 6, 'competing'),
  ('remote_work', 'Claude Cowork', 'direct', 'AI cowork market', 'Team workspace + AI assistants', 7, 'competing'),
  ('business_chat', 'Chatwork', 'direct', 'Japan business chat market', 'Chat + task + AI operations', 8, 'competing'),
  ('business_chat', 'Slack', 'direct', 'Global business chat market', 'AI-first collaboration workspace', 9, 'competing'),
  ('hr_payroll', 'Jobcan', 'direct', 'Japan HR SaaS market', 'Labor and payroll intelligence', 7, 'competing'),
  ('ecommerce', 'Amazon', 'direct', 'Global ecommerce market', 'Shopping intelligence and tracking', 6, 'tracking'),
  ('platform', 'Google', 'direct', 'Global platform market', 'AI search and workspace integration', 10, 'competing'),
  ('platform', 'Microsoft', 'direct', 'Enterprise platform market', 'Office and Teams integration', 9, 'competing'),
  ('gaming_community', 'Discord', 'direct', 'Community platform market', 'Community + voice + AI support', 7, 'competing'),
  ('sns_messaging', 'LINE', 'direct', 'Japan messaging market', 'AI messaging workflows', 9, 'competing'),
  ('sns', 'Facebook', 'direct', 'Global SNS market', 'Community and group operations', 7, 'competing'),
  ('lifestyle', 'Liven', 'direct', 'Lifestyle app market', 'Life management automation', 6, 'competing'),
  ('developer_tools', 'GitHub', 'direct', 'Coding platform market', 'Project execution and CI support', 8, 'competing')
ON CONFLICT DO NOTHING;
