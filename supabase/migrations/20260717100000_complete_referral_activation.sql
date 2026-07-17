-- Complete activation-gated referrals only after a paid subscription checkout.
-- The counter refresh lives in the same transaction so webhook retries remain
-- idempotent and the referral dashboard cannot drift from referral row state.

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
  v_referrer_user_id uuid;
  v_completed_at timestamptz := now();
begin
  select referral.referrer_user_id
    into v_referrer_user_id
  from public.referrals as referral
  where referral.referred_user_id = p_referred_user_id
    and referral.status in ('pending', 'pending_activation', 'completed')
  for update;

  if not found or v_referrer_user_id is null then
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
        'activated_at', v_completed_at,
        'stripe_checkout_session_id', nullif(
          btrim(p_stripe_checkout_session_id),
          ''
        )
      ))
  where referral.referred_user_id = p_referred_user_id
    and referral.status in ('pending', 'pending_activation');

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

comment on function public.complete_referral_activation(uuid, text, text) is
  'Idempotently completes a referred user activation and refreshes referrer counters after a paid checkout.';
