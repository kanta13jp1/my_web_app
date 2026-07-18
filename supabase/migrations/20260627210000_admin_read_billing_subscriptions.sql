-- Admin-only paid conversion aggregate for AdminAnalyticsPage.
-- Keeps billing_subscriptions row-level data behind RLS and exposes only
-- count/MRR after the caller is confirmed via public.is_user_admin().

CREATE OR REPLACE FUNCTION public.get_billing_paid_conversion_summary()
RETURNS TABLE (
  paid_customers integer,
  mrr_yen integer
)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT
    CASE
      WHEN public.is_user_admin(auth.uid()) THEN COUNT(*)::integer
      ELSE 0
    END AS paid_customers,
    CASE
      WHEN public.is_user_admin(auth.uid()) THEN COALESCE(
        SUM(
          CASE tier
            WHEN 'pro' THEN 980
            WHEN 'team' THEN 2980
            ELSE 0
          END
        ),
        0
      )::integer
      ELSE 0
    END AS mrr_yen
  FROM public.billing_subscriptions
  WHERE status = 'active'
    AND tier IN ('pro', 'team');
$$;

REVOKE ALL ON FUNCTION public.get_billing_paid_conversion_summary()
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_billing_paid_conversion_summary()
  TO authenticated;
