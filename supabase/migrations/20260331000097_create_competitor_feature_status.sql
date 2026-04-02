-- Session 427: competitor_feature_status テーブル + competitor-feature-sync 実績
CREATE TABLE IF NOT EXISTS competitor_feature_status (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  competitor_id text NOT NULL,
  feature_name text NOT NULL,
  status text NOT NULL DEFAULT 'notYet',
  notes text,
  updated_at timestamptz DEFAULT now(),
  UNIQUE (competitor_id, feature_name)
);

CREATE INDEX IF NOT EXISTS idx_competitor_feature_status_competitor
  ON competitor_feature_status (competitor_id);

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('Competitor Feature Sync Edge Function 追加', '競合機能パリティの動的管理。ステータス更新・進捗率算出・カテゴリ別分析・優先実装リスト。competitor_feature_status テーブル追加', '2026-03-31')
ON CONFLICT DO NOTHING;
