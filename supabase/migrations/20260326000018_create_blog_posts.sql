-- Session 25: ブログ投稿管理テーブル + Schedule タスク追加
-- Claude Code Schedule の blog-draft タスクで使用する

CREATE TABLE IF NOT EXISTS blog_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  draft_path text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'posted', 'skipped')),
  target_platforms text[] DEFAULT '{}',
  posted_at timestamptz,
  url text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- updated_at 自動更新
CREATE OR REPLACE FUNCTION update_blog_posts_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER blog_posts_updated_at
  BEFORE UPDATE ON blog_posts
  FOR EACH ROW EXECUTE FUNCTION update_blog_posts_updated_at();

-- 管理者のみ読み書き可 (RLS)
ALTER TABLE blog_posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_all" ON blog_posts
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- 開発実績シード
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'ブログ投稿管理テーブル作成・Schedule blog-draft タスク追加',
  'Claude Code Schedule で毎日自動ブログ下書きを生成し、blog_posts テーブルで投稿管理できるようにした。PRレビュー自動化・競合モニタリング・インフラヘルスチェック・脆弱性チェックも追加。',
  '2026-03-26'
)
ON CONFLICT DO NOTHING;
