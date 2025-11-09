-- AI features table creation
-- AI usage logs, user profiles, follow functionality, comments functionality

-- AI usage log table
CREATE TABLE IF NOT EXISTS ai_usage_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action TEXT NOT NULL, -- 'improve', 'summarize', 'expand', 'translate', 'suggest_title', 'suggest_tags', 'search'
  input_tokens INTEGER DEFAULT 0,
  output_tokens INTEGER DEFAULT 0,
  total_tokens INTEGER DEFAULT 0,
  cost_estimate DECIMAL(10, 6) DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_ai_usage_log_user_id ON ai_usage_log(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_usage_log_created_at ON ai_usage_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_usage_log_action ON ai_usage_log(action);

-- RLS setup
ALTER TABLE ai_usage_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own AI usage logs" ON ai_usage_log;
CREATE POLICY "Users can view their own AI usage logs"
  ON ai_usage_log FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own AI usage logs" ON ai_usage_log;
CREATE POLICY "Users can insert their own AI usage logs"
  ON ai_usage_log FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- User profiles table
CREATE TABLE IF NOT EXISTS user_profiles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  bio TEXT,
  avatar_url TEXT,
  website_url TEXT,
  location TEXT,
  twitter_handle TEXT,
  github_handle TEXT,
  is_public BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS setup
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON user_profiles;
CREATE POLICY "Public profiles are viewable by everyone"
  ON user_profiles FOR SELECT
  USING (is_public = true OR auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own profile" ON user_profiles;
CREATE POLICY "Users can insert their own profile"
  ON user_profiles FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
CREATE POLICY "Users can update their own profile"
  ON user_profiles FOR UPDATE
  USING (auth.uid() = user_id);

-- Follow table
CREATE TABLE IF NOT EXISTS user_follows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  following_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(follower_id, following_id),
  CHECK (follower_id != following_id)
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_user_follows_follower ON user_follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_user_follows_following ON user_follows(following_id);

-- RLS setup
ALTER TABLE user_follows ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view all follows" ON user_follows;
CREATE POLICY "Users can view all follows"
  ON user_follows FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Users can follow others" ON user_follows;
CREATE POLICY "Users can follow others"
  ON user_follows FOR INSERT
  WITH CHECK (auth.uid() = follower_id);

DROP POLICY IF EXISTS "Users can unfollow" ON user_follows;
CREATE POLICY "Users can unfollow"
  ON user_follows FOR DELETE
  USING (auth.uid() = follower_id);

-- Note comments table
CREATE TABLE IF NOT EXISTS note_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id BIGINT NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_note_comments_note_id ON note_comments(note_id);
CREATE INDEX IF NOT EXISTS idx_note_comments_user_id ON note_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_note_comments_created_at ON note_comments(created_at DESC);

-- RLS setup
ALTER TABLE note_comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Comments on public notes are viewable by everyone" ON note_comments;
CREATE POLICY "Comments on public notes are viewable by everyone"
  ON note_comments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM notes
      WHERE notes.id = note_comments.note_id
      AND (notes.user_id = auth.uid() OR notes.id IN (
        SELECT note_id FROM public_memos WHERE public_memos.is_public = true
      ))
    )
  );

DROP POLICY IF EXISTS "Users can create comments" ON note_comments;
CREATE POLICY "Users can create comments"
  ON note_comments FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own comments" ON note_comments;
CREATE POLICY "Users can update their own comments"
  ON note_comments FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own comments" ON note_comments;
CREATE POLICY "Users can delete their own comments"
  ON note_comments FOR DELETE
  USING (auth.uid() = user_id);

-- Note likes table
CREATE TABLE IF NOT EXISTS note_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id BIGINT NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(note_id, user_id)
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_note_likes_note_id ON note_likes(note_id);
CREATE INDEX IF NOT EXISTS idx_note_likes_user_id ON note_likes(user_id);

-- RLS setup
ALTER TABLE note_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Likes on public notes are viewable by everyone" ON note_likes;
CREATE POLICY "Likes on public notes are viewable by everyone"
  ON note_likes FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Users can like notes" ON note_likes;
CREATE POLICY "Users can like notes"
  ON note_likes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can unlike notes" ON note_likes;
CREATE POLICY "Users can unlike notes"
  ON note_likes FOR DELETE
  USING (auth.uid() = user_id);

-- View to get follower and following counts
CREATE OR REPLACE VIEW user_follow_counts AS
SELECT
  u.id AS user_id,
  COALESCE(follower_counts.count, 0) AS followers_count,
  COALESCE(following_counts.count, 0) AS following_count
FROM auth.users u
LEFT JOIN (
  SELECT following_id, COUNT(*) AS count
  FROM user_follows
  GROUP BY following_id
) follower_counts ON u.id = follower_counts.following_id
LEFT JOIN (
  SELECT follower_id, COUNT(*) AS count
  FROM user_follows
  GROUP BY follower_id
) following_counts ON u.id = following_counts.follower_id;

-- View to get like counts
CREATE OR REPLACE VIEW note_like_counts AS
SELECT
  note_id,
  COUNT(*) AS likes_count
FROM note_likes
GROUP BY note_id;

-- View to get comment counts
CREATE OR REPLACE VIEW note_comment_counts AS
SELECT
  note_id,
  COUNT(*) AS comments_count
FROM note_comments
GROUP BY note_id;

-- Trigger: Auto-update updated_at
-- Note: update_updated_at_column() function already exists from growth_features migration
-- We only need to create triggers for new tables

DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON user_profiles;
DROP TRIGGER IF EXISTS update_note_comments_updated_at ON note_comments;

CREATE TRIGGER update_user_profiles_updated_at
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_note_comments_updated_at
  BEFORE UPDATE ON note_comments
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Sample data: Function to create default profile
CREATE OR REPLACE FUNCTION create_default_user_profile()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_profiles (user_id, display_name, is_public)
  VALUES (NEW.id, NEW.email, true)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: Create default profile on new user registration
DROP TRIGGER IF EXISTS on_auth_user_created_profile ON auth.users;

CREATE TRIGGER on_auth_user_created_profile
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION create_default_user_profile();
