-- #2584: 危機管理および事前防災インテークモジュール用スキーマ構築
-- リスク評価テーブル (public.crisis_risks) と対策プランテーブル (public.mitigation_plans) を作成し、
-- 所有者限定の厳格な RLS を有効化する。

create table if not exists public.crisis_risks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(btrim(title)) > 0),
  category text not null check (
    category in ('natural_disaster','infra_outage','security','supply_chain','operations')
  ),
  severity text not null check (severity in ('low','medium','high','critical')),
  likelihood integer not null default 3 check (likelihood between 1 and 5),
  impact integer not null default 3 check (impact between 1 and 5),
  status text not null default 'monitoring' check (status in ('monitoring','mitigating','resolved')),
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_crisis_risks_user_severity
  on public.crisis_risks (user_id, severity, updated_at desc);

create table if not exists public.mitigation_plans (
  id uuid primary key default gen_random_uuid(),
  risk_id uuid not null references public.crisis_risks(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  action_title text not null check (char_length(btrim(action_title)) > 0),
  owner_role text not null default '',
  trigger_condition text not null default '',
  offline_priority integer not null default 1 check (offline_priority between 1 and 5),
  is_offline_essential boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists idx_mitigation_plans_user_offline
  on public.mitigation_plans (user_id, is_offline_essential, offline_priority asc);

create index if not exists idx_mitigation_plans_risk_id
  on public.mitigation_plans (risk_id);

alter table public.crisis_risks enable row level security;
alter table public.mitigation_plans enable row level security;

revoke all on table public.crisis_risks from anon, authenticated;
revoke all on table public.mitigation_plans from anon, authenticated;

grant select, insert, update, delete on table public.crisis_risks to authenticated;
grant select, insert, update, delete on table public.mitigation_plans to authenticated;

grant all on table public.crisis_risks to service_role;
grant all on table public.mitigation_plans to service_role;

drop policy if exists "Users can view own crisis risks"
  on public.crisis_risks;
create policy "Users can view own crisis risks"
  on public.crisis_risks
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert own crisis risks"
  on public.crisis_risks;
create policy "Users can insert own crisis risks"
  on public.crisis_risks
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update own crisis risks"
  on public.crisis_risks;
create policy "Users can update own crisis risks"
  on public.crisis_risks
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete own crisis risks"
  on public.crisis_risks;
create policy "Users can delete own crisis risks"
  on public.crisis_risks
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can view own mitigation plans"
  on public.mitigation_plans;
create policy "Users can view own mitigation plans"
  on public.mitigation_plans
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert own mitigation plans"
  on public.mitigation_plans;
create policy "Users can insert own mitigation plans"
  on public.mitigation_plans
  for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1
      from public.crisis_risks r
      where r.id = risk_id
        and r.user_id = (select auth.uid())
    )
  );

drop policy if exists "Users can update own mitigation plans"
  on public.mitigation_plans;
create policy "Users can update own mitigation plans"
  on public.mitigation_plans
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1
      from public.crisis_risks r
      where r.id = risk_id
        and r.user_id = (select auth.uid())
    )
  );

drop policy if exists "Users can delete own mitigation plans"
  on public.mitigation_plans;
create policy "Users can delete own mitigation plans"
  on public.mitigation_plans
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

comment on table public.crisis_risks is
  '平時リスク評価および危機管理対象項目（発生確率・影響度・深刻度付き / #2584）。';
comment on table public.mitigation_plans is
  '各リスクに対応する事前防災・初動対応プラン（災害時オフラインキャッシュ対象優先度付き / #2584）。';
