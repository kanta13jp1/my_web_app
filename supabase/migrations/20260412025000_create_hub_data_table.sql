-- hub_data: generic CRUD table for all hub EFs
-- app_analytics has a date PRIMARY KEY (one row/day) which conflicts with hub INSERT patterns
-- This table is purpose-built for hub EF multi-row CRUD operations

CREATE TABLE IF NOT EXISTS hub_data (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source text NOT NULL,
  metadata jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hub_data_source ON hub_data (source);
CREATE INDEX IF NOT EXISTS idx_hub_data_created_at ON hub_data (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_hub_data_metadata ON hub_data USING gin (metadata jsonb_path_ops);

ALTER TABLE hub_data ENABLE ROW LEVEL SECURITY;

-- Allow service_role full access (hub EFs use SERVICE_ROLE_KEY)
CREATE POLICY "service_role_all" ON hub_data
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Allow authenticated users to read/write their own rows
CREATE POLICY "authenticated_own_rows" ON hub_data
  FOR ALL TO authenticated
  USING (metadata->>'user_id' = auth.uid()::text)
  WITH CHECK (metadata->>'user_id' = auth.uid()::text);
