-- Nonfinancial observations only. No trigger modifies wealth_struggles or balances.
create table public.asset_calendar_reflections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  source_key text not null check (length(source_key) between 1 and 200),
  occurred_on date not null,
  kinds text[] not null check (cardinality(kinds) between 1 and 4 and kinds <@ array['dining','drinkingOut','alcoholPurchase','reading']::text[]),
  title text not null check (length(title) between 1 and 200),
  source_label text not null check (length(source_label) between 1 and 200),
  memo text not null default '' check (length(memo) <= 2000),
  verified_amount numeric(12,2) check (verified_amount between 0 and 100000000),
  alcohol_amount numeric(12,2) check (alcohol_amount between 0 and 100000000),
  pages integer check (pages between 0 and 1000000),
  minutes integer check (minutes between 0 and 1000000),
  linked_flow_id uuid,
  created_at timestamptz not null default now(),
  unique(user_id, source_key),
  check (verified_amount is null or alcohol_amount is null or alcohol_amount <= verified_amount),
  check ('reading' = any(kinds) or (pages is null and minutes is null))
);
create index asset_calendar_reflections_user_date_idx
  on public.asset_calendar_reflections(user_id, occurred_on, source_key);
alter table public.asset_calendar_reflections enable row level security;
revoke all on public.asset_calendar_reflections from anon;
grant select, insert, update, delete on public.asset_calendar_reflections to authenticated;
create policy reflection_select on public.asset_calendar_reflections for select to authenticated
  using ((select auth.uid()) = user_id);
create policy reflection_insert on public.asset_calendar_reflections for insert to authenticated
  with check ((select auth.uid()) = user_id and (linked_flow_id is null or exists (
    select 1 from public.wealth_struggles f where f.id = linked_flow_id and f.user_id = (select auth.uid())
  )));
create policy reflection_update on public.asset_calendar_reflections for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id and (linked_flow_id is null or exists (
    select 1 from public.wealth_struggles f where f.id = linked_flow_id and f.user_id = (select auth.uid())
  )));
create policy reflection_delete on public.asset_calendar_reflections for delete to authenticated
  using ((select auth.uid()) = user_id);
comment on table public.asset_calendar_reflections is
  'User-confirmed diary/receipt/reading observations; amounts are reference metadata, never financial postings.';
