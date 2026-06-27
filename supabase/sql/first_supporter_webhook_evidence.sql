-- First-yen revenue evidence:
-- run after a real Founding Supporter checkout completes.

select
  id,
  created_at,
  metadata ->> 'payment_status' as payment_status,
  (metadata ->> 'amount_jpy')::integer as amount_jpy,
  metadata ->> 'currency' as currency,
  metadata ->> 'stripe_checkout_session_id' as stripe_checkout_session_id,
  metadata ->> 'stripe_payment_intent_id' as stripe_payment_intent_id,
  metadata ->> 'utm_source' as utm_source,
  metadata ->> 'utm_medium' as utm_medium,
  metadata ->> 'utm_campaign' as utm_campaign,
  metadata ->> 'utm_content' as utm_content,
  metadata ->> 'experiment_key' as experiment_key,
  metadata ->> 'variant' as variant,
  metadata ->> 'source_log_id' as source_log_id
from public.hub_data
where source = 'stripe_supporter_payment'
order by created_at desc
limit 20;
