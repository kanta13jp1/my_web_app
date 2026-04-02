-- Blog post record: 2026-03-31 Edge Function 155本体制達成
INSERT INTO blog_posts (title, draft_path, status, target_platforms, created_at)
VALUES (
  'Flutter Web × Supabase で Edge Function 155本体制を達成 — AI自動化・電子署名・ビデオ会議まで全部乗せ',
  'docs/blog-drafts/2026-03-31.md',
  'draft',
  ARRAY['zenn','qiita','note','hatena','medium','devto','hashnode','substack','github-pages','notion','x-article'],
  '2026-03-31T09:00:00+09:00'
)
ON CONFLICT DO NOTHING;
