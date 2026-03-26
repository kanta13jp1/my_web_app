-- Create competitor_monitoring table for tracking competitor website availability
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

-- Index for efficient querying by competitor and time
CREATE INDEX IF NOT EXISTS idx_competitor_monitoring_name_checked
  ON competitor_monitoring (competitor_name, checked_at DESC);

-- Enable RLS
ALTER TABLE competitor_monitoring ENABLE ROW LEVEL SECURITY;

-- Allow service role full access
CREATE POLICY "Service role can manage competitor_monitoring"
  ON competitor_monitoring
  FOR ALL
  USING (true)
  WITH CHECK (true);
