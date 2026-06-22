-- 1) 表示モード実験の全体集計関数 (個人特定情報を返さない集計のみ)
--    クライアントは supabase.rpc('display_mode_experiment_summary') で取得。
create or replace function public.display_mode_experiment_summary()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'initial_minimum',
      count(*) filter (where event_type = 'initial' and mode = 'minimum'),
    'initial_standard',
      count(*) filter (where event_type = 'initial' and mode = 'standard'),
    'initial_full',
      count(*) filter (where event_type = 'initial' and mode = 'full'),
    'switch_total', count(*) filter (where event_type = 'switch'),
    'standard_retained', (
      select count(*)
      from display_mode_events i
      where i.event_type = 'initial' and i.mode = 'standard'
        and not exists (
          select 1 from display_mode_events s
          where s.user_id = i.user_id
            and s.event_type = 'switch'
            and s.created_at > i.created_at
        )
    )
  )
  from display_mode_events;
$$;

revoke all on function public.display_mode_experiment_summary() from public;
revoke all on function public.display_mode_experiment_summary() from anon;
grant execute on function public.display_mode_experiment_summary()
  to authenticated;

-- 2) 入金予定のバックアップミラー (#3246 関連 / v1 は書き込みミラーのみ、
--    読み込みは端末ローカルを正とする。復元・マージは別Issueで対応)
create table if not exists public.asset_expected_inflow_items (
  id text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('one_time', 'rule')),
  date date,
  day_of_month integer check (day_of_month between 1 and 31),
  amount numeric not null check (amount > 0),
  label text not null default '',
  updated_at timestamptz not null default now()
);

create index if not exists asset_expected_inflow_items_user_idx
  on public.asset_expected_inflow_items (user_id);

alter table public.asset_expected_inflow_items enable row level security;

drop policy if exists "asset_expected_inflow_items_own_all"
  on public.asset_expected_inflow_items;
create policy "asset_expected_inflow_items_own_all"
  on public.asset_expected_inflow_items
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
