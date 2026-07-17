-- Connect referral signups to later billing conversion without changing the
-- existing referral ownership model.

alter table public.referrals
  add column if not exists metadata jsonb not null default '{}'::jsonb;

create index if not exists idx_referrals_metadata_gin
  on public.referrals using gin (metadata jsonb_path_ops);

create index if not exists idx_referrals_referred_status
  on public.referrals (referred_user_id, status);

comment on column public.referrals.metadata is
  'Referral attribution metadata such as signup_signal, channel, and activation gate state.';
