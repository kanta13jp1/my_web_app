-- PII-free first-yen revenue evidence.
-- A payment is only a goal candidate when it is paid, linked to a signed-in
-- non-admin account, and attributed to the unknown-user X acquisition path.
-- This deliberately exposes no email, UUID, or full Stripe identifier.

with supporter_payments as (
  select
    id as payment_record_id,
    created_at,
    metadata ->> 'payment_status' as payment_status,
    case
      when coalesce(metadata ->> 'amount_jpy', '') ~ '^[0-9]+$'
        then (metadata ->> 'amount_jpy')::integer
      else 0
    end as amount_jpy,
    metadata ->> 'buyer_classification' as buyer_classification,
    case
      when coalesce(metadata ->> 'auth_user_id', '')
        ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then (metadata ->> 'auth_user_id')::uuid
      else null
    end as auth_user_id,
    metadata ->> 'utm_source' as utm_source,
    metadata ->> 'utm_medium' as utm_medium,
    metadata ->> 'utm_campaign' as utm_campaign,
    metadata ->> 'utm_content' as utm_content
  from public.hub_data
  where source = 'stripe_supporter_payment'
),
external_candidates as (
  select *
  from supporter_payments
  where payment_status = 'paid'
    and buyer_classification = 'authenticated_non_admin'
    and auth_user_id is not null
    and utm_source = 'x'
    and utm_campaign = 'first_user_growth'
),
activated_candidate_payments as (
  select
    payment.payment_record_id,
    payment.auth_user_id
  from external_candidates as payment
  join public.first_user_acquisition_events as acquisition
    on acquisition.auth_user_id = payment.auth_user_id
   and acquisition.utm_source = 'x'
   and acquisition.utm_medium = payment.utm_medium
   and acquisition.utm_campaign = 'first_user_growth'
   and acquisition.utm_content = payment.utm_content
   and acquisition.stage in ('signup_complete', 'first_action_completed')
   and acquisition.first_occurred_at <= payment.created_at
  group by payment.payment_record_id, payment.auth_user_id
  having bool_or(acquisition.stage = 'signup_complete')
     and bool_or(acquisition.stage = 'first_action_completed')
)
select
  count(*) filter (where payment_status = 'paid') as all_paid_records,
  coalesce(sum(amount_jpy) filter (where payment_status = 'paid'), 0)
    as all_paid_jpy,
  count(*) filter (where buyer_classification = 'admin_self')
    as excluded_admin_records,
  count(*) filter (where buyer_classification = 'anonymous_unclassified')
    as excluded_unclassified_records,
  (select count(*) from external_candidates) as external_candidate_records,
  coalesce((select sum(amount_jpy) from external_candidates), 0)
    as external_candidate_jpy,
  (select count(*) from activated_candidate_payments)
    as activated_external_candidate_payments,
  (select count(distinct auth_user_id) from activated_candidate_payments)
    as activated_external_candidate_users,
  (select min(created_at) from external_candidates)
    as first_external_candidate_paid_at,
  (select count(distinct utm_content) from external_candidates)
    as converting_utm_contents
from supporter_payments;
