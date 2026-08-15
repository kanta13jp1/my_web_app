select
  id,
  created_at,
  metadata->>'payment_status' as payment_status,
  metadata->>'currency' as currency,
  (metadata->>'amount_total')::int as amount_jpy,
  metadata->>'stripe_checkout_session_id' as stripe_checkout_session_id,
  metadata->>'stripe_payment_intent_id' as stripe_payment_intent_id,
  metadata->>'stripe_customer_id' as stripe_customer_id,
  metadata->>'customer_email' as customer_email,
  metadata->>'milestone_code' as milestone_code
from public.hub_data
where source = 'stripe_supporter_payment'
order by created_at desc
limit 5;
