-- user_pinned_features: ユーザーピン留め機能 (5-tier home Layer 3)
CREATE TABLE IF NOT EXISTS user_pinned_features (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  feature_route text NOT NULL,
  feature_label text,
  sort_order integer DEFAULT 0,
  UNIQUE(user_id, feature_route)
);

ALTER TABLE user_pinned_features ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users can manage own pinned features"
  ON user_pinned_features FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
