-- 思考妨害排除: slip ログをサーバーサイドに記録
-- SharedPreferences → Supabase に移行し、パターン分析を可能にする

CREATE TABLE IF NOT EXISTS abstinence_slips (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  item_id text NOT NULL,
  slipped_at timestamptz NOT NULL DEFAULT now(),
  day_of_week int GENERATED ALWAYS AS (EXTRACT(DOW FROM slipped_at AT TIME ZONE 'Asia/Tokyo')::int) STORED,
  hour_of_day int GENERATED ALWAYS AS (EXTRACT(HOUR FROM slipped_at AT TIME ZONE 'Asia/Tokyo')::int) STORED,
  trigger_note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ユーザー別・日付別のslip集計を高速化
CREATE INDEX IF NOT EXISTS idx_abstinence_slips_user_date
  ON abstinence_slips (user_id, slipped_at DESC);

-- item_id別のパターン分析用
CREATE INDEX IF NOT EXISTS idx_abstinence_slips_item
  ON abstinence_slips (item_id, slipped_at DESC);

-- 曜日・時間帯のパターン分析用
CREATE INDEX IF NOT EXISTS idx_abstinence_slips_pattern
  ON abstinence_slips (user_id, day_of_week, hour_of_day);

-- RLS
ALTER TABLE abstinence_slips ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_slips"
  ON abstinence_slips
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "service_role_full_access_slips"
  ON abstinence_slips
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- 週次パターン分析用のビュー
CREATE OR REPLACE VIEW abstinence_weekly_pattern AS
SELECT
  user_id,
  item_id,
  day_of_week,
  hour_of_day,
  COUNT(*) as slip_count,
  MAX(slipped_at) as last_slip
FROM abstinence_slips
WHERE slipped_at >= NOW() - INTERVAL '30 days'
GROUP BY user_id, item_id, day_of_week, hour_of_day
ORDER BY slip_count DESC;

COMMENT ON TABLE abstinence_slips IS '思考妨害の逸脱ログ (禁欲ガードのslip記録)';
COMMENT ON COLUMN abstinence_slips.item_id IS 'sns, video, masturbation, smoking 等のプリセットID';
COMMENT ON COLUMN abstinence_slips.trigger_note IS 'ユーザーが入力する「何がきっかけだったか」メモ';
COMMENT ON COLUMN abstinence_slips.day_of_week IS '曜日 (0=日曜, 6=土曜) - 自動計算';
COMMENT ON COLUMN abstinence_slips.hour_of_day IS '時間帯 (0-23, JST) - 自動計算';
