-- tech_blog_posts: track daily tech blog posting across platforms
create table if not exists public.tech_blog_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null, -- 'zenn', 'qiita', 'hatena', 'note', 'medium', 'devto', 'hashnode', 'substack', 'github_pages', 'notion'
  title text not null default '',
  url text not null default '',
  posted_at date not null default current_date,
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.tech_blog_posts enable row level security;

drop policy if exists "Users can manage their own blog posts" on public.tech_blog_posts;
create policy "Users can manage their own blog posts"
  on public.tech_blog_posts for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create index if not exists tech_blog_posts_user_posted_idx
  on public.tech_blog_posts(user_id, posted_at desc);
