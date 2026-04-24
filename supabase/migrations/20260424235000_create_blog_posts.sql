-- ブログ投稿管理テーブル
-- Claude Schedule が生成した下書きを記録し、各プラットフォームへの投稿状態を管理する。
CREATE TABLE IF NOT EXISTS public.blog_posts (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  title            text        NOT NULL,
  draft_path       text        NOT NULL,
  status           text        NOT NULL DEFAULT 'draft'
                               CHECK (status IN ('draft', 'scheduled', 'published', 'archived')),
  target_platforms text[]      NOT NULL DEFAULT '{}',
  published_platforms jsonb    NOT NULL DEFAULT '{}',
  slug             text,
  tags             text[]      NOT NULL DEFAULT '{}',
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  published_at     timestamptz
);

-- updated_at 自動更新トリガー
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER blog_posts_updated_at
  BEFORE UPDATE ON public.blog_posts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- RLS: anon は読み取りのみ / service_role は全操作
ALTER TABLE public.blog_posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon read blog_posts" ON public.blog_posts
  FOR SELECT USING (true);

CREATE POLICY "service role write blog_posts" ON public.blog_posts
  FOR ALL USING (auth.role() = 'service_role');

-- 初回下書きレコード (2026-04-23 Multi-AI Fallback記事)
INSERT INTO public.blog_posts (title, draft_path, status, target_platforms, tags, created_at)
VALUES (
  'Claude Quota超過でも開発を止めない — 自分株式会社のMulti-AI Fallback設計',
  'docs/blog-drafts/2026-04-23.md',
  'draft',
  ARRAY['zenn','qiita','note','hatena','medium','devto','hashnode','substack','github-pages','notion','x-article'],
  ARRAY['Flutter','Supabase','ClaudeCode','MultiAI','個人開発','buildinpublic'],
  '2026-04-23 00:00:00+09'
)
ON CONFLICT DO NOTHING;
