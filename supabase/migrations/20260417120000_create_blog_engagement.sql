-- Blog engagement tracking tables (2026-04-17)
-- blog_engagement: per-article stats (likes/comments/views)
-- blog_comments:   individual comments + auto-reply tracking
-- blog_likers:     who liked each article + auto-follow tracking

-- ─── blog_engagement ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS blog_engagement (
  platform       text NOT NULL,  -- 'qiita' | 'devto'
  article_id     text NOT NULL,
  title          text,
  url            text,
  likes_count    int  NOT NULL DEFAULT 0,
  comments_count int  NOT NULL DEFAULT 0,
  views_count    int  NOT NULL DEFAULT 0,
  updated_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (platform, article_id)
);

-- ─── blog_comments ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS blog_comments (
  platform    text NOT NULL,  -- 'qiita' | 'devto'
  article_id  text NOT NULL,
  comment_id  text NOT NULL,
  author      text,
  body        text,
  created_at  timestamptz,
  replied     boolean     NOT NULL DEFAULT false,
  reply_text  text,
  replied_at  timestamptz,
  fetched_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (platform, comment_id)
);

-- ─── blog_likers ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS blog_likers (
  article_id     text NOT NULL,
  qiita_user_id  text NOT NULL,
  username       text,
  followed       boolean     NOT NULL DEFAULT false,
  followed_at    timestamptz,
  fetched_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (article_id, qiita_user_id)
);

-- ─── RLS: service role only ─────────────────────────────────────
ALTER TABLE blog_engagement ENABLE ROW LEVEL SECURITY;
ALTER TABLE blog_comments   ENABLE ROW LEVEL SECURITY;
ALTER TABLE blog_likers     ENABLE ROW LEVEL SECURITY;

CREATE POLICY "service_role_all_engagement" ON blog_engagement
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "service_role_all_comments" ON blog_comments
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "service_role_all_likers" ON blog_likers
  FOR ALL USING (auth.role() = 'service_role');

-- ─── Admin read access ──────────────────────────────────────────
CREATE POLICY "admin_read_engagement" ON blog_engagement
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM user_profiles up WHERE up.user_id = auth.uid() AND up.is_admin = true)
  );

CREATE POLICY "admin_read_comments" ON blog_comments
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM user_profiles up WHERE up.user_id = auth.uid() AND up.is_admin = true)
  );

CREATE POLICY "admin_read_likers" ON blog_likers
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM user_profiles up WHERE up.user_id = auth.uid() AND up.is_admin = true)
  );
