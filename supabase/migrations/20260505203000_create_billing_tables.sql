-- Billing foundation for Stripe freemium rollout (#1305).

create table if not exists public.billing_subscriptions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  stripe_customer_id text unique,
  stripe_subscription_id text unique,
  tier text not null default 'free' check (tier in ('free', 'pro', 'team')),
  status text not null default 'active'
    check (status in ('active', 'past_due', 'canceled', 'trialing', 'incomplete')),
  current_period_end timestamptz,
  cancel_at_period_end boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.billing_usage_counters (
  user_id uuid references auth.users(id) on delete cascade,
  period_start date not null,
  ai_query_count integer not null default 0 check (ai_query_count >= 0),
  ef_call_count integer not null default 0 check (ef_call_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, period_start)
);

create index if not exists billing_subscriptions_customer_idx
  on public.billing_subscriptions (stripe_customer_id);

create index if not exists billing_subscriptions_subscription_idx
  on public.billing_subscriptions (stripe_subscription_id);

create or replace function public.set_billing_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists billing_subscriptions_updated_at
  on public.billing_subscriptions;
create trigger billing_subscriptions_updated_at
before update on public.billing_subscriptions
for each row execute function public.set_billing_updated_at();

drop trigger if exists billing_usage_counters_updated_at
  on public.billing_usage_counters;
create trigger billing_usage_counters_updated_at
before update on public.billing_usage_counters
for each row execute function public.set_billing_updated_at();

alter table public.billing_subscriptions enable row level security;
alter table public.billing_usage_counters enable row level security;

drop policy if exists billing_sub_self_read on public.billing_subscriptions;
create policy billing_sub_self_read on public.billing_subscriptions
for select using (auth.uid() = user_id);

drop policy if exists billing_usage_self_read on public.billing_usage_counters;
create policy billing_usage_self_read on public.billing_usage_counters
for select using (auth.uid() = user_id);
