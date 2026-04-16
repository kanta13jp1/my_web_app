-- P2: 構造化学習者プロファイル (AI大学 v2)
CREATE TABLE IF NOT EXISTS ai_university_learner_profiles (
  user_id          uuid REFERENCES auth.users PRIMARY KEY,
  weak_providers   text[] DEFAULT '{}',
  strong_providers text[] DEFAULT '{}',
  preferred_style  text DEFAULT 'text',
  total_sessions   int DEFAULT 0,
  profile_json     jsonb DEFAULT '{}',
  updated_at       timestamptz DEFAULT now()
);

ALTER TABLE ai_university_learner_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_profile" ON ai_university_learner_profiles
  FOR ALL USING (user_id = auth.uid());

-- P3/P4: ai_university_scores に voice/groq カラム追加
ALTER TABLE ai_university_scores
  ADD COLUMN IF NOT EXISTS voice_mode   bool DEFAULT false,
  ADD COLUMN IF NOT EXISTS groq_routed  bool DEFAULT false;
