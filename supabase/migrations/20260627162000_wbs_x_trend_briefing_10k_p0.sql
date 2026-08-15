-- Revenue-first growth follow-up:
-- register the user's proven high-impression X briefing pattern as a P0 task.
-- The goal is not vanity reach by itself; it is one X-origin real user that can
-- later convert to the first paid supporter and bank payout evidence.

WITH trend_briefing_tasks AS (
  SELECT *
  FROM (
    VALUES
      (
        '[追加要望][収益化P0][X集客][10K] Xトレンド連動デイリーブリーフィング生成を本番化',
        'Upgrade AI share so it can fetch current X trends, generate Daily Briefing style posts that match the user''s proven high-impression format, post them as reply threads, and keep the site URL in a reply instead of weakening the lead post.',
        'codex',
        'codex',
        'in_progress',
        95,
        DATE '2026-06-27',
        DATE '2026-06-27',
        'high',
        'Verify one live generation from the deployed AI share dialog: trend-aware lead post, briefing thread replies, link-in-reply, and no viral-video template error. Keep the implementation guarded by tests.',
        'If the X trends API is unavailable, continue with the evergreen Daily Briefing fallback and manually paste trend topics from X Explore until API access is restored.',
        ARRAY[
          '[additional][revenue-p0][x-growth] AI share first-user acquisition mode'
        ]::text[]
      ),
      (
        '[追加要望][収益化P0][X集客][10K] 10Kインプレッション狙いのブリーフィング投稿を7日実行',
        'Publish one Daily Briefing style X post/thread per day for 7 days using timely topics and the AI share briefing preset. Target at least one 10K-impression post, then convert profile visits/replies into one real site user.',
        'user',
        'user',
        'pending',
        0,
        DATE '2026-06-27',
        DATE '2026-07-04',
        'high',
        'Each daily post must include: 3-5 numbered topical items, why it matters, outlook, minimal hashtags, and the site URL in a reply. Record impressions after 1h/6h/24h plus replies, profile visits, and any site feedback.',
        'If no post crosses 3K impressions by day 2, stop generic product posts and double down on the topic style that previously earned 30K/13K/6.6K impressions: politics, markets, international risk, AI/dev workflow, and local election analysis.',
        ARRAY[
          '[追加要望][収益化P0][X集客][10K] Xトレンド連動デイリーブリーフィング生成を本番化',
          '[追加要望][収益化P0][X集客] Xアナリティクスで勝ち投稿を増幅'
        ]::text[]
      ),
      (
        '[追加要望][収益化P0][X集客][10K] 勝ち投稿から1人目ユーザー導線へ転換',
        'When a briefing post reaches high reach, convert attention into a real user by replying with a concrete 5-minute trial ask, pinning the best thread, and capturing one X-origin user evidence.',
        'codex',
        'codex',
        'pending',
        0,
        DATE '2026-06-28',
        DATE '2026-07-05',
        'high',
        'For the best-performing thread, prepare one follow-up reply that asks for a 5-minute trial and A/B/C feedback, then record evidence of one real user from X in WBS/docs. Anonymous impressions alone do not satisfy this task.',
        'If reach rises but no one tries the site, remove the product CTA from the lead entirely and test conversion through profile + pinned reply only.',
        ARRAY[
          '[追加要望][収益化P0][X集客][10K] 10Kインプレッション狙いのブリーフィング投稿を7日実行',
          '[追加要望][収益化P0][X集客] X経由の1人利用を確認'
        ]::text[]
      )
  ) AS t(
    title,
    description,
    instance,
    owner_instance,
    status,
    progress,
    start_date,
    end_date,
    priority,
    remaining_work,
    recovery_plan,
    depends_on_titles
  )
)
INSERT INTO public.wbs_tasks
  (
    category,
    category_icon,
    category_order,
    title,
    description,
    instance,
    owner_instance,
    status,
    progress,
    start_date,
    end_date,
    milestone_code,
    priority,
    ai_review_status,
    stale_threshold_hours,
    remaining_work,
    recovery_plan,
    depends_on_titles
  )
SELECT
  '追加要望 / x-10k-briefing-growth',
  'trending_up',
  0,
  title,
  description,
  instance,
  owner_instance,
  status,
  progress,
  start_date,
  end_date,
  'first-yen-revenue',
  priority,
  'pending',
  6,
  remaining_work,
  recovery_plan,
  depends_on_titles
FROM trend_briefing_tasks
ON CONFLICT (title, instance) DO UPDATE SET
  category = EXCLUDED.category,
  category_icon = EXCLUDED.category_icon,
  category_order = EXCLUDED.category_order,
  description = EXCLUDED.description,
  owner_instance = EXCLUDED.owner_instance,
  status = CASE
    WHEN public.wbs_tasks.status = 'completed' THEN public.wbs_tasks.status
    ELSE EXCLUDED.status
  END,
  progress = GREATEST(public.wbs_tasks.progress, EXCLUDED.progress),
  start_date = EXCLUDED.start_date,
  end_date = EXCLUDED.end_date,
  milestone_code = EXCLUDED.milestone_code,
  priority = EXCLUDED.priority,
  stale_threshold_hours = EXCLUDED.stale_threshold_hours,
  remaining_work = EXCLUDED.remaining_work,
  recovery_plan = EXCLUDED.recovery_plan,
  depends_on_titles = EXCLUDED.depends_on_titles,
  updated_at = now();

UPDATE public.wbs_tasks
SET
  status = 'in_progress',
  progress = GREATEST(progress, 60),
  remaining_work =
    'AI share is now oriented toward the proven Daily Briefing format with X trends, threads, link-in-reply, and 10K-impression measurement. Next: publish daily briefing threads and convert one X-origin user.',
  recovery_plan =
    'Do not keep posting generic app promotion. Use the proven high-impression briefing format and measure 1h/6h/24h performance. If X trends API fails, manually seed trend topics.',
  depends_on_titles = ARRAY[
    '[追加要望][収益化P0][X集客][10K] Xトレンド連動デイリーブリーフィング生成を本番化',
    '[追加要望][収益化P0][X集客][10K] 10Kインプレッション狙いのブリーフィング投稿を7日実行',
    '[追加要望][収益化P0][X集客][10K] 勝ち投稿から1人目ユーザー導線へ転換'
  ]::text[],
  updated_at = now()
WHERE title IN (
    '[追加要望][収益化P0][X集客] 7日間・1日5投稿のインプレッション実験',
    '[追加要望][収益化P0][X集客] Xアナリティクスで勝ち投稿を増幅',
    '[追加要望][収益化P0][X集客] X経由の1人利用を確認',
    '[additional][revenue-p0][x-growth] AI share first-user acquisition mode'
  )
  AND status <> 'completed';
