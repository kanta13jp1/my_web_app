-- Create competitor_monitoring table for check-competitor-updates Edge Function
CREATE TABLE IF NOT EXISTS competitor_monitoring (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  competitor_name TEXT NOT NULL,
  competitor_url TEXT NOT NULL,
  status_code INTEGER NOT NULL DEFAULT 0,
  response_time_ms INTEGER NOT NULL DEFAULT 0,
  available BOOLEAN NOT NULL DEFAULT false,
  checked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for querying by competitor and time
CREATE INDEX IF NOT EXISTS idx_competitor_monitoring_name_checked
  ON competitor_monitoring (competitor_name, checked_at DESC);

-- Index for querying latest checks
CREATE INDEX IF NOT EXISTS idx_competitor_monitoring_checked_at
  ON competitor_monitoring (checked_at DESC);

-- Enable RLS
ALTER TABLE competitor_monitoring ENABLE ROW LEVEL SECURITY;

-- Allow service role full access (Edge Functions use service role)
CREATE POLICY "Service role full access on competitor_monitoring"
  ON competitor_monitoring
  FOR ALL
  USING (true)
  WITH CHECK (true);
