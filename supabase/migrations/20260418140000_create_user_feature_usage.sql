-- user_feature_usage: ホーム画面機能タップ履歴 (5-tier home Layer 1)
CREATE TABLE IF NOT EXISTS user_feature_usage (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  feature_route text NOT NULL,
  feature_label text,
  tapped_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_feature_usage_user_tapped
  ON user_feature_usage(user_id, tapped_at DESC);

ALTER TABLE user_feature_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users can manage own feature usage"
  ON user_feature_usage FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
