-- Revenue-first growth follow-up: add concrete P0 tasks for acquiring the
-- first real user/supporter candidate. Payment conversion remains gated by
-- Stripe identity/payout status, but user acquisition must start now.

WITH first_user_tasks AS (
  SELECT *
  FROM (
    VALUES
      (
        '[追加要望][収益化P0][1人目獲得] 最初の対象ユーザー像と10名リストを作る',
        'Define the first-user persona and create a concrete list of at least 10 people to contact directly. This is not a vague marketing plan; it is a named target list for the first real user/supporter candidate.',
        'user',
        'user',
        'in_progress',
        10,
        DATE '2026-06-27',
        DATE '2026-06-27',
        'high',
        'Create a list of 10 named prospects or communities with why each person would care, contact channel, and exact ask. Include at least 3 warm/direct contacts before relying on public posts.',
        'If no warm contacts are available, use existing communities or followers, but still record concrete targets and outreach attempts.',
        ARRAY[]::text[]
      ),
      (
        '[追加要望][収益化P0][1人目獲得] 1対1アウトリーチ10件を実施',
        'Send direct messages or personal requests to 10 concrete prospects to get one real user or supporter candidate. Track sent time, response, objections, and next action.',
        'user',
        'user',
        'pending',
        0,
        DATE '2026-06-27',
        DATE '2026-06-28',
        'high',
        'Use docs/marketing/first-user-acquisition-sprint.md to send 10 direct outreach messages. The ask can be free usage, feedback, or supporter intent while Stripe payout status is still clearing.',
        'If response rate is zero after 10 touches, rewrite the message around one concrete use case and do 10 more touches before changing product scope.',
        ARRAY['[追加要望][収益化P0][1人目獲得] 最初の対象ユーザー像と10名リストを作る']::text[]
      ),
      (
        '[追加要望][収益化P0][1人目獲得] 公開投稿1本と導線クリックを確認',
        'Publish one honest build-in-public post or X post that drives people to /subscription-billing or the most relevant public entry page. Track whether at least one person clicks or replies.',
        'user',
        'user',
        'pending',
        0,
        DATE '2026-06-27',
        DATE '2026-06-28',
        'high',
        'Publish one public post after confirming account-status risk wording. If Stripe payouts are paused, ask for feedback/early access first and supporter payment later.',
        'If posting is not possible, prepare the post-ready copy and manually send it to at least 3 direct contacts.',
        ARRAY['[追加要望][収益化P0][1人目獲得] 最初の対象ユーザー像と10名リストを作る']::text[]
      ),
      (
        '[追加要望][収益化P0][1人目獲得] 初回ユーザーの利用証跡とヒアリングを取得',
        'After one real person uses the site or agrees to support, capture evidence: route used, what problem they wanted solved, what confused them, and whether they would pay/support after Stripe status clears.',
        'codex',
        'codex',
        'pending',
        0,
        DATE '2026-06-28',
        DATE '2026-06-29',
        'high',
        'Record one real user/supporter candidate outcome in the WBS/review doc. Do not fabricate usage or testimonials.',
        'If the first user bounces, record the objection and update copy/CTA before the next 10-touch sprint.',
        ARRAY['[追加要望][収益化P0][1人目獲得] 1対1アウトリーチ10件を実施']::text[]
      ),
      (
        '[追加要望][収益化P0][1人目獲得] Stripe解除後に初回支援決済へ転換',
        'Once Stripe identity review and payout pause are clear, ask the first interested user/supporter candidate to complete the 100 JPY Founding Supporter Checkout. Then verify webhook and payout evidence.',
        'user',
        'user',
        'pending',
        0,
        DATE '2026-06-29',
        DATE '2026-07-02',
        'high',
        'Do not self-pay in live mode. Convert a real supporter/customer after Stripe account status clears. Then run the webhook evidence SQL.',
        'If the candidate will not pay, ask why, log the objection, and return to the 10-touch direct outreach sprint.',
        ARRAY[
          '[追加要望][収益化P0] Stripe本人確認・入金停止解除',
          '[追加要望][収益化P0][1人目獲得] 初回ユーザーの利用証跡とヒアリングを取得'
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
  '追加要望 / first-user-acquisition',
  'person_add',
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
FROM first_user_tasks
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
  progress = GREATEST(progress, 20),
  remaining_work =
    'First-user acquisition has been split into concrete P0 tasks: target list, 10 direct outreach touches, one public post, first-user evidence/interview, and payment conversion after Stripe payout status clears.',
  recovery_plan =
    'Do not wait for passive SEO. Execute the direct outreach sprint while keeping paid conversion gated until Stripe account status clears.',
  depends_on_titles = ARRAY[
    '[追加要望][収益化P0][1人目獲得] 最初の対象ユーザー像と10名リストを作る',
    '[追加要望][収益化P0][1人目獲得] 1対1アウトリーチ10件を実施',
    '[追加要望][収益化P0][1人目獲得] 公開投稿1本と導線クリックを確認'
  ]::text[],
  updated_at = now()
WHERE title = '[追加要望][収益化P0] 初回購入者獲得スプリント'
  AND status <> 'completed';
