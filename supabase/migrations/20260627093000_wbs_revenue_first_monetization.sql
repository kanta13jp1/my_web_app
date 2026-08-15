-- Revenue-first monetization WBS registration.
-- User request (2026-06-27 JST): make monetization the top priority and keep
-- working until an actual bank payout of at least 1 JPY can be confirmed.
--
-- Source review before registration:
-- - Existing WBS already has "決済導入 (Stripe)" but it was scheduled for Q3.
-- - Existing implementation already has:
--   - lib/pages/subscription_billing_page.dart
--   - lib/services/billing_service.dart
--   - supabase/functions/schedule-hub billing.* actions
--   - supabase/functions/stripe-webhook
--   - billing_subscriptions / billing_usage_counters tables
-- - Remaining risk is production readiness: live Stripe account, bank payout,
--   legal display, live secrets, live checkout/webhook proof, and first buyer.

INSERT INTO public.wbs_milestones
  (code, name, target_date, goal_users, description, color)
VALUES
  (
    'first-yen-revenue',
    '初回実入金確認',
    DATE '2026-07-10',
    1,
    'サイト収益化の最初の実績。Stripe等で初回決済を成立させ、Stripe残高ではなく銀行口座への入金が1円以上あることを確認する。',
    '#16A34A'
  )
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  target_date = EXCLUDED.target_date,
  goal_users = EXCLUDED.goal_users,
  description = EXCLUDED.description,
  color = EXCLUDED.color;

WITH revenue_tasks AS (
  SELECT *
  FROM (
    VALUES
      (
        '[追加要望][収益化P0] Stripe本番・銀行入金レディネス確認',
        'Stripe live mode、本人確認/事業者情報、銀行口座、live Product/Price、Webhook endpoint、Supabase secrets、特商法/利用規約/プライバシー表記を確認し、1円以上の銀行入金を受けられる前提を作る。',
        'user',
        'user',
        'in_progress',
        10,
        DATE '2026-06-27',
        DATE '2026-06-27',
        'high',
        'CEO/user action is required for external accounts and bank verification. Codex can verify code paths and prepare exact configuration checklist, but cannot access or confirm the bank account directly.',
        'If live Stripe or bank verification is not available, create the checklist and block only the external-account step; keep code-side checkout and webhook validation moving in parallel.',
        ARRAY[]::text[]
      ),
      (
        '[追加要望][収益化P0] Live Checkout + Webhook 証跡を本番で取得',
        'subscription-billing -> schedule-hub billing.create_checkout_session -> Stripe Checkout -> stripe-webhook -> billing_subscriptions の本番経路を、少額の実決済または本番準備済みテストで検証する。受け入れ条件: checkout URL発行、決済成功、webhook署名検証、tier更新、画面反映の証跡が揃う。',
        'codex',
        'codex',
        'pending',
        0,
        DATE '2026-06-27',
        DATE '2026-06-28',
        'high',
        'Needs live/test credentials from the Stripe readiness task. Add any missing deterministic tests around BillingService and stripe-webhook before declaring production-ready.',
        'If live payment cannot run, complete test-mode proof and leave one explicit user handoff for live-mode secret/product/webhook values.',
        ARRAY['[追加要望][収益化P0] Stripe本番・銀行入金レディネス確認']::text[]
      ),
      (
        '[追加要望][収益化P0] Founding Supporter 有料CTAを公開',
        '現在のLP/SEO文言は「完全無料」が強く、課金画面と矛盾する。ログイン不要のFounding Supporter一回払いCTA、またはPro月額CTAを公開し、無料MVPの価値訴求と支払い導線を両立させる。',
        'codex',
        'codex',
        'pending',
        0,
        DATE '2026-06-27',
        DATE '2026-06-28',
        'high',
        'Update public copy so paid checkout is discoverable without misleading users. Keep claims honest: no fabricated users, revenue, certifications, or guarantees. Prefer the public one-time supporter checkout for the first-revenue sprint.',
        'If pricing is not CEO-final, publish as Founding Supporter / early access with explicit terms and keep refundable/fulfillment language clear.',
        ARRAY['[追加要望][収益化P0] Stripe本番・銀行入金レディネス確認']::text[]
      ),
      (
        '[追加要望][収益化P0] 初回購入者獲得スプリント',
        '実収益を得るため、既存のX/ブログ/紹介/直送導線から初回購入者を1人獲得する。受け入れ条件: 支払いリンクまたはsubscription-billing URLつきの告知/DM/記事を公開し、少なくとも10件の具体的な接触ログを残す。',
        'ps2',
        'ps2',
        'pending',
        0,
        DATE '2026-06-28',
        DATE '2026-06-30',
        'high',
        'Promotion is required if organic traffic is not enough. External posting must use approved copy and configured credentials; do not auto-post without CEO confirmation.',
        'If social credentials are unavailable, prepare post-ready drafts and a contact list so the CEO can publish manually.',
        ARRAY['[追加要望][収益化P0] Founding Supporter 有料CTAを公開']::text[]
      ),
      (
        '[追加要望][収益化P0] 銀行口座への1円以上入金を確認',
        'セッションゴールの完了判定タスク。Stripe等の決済残高ではなく、実際の銀行口座明細で1円以上の入金を確認する。受け入れ条件: 決済ID、出金/入金予定日、銀行入金額、確認日をWBS/証跡に記録する。',
        'user',
        'user',
        'pending',
        0,
        DATE '2026-06-30',
        DATE '2026-07-10',
        'high',
        'Bank statement confirmation requires the CEO/user. Codex can reconcile IDs and record evidence text, but cannot access private bank statements unless explicitly provided in-session.',
        'If payout schedule delays the bank deposit, keep this task active and update the expected payout date; do not mark complete from Stripe balance alone.',
        ARRAY['[追加要望][収益化P0] Live Checkout + Webhook 証跡を本番で取得', '[追加要望][収益化P0] 初回購入者獲得スプリント']::text[]
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
  '追加要望 / business-revenue',
  '$',
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
FROM revenue_tasks
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
  instance = 'codex',
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = CASE WHEN status = 'completed' THEN progress ELSE GREATEST(progress, 65) END,
  start_date = DATE '2026-06-27',
  end_date = DATE '2026-06-28',
  milestone_code = 'first-yen-revenue',
  priority = 'high',
  remaining_work =
    'Existing subscription code exists, and a public Founding Supporter one-time Checkout path is now prepared. Production proof is not complete: live Stripe account, Product/Price IDs where needed, Supabase secrets, webhook URL, live checkout, webhook tier/supporter evidence, paid CTA, and bank payout confirmation remain.',
  recovery_plan =
    'Revenue-first reprioritization: prove live checkout/webhook first, then publish a paid CTA and acquire the first paying user. Keep this task open until the implementation is production-proven, not merely coded.',
  depends_on_titles = ARRAY[
    '[追加要望][収益化P0] Stripe本番・銀行入金レディネス確認',
    '[追加要望][収益化P0] Live Checkout + Webhook 証跡を本番で取得'
  ]::text[],
  updated_at = now()
WHERE title = '決済導入 (Stripe)'
  AND status <> 'completed';

UPDATE public.wbs_tasks
SET
  category_order = 0,
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = CASE WHEN status = 'completed' THEN progress ELSE GREATEST(progress, 80) END,
  start_date = DATE '2026-06-27',
  end_date = DATE '2026-06-27',
  milestone_code = 'first-yen-revenue',
  priority = 'high',
  remaining_work =
    'Pricing copy and product amounts exist in docs/code, but CEO-final public terms must match the paid CTA before charging real users.',
  recovery_plan =
    'Use the current Pro/Team amounts as the default unless the CEO changes them; do not block first revenue on a large pricing redesign.',
  updated_at = now()
WHERE title = '料金プラン v1.0 確定'
  AND status <> 'completed';
