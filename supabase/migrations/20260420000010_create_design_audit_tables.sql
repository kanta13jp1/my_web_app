-- Design audit tables: source of truth for UI design compliance status
-- Replaces Dart const arrays in lib/data/design_compliance_data.dart (UI reads via core-hub)

CREATE TABLE IF NOT EXISTS design_screens (
  route          text PRIMARY KEY,
  name           text NOT NULL,
  category       text NOT NULL CHECK (category IN (
    'marketing','home','notes','ai','business','personal','creative','admin'
  )),
  compliance     boolean[],          -- length=7, NULL = 未審査
  audit_date     date,
  notes          text,
  mcp_tool_used  text[],             -- ['figma','aidesigner','designskills','designmd']
  updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS design_rollout (
  route          text PRIMARY KEY REFERENCES design_screens(route) ON DELETE CASCADE,
  stage          text NOT NULL CHECK (stage IN ('applied','in_progress','planned')),
  figma_mcp      text NOT NULL CHECK (figma_mcp IN ('applied','in_progress','planned')),
  ai_designer    text NOT NULL CHECK (ai_designer IN ('applied','in_progress','planned')),
  design_skills  text NOT NULL CHECK (design_skills IN ('applied','in_progress','planned')),
  design_md      text NOT NULL CHECK (design_md IN ('applied','in_progress','planned')),
  headline       text NOT NULL,
  next_step      text NOT NULL,
  updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_design_screens_category  ON design_screens(category);
CREATE INDEX IF NOT EXISTS idx_design_screens_audit_date ON design_screens(audit_date DESC);

ALTER TABLE design_screens ENABLE ROW LEVEL SECURITY;
ALTER TABLE design_rollout ENABLE ROW LEVEL SECURITY;

CREATE POLICY "design_screens read" ON design_screens FOR SELECT USING (true);
CREATE POLICY "design_rollout read"  ON design_rollout  FOR SELECT USING (true);
-- Write operations are service_role only (enforced at EF layer via bearer check)
