-- Revenue-first growth follow-up: user explicitly rejected warm-contact
-- outreach and requested X-account impression growth for @kanta13jp1.

WITH x_tasks AS (
  SELECT *
  FROM (
    VALUES
      (
        '[追加要望][収益化P0][X集客] プロフィールを1人目ユーザー獲得用に改修',
        'Rewrite the X profile for @kanta13jp1 so profile visitors immediately understand what the site does, who should try it, and why they should click. The profile link already points to the site; the bio and pinned post must make the value proposition clear.',
        'user',
        'user',
        'in_progress',
        10,
        DATE '2026-06-27',
        DATE '2026-06-27',
        'high',
        'Replace the current broad hashtag-heavy bio with a concrete one-line promise and CTA to try the site. Keep the link to https://my-web-app-b67f4.web.app/ visible.',
        'If editing the profile is delayed, publish and pin the conversion post first so profile visitors see the site value.',
        ARRAY[]::text[]
      ),
      (
        '[追加要望][収益化P0][X集客] 固定ポストをサイト導線に差し替え',
        'Create and pin one post that explains the site in plain language, asks for one real user to try it, and sends people to the site. X Help Center states pinned posts stay at the top of the profile, so this is the account conversion surface.',
        'user',
        'user',
        'pending',
        0,
        DATE '2026-06-27',
        DATE '2026-06-27',
        'high',
        'Publish the prepared pinned post from docs/marketing/x-impression-growth-sprint.md and pin it to the profile. Do not lead with payment while Stripe payout status is not clear; ask for trial and feedback first.',
        'If a post cannot be pinned immediately, keep the draft ready and post it as the next public update.',
        ARRAY['[追加要望][収益化P0][X集客] プロフィールを1人目ユーザー獲得用に改修']::text[]
      ),
      (
        '[追加要望][収益化P0][X集客] 7日間・1日5投稿のインプレッション実験',
        'Run a 7-day X content sprint: 1 build-in-public post, 1 problem/lesson post, 1 site feature post, 1 reply-bait question, and 1 quote/reply to a relevant larger account per day.',
        'user',
        'user',
        'pending',
        0,
        DATE '2026-06-27',
        DATE '2026-07-04',
        'high',
        'Track daily impressions, profile visits/clicks if available, replies, and site visits. Keep posts honest and avoid fake metrics or engagement bait that misrepresents the product.',
        'If impressions do not increase after 2 days, double down on replies to larger relevant accounts and rewrite hooks around one concrete pain point.',
        ARRAY['[追加要望][収益化P0][X集客] 固定ポストをサイト導線に差し替え']::text[]
      ),
      (
        '[追加要望][収益化P0][X集客] 大きめアカウントへの有益リプライ30件',
        'Use X replies to earn impressions without relying on acquaintances. Reply to 30 relevant posts from larger accounts in AI/dev/productivity/learning with concrete, non-spammy comments that naturally mention the site only when relevant.',
        'user',
        'user',
        'pending',
        0,
        DATE '2026-06-27',
        DATE '2026-07-04',
        'high',
        'Create a list of 20 larger accounts/topics and leave 30 useful replies. Track which replies get views, likes, replies, or profile visits.',
        'If direct site links in replies underperform, remove the link from replies and rely on the pinned profile post for conversion.',
        ARRAY['[追加要望][収益化P0][X集客] 固定ポストをサイト導線に差し替え']::text[]
      ),
      (
        '[追加要望][収益化P0][X集客] Xアナリティクスで勝ち投稿を増幅',
        'Use X Analytics / post activity to identify which posts drive impressions and engagement, then rewrite the top performer into 3 variants. X Business documentation says analytics show what works and help optimize future campaigns.',
        'user',
        'user',
        'pending',
        0,
        DATE '2026-06-29',
        DATE '2026-07-05',
        'high',
        'Record the top 3 posts by impressions and engagement. Create three follow-up variants from the winner and link/profile-convert through the pinned post.',
        'If analytics access is limited, use visible view counts and engagement counts as the minimum viable measurement.',
        ARRAY['[追加要望][収益化P0][X集客] 7日間・1日5投稿のインプレッション実験']::text[]
      ),
      (
        '[追加要望][収益化P0][X集客] X経由の1人利用を確認',
        'Convert X impressions into one real user: someone from X opens the site, replies/DMs with what they tried, or agrees to become a supporter candidate. This is the bridge from attention to revenue.',
        'codex',
        'codex',
        'pending',
        0,
        DATE '2026-07-01',
        DATE '2026-07-07',
        'high',
        'Capture evidence from one X-origin user: reply, DM, screenshot, or recorded feedback. Anonymous impressions alone do not count.',
        'If no X-origin user appears after 7 days, change the pinned post promise and run another 7-day sprint focused on the best-performing topic.',
        ARRAY[
          '[追加要望][収益化P0][X集客] 固定ポストをサイト導線に差し替え',
          '[追加要望][収益化P0][X集客] 7日間・1日5投稿のインプレッション実験',
          '[追加要望][収益化P0][X集客] 大きめアカウントへの有益リプライ30件'
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
  '追加要望 / x-first-user-growth',
  'X',
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
FROM x_tasks
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
  progress = GREATEST(progress, 25),
  remaining_work =
    'User explicitly rejected warm-contact outreach. First-user acquisition is now X-led: profile rewrite, pinned post, 7-day posting sprint, 30 useful replies to larger accounts, analytics amplification, and one X-origin user evidence.',
  recovery_plan =
    'Execute docs/marketing/x-impression-growth-sprint.md. Do not wait for acquaintances or passive SEO. Payment conversion still waits for Stripe payout status to clear.',
  depends_on_titles = ARRAY[
    '[追加要望][収益化P0][X集客] プロフィールを1人目ユーザー獲得用に改修',
    '[追加要望][収益化P0][X集客] 固定ポストをサイト導線に差し替え',
    '[追加要望][収益化P0][X集客] 7日間・1日5投稿のインプレッション実験',
    '[追加要望][収益化P0][X集客] 大きめアカウントへの有益リプライ30件'
  ]::text[],
  updated_at = now()
WHERE title IN (
    '[追加要望][収益化P0] 初回購入者獲得スプリント',
    '[追加要望][収益化P0][1人目獲得] 1対1アウトリーチ10件を実施',
    '[追加要望][収益化P0][1人目獲得] 公開投稿1本と導線クリックを確認'
  )
  AND status <> 'completed';
