-- Convert activation-gated referral points into an auditable Stripe credit
-- outbox. Stripe calls remain in the webhook; these RPCs only claim/finalize
-- short database transactions so external I/O never holds a row lock.
-- nocheck: time-relative -- UPDATE statements below are runtime RPC bodies;
-- this migration executes no data UPDATE while being applied or replayed.

create table if not exists public.referral_credit_grants (
  id bigint generated always as identity primary key,
  referral_id bigint not null
    references public.referrals(id) on delete cascade,
  beneficiary_user_id uuid not null
    references auth.users(id) on delete cascade,
  beneficiary_role text not null
    check (beneficiary_role in ('referrer', 'referred')),
  reward_points integer not null default 500
    check (reward_points > 0),
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'granted', 'failed')),
  stripe_idempotency_key text not null unique,
  stripe_customer_id text,
  stripe_balance_transaction_id text unique,
  credit_amount integer check (credit_amount is null or credit_amount > 0),
  currency text check (currency is null or currency ~ '^[a-z]{3}$'),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  last_attempt_at timestamptz,
  granted_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (referral_id, beneficiary_role)
);

create index if not exists referral_credit_grants_beneficiary_idx
  on public.referral_credit_grants (beneficiary_user_id, created_at desc);

create index if not exists referral_credit_grants_pending_idx
  on public.referral_credit_grants (referral_id, id)
  where status in ('pending', 'failed');

alter table public.referral_credit_grants enable row level security;

revoke all on table public.referral_credit_grants
  from public, anon, authenticated;
grant select, insert, update on table public.referral_credit_grants
  to service_role;
revoke all on sequence public.referral_credit_grants_id_seq
  from public, anon, authenticated;
grant usage, select on sequence public.referral_credit_grants_id_seq
  to service_role;

comment on table public.referral_credit_grants is
  'Service-role-only outbox for one-time Stripe invoice credits earned by referral activation.';

-- Recreate the existing activation RPC so the referral state transition and
-- both give-get outbox rows commit atomically. ON CONFLICT makes webhook
-- retries and already-completed historical referrals safe.
create or replace function public.complete_referral_activation(
  p_referred_user_id uuid,
  p_activation_source text default 'stripe_checkout_paid',
  p_stripe_checkout_session_id text default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_referral_id bigint;
  v_referrer_user_id uuid;
  v_completed_at timestamptz := now();
begin
  select referral.id, referral.referrer_user_id
    into v_referral_id, v_referrer_user_id
  from public.referrals as referral
  where referral.referred_user_id = p_referred_user_id
    and referral.status in ('pending', 'pending_activation', 'completed')
  for update;

  if not found or
    v_referrer_user_id is null or
    v_referrer_user_id = p_referred_user_id then
    return false;
  end if;

  update public.referrals as referral
  set
    status = 'completed',
    completed_at = coalesce(referral.completed_at, v_completed_at),
    metadata = coalesce(referral.metadata, '{}'::jsonb) ||
      jsonb_strip_nulls(jsonb_build_object(
        'activation_source', coalesce(
          nullif(btrim(p_activation_source), ''),
          'stripe_checkout_paid'
        ),
        'activated_at', coalesce(referral.completed_at, v_completed_at),
        'stripe_checkout_session_id', nullif(
          btrim(p_stripe_checkout_session_id),
          ''
        ),
        'stripe_credit_outbox', true
      ))
  where referral.id = v_referral_id
    and referral.status in ('pending', 'pending_activation');

  insert into public.referral_credit_grants (
    referral_id,
    beneficiary_user_id,
    beneficiary_role,
    stripe_idempotency_key
  )
  values
    (
      v_referral_id,
      v_referrer_user_id,
      'referrer',
      'referral-credit-' || v_referral_id::text || '-referrer'
    ),
    (
      v_referral_id,
      p_referred_user_id,
      'referred',
      'referral-credit-' || v_referral_id::text || '-referred'
    )
  on conflict (referral_id, beneficiary_role) do nothing;

  update public.referral_codes as code
  set
    total_referrals = (
      select count(*)::integer
      from public.referrals as referral
      where referral.referrer_user_id = v_referrer_user_id
    ),
    successful_referrals = (
      select count(*)::integer
      from public.referrals as referral
      where referral.referrer_user_id = v_referrer_user_id
        and referral.status = 'completed'
    ),
    bonus_points_earned = (
      select coalesce(sum(referral.bonus_points), 0)::integer
      from public.referrals as referral
      where referral.referrer_user_id = v_referrer_user_id
        and referral.status = 'completed'
    )
  where code.user_id = v_referrer_user_id;

  return true;
end;
$$;

revoke all on function public.complete_referral_activation(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.complete_referral_activation(uuid, text, text)
  to service_role;

create or replace function public.claim_next_referral_credit_grant(
  p_referred_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_grant public.referral_credit_grants%rowtype;
begin
  update public.referral_credit_grants as grant_row
  set
    status = 'processing',
    attempt_count = grant_row.attempt_count + 1,
    last_attempt_at = now(),
    last_error = null,
    updated_at = now()
  where grant_row.id = (
    select candidate.id
    from public.referral_credit_grants as candidate
    join public.referrals as referral
      on referral.id = candidate.referral_id
    where referral.referred_user_id = p_referred_user_id
      and candidate.status in ('pending', 'failed')
    order by candidate.id
    limit 1
    for update of candidate skip locked
  )
  returning grant_row.* into v_grant;

  if not found then
    return null;
  end if;

  return jsonb_build_object(
    'id', v_grant.id,
    'referral_id', v_grant.referral_id,
    'beneficiary_user_id', v_grant.beneficiary_user_id,
    'beneficiary_role', v_grant.beneficiary_role,
    'stripe_idempotency_key', v_grant.stripe_idempotency_key
  );
end;
$$;

revoke all on function public.claim_next_referral_credit_grant(uuid)
  from public, anon, authenticated;
grant execute on function public.claim_next_referral_credit_grant(uuid)
  to service_role;

create or replace function public.complete_referral_credit_grant(
  p_grant_id bigint,
  p_stripe_customer_id text,
  p_stripe_balance_transaction_id text,
  p_credit_amount integer,
  p_currency text
)
returns boolean
language sql
security definer
set search_path = ''
as $$
  with completed as (
    update public.referral_credit_grants as grant_row
    set
      status = 'granted',
      stripe_customer_id = nullif(btrim(p_stripe_customer_id), ''),
      stripe_balance_transaction_id = nullif(
        btrim(p_stripe_balance_transaction_id),
        ''
      ),
      credit_amount = p_credit_amount,
      currency = lower(nullif(btrim(p_currency), '')),
      granted_at = now(),
      last_error = null,
      updated_at = now()
    where grant_row.id = p_grant_id
      and grant_row.status = 'processing'
      and p_credit_amount > 0
      and lower(p_currency) ~ '^[a-z]{3}$'
    returning 1
  )
  select exists(select 1 from completed);
$$;

revoke all on function public.complete_referral_credit_grant(bigint, text, text, integer, text)
  from public, anon, authenticated;
grant execute on function public.complete_referral_credit_grant(bigint, text, text, integer, text)
  to service_role;

create or replace function public.fail_referral_credit_grant(
  p_grant_id bigint,
  p_error text
)
returns boolean
language sql
security definer
set search_path = ''
as $$
  with failed as (
    update public.referral_credit_grants as grant_row
    set
      status = 'failed',
      last_error = left(coalesce(p_error, 'unknown Stripe credit error'), 1000),
      updated_at = now()
    where grant_row.id = p_grant_id
      and grant_row.status = 'processing'
    returning 1
  )
  select exists(select 1 from failed);
$$;

revoke all on function public.fail_referral_credit_grant(bigint, text)
  from public, anon, authenticated;
grant execute on function public.fail_referral_credit_grant(bigint, text)
  to service_role;
