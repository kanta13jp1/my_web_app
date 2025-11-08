-- Growth Metrics Table Migration
-- This tracks daily growth metrics for real-time statistics and trend analysis

-- 1. Create growth_metrics table
CREATE TABLE IF NOT EXISTS growth_metrics (
  id BIGSERIAL PRIMARY KEY,
  metric_date DATE NOT NULL UNIQUE,
  total_users INTEGER NOT NULL DEFAULT 0,
  active_users INTEGER NOT NULL DEFAULT 0,
  new_users INTEGER NOT NULL DEFAULT 0,
  total_notes INTEGER NOT NULL DEFAULT 0,
  notes_created_today INTEGER NOT NULL DEFAULT 0,
  total_shares INTEGER NOT NULL DEFAULT 0,
  shares_created_today INTEGER NOT NULL DEFAULT 0,
  online_users INTEGER NOT NULL DEFAULT 0,
  online_guests INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Create index for better performance
CREATE INDEX IF NOT EXISTS idx_growth_metrics_date ON growth_metrics(metric_date DESC);

-- 3. Enable Row Level Security (RLS)
ALTER TABLE growth_metrics ENABLE ROW LEVEL SECURITY;

-- 4. Create RLS policy - Anyone can read growth metrics (public data)
CREATE POLICY "Anyone can view growth metrics"
  ON growth_metrics FOR SELECT
  USING (true);

-- 5. Create function to record daily growth metrics
CREATE OR REPLACE FUNCTION record_daily_growth_metrics()
RETURNS void AS $$
DECLARE
  v_today DATE := CURRENT_DATE;
  v_total_users INTEGER;
  v_active_users INTEGER;
  v_new_users INTEGER;
  v_total_notes INTEGER;
  v_notes_today INTEGER;
  v_total_shares INTEGER;
  v_shares_today INTEGER;
  v_online_users INTEGER;
  v_online_guests INTEGER;
BEGIN
  -- Count total users
  SELECT COUNT(*) INTO v_total_users
  FROM auth.users;

  -- Count active users today (users who have activity today)
  SELECT COUNT(DISTINCT user_id) INTO v_active_users
  FROM user_stats
  WHERE DATE(last_activity_date) = v_today;

  -- Count new users today
  SELECT COUNT(*) INTO v_new_users
  FROM auth.users
  WHERE DATE(created_at) = v_today;

  -- Count total notes
  SELECT COUNT(*) INTO v_total_notes
  FROM notes;

  -- Count notes created today
  SELECT COUNT(*) INTO v_notes_today
  FROM notes
  WHERE DATE(created_at) = v_today;

  -- Count total shares
  SELECT COUNT(*) INTO v_total_shares
  FROM shared_notes;

  -- Count shares created today
  SELECT COUNT(*) INTO v_shares_today
  FROM shared_notes
  WHERE DATE(created_at) = v_today;

  -- Count online users (active in last 5 minutes)
  SELECT COUNT(DISTINCT user_id) INTO v_online_users
  FROM user_presence
  WHERE is_online = true
    AND last_seen >= NOW() - INTERVAL '5 minutes';

  -- Count online guests (active in last 5 minutes)
  SELECT COUNT(*) INTO v_online_guests
  FROM guest_presence
  WHERE last_seen >= NOW() - INTERVAL '5 minutes';

  -- Insert or update today's metrics
  INSERT INTO growth_metrics (
    metric_date,
    total_users,
    active_users,
    new_users,
    total_notes,
    notes_created_today,
    total_shares,
    shares_created_today,
    online_users,
    online_guests
  ) VALUES (
    v_today,
    v_total_users,
    v_active_users,
    v_new_users,
    v_total_notes,
    v_notes_today,
    v_total_shares,
    v_shares_today,
    v_online_users,
    v_online_guests
  )
  ON CONFLICT (metric_date)
  DO UPDATE SET
    total_users = EXCLUDED.total_users,
    active_users = EXCLUDED.active_users,
    new_users = EXCLUDED.new_users,
    total_notes = EXCLUDED.total_notes,
    notes_created_today = EXCLUDED.notes_created_today,
    total_shares = EXCLUDED.total_shares,
    shares_created_today = EXCLUDED.shares_created_today,
    online_users = EXCLUDED.online_users,
    online_guests = EXCLUDED.online_guests,
    updated_at = NOW();

  RAISE NOTICE 'Daily growth metrics recorded successfully';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Create function to auto-record metrics (called hourly via cron or edge function)
CREATE OR REPLACE FUNCTION auto_record_growth_metrics()
RETURNS void AS $$
BEGIN
  PERFORM record_daily_growth_metrics();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Grant permissions
GRANT SELECT ON growth_metrics TO authenticated;
GRANT SELECT ON growth_metrics TO anon;

-- 8. Initial data - record metrics for today
SELECT record_daily_growth_metrics();

-- Note: Set up a cron job or Supabase Edge Function to call record_daily_growth_metrics() every hour
-- Example using pg_cron (if available):
-- SELECT cron.schedule('record-growth-metrics', '0 * * * *', 'SELECT record_daily_growth_metrics();');
