-- 「締め切りの重さ」(/deadline-weight)
--
-- ADHD 傾向の脳は遠い締め切りを「身体的な重さを伴う脅威」として認識しにくい
-- (時間盲目性 / 時間的近視眼)。本機能は締め切りを日数ではなく
-- 「実際に手を動かせる残り時間 = 可処分時間」に換算して体感に近づける。
--
-- deadline_weight_items    : 体感したい締め切り (タイトル / 期日 / 必要時間)
-- deadline_weight_settings : 曜日ごとの可処分時間 (1 ユーザー 1 行)
--
-- どちらもオーナー本人しか読み書きしない個人データのため RLS で user_id に閉じる。

begin;

create table public.deadline_weight_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  due_on date not null,
  required_minutes integer not null,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint deadline_weight_items_title_length
    check (length(btrim(title)) between 1 and 120),
  constraint deadline_weight_items_required_minutes_range
    check (required_minutes between 1 and 60000)
);

create index deadline_weight_items_user_due_idx
  on public.deadline_weight_items (user_id, due_on, id);

create index deadline_weight_items_user_open_idx
  on public.deadline_weight_items (user_id, due_on)
  where completed_at is null;

comment on table public.deadline_weight_items is
  'Owner-scoped deadlines rendered as remaining disposable time instead of calendar days.';
comment on column public.deadline_weight_items.due_on is
  'Due date in the owner local calendar. Time of day is intentionally not stored.';
comment on column public.deadline_weight_items.required_minutes is
  'Owner estimate of hands-on minutes still needed, capped at 1000 hours.';
comment on column public.deadline_weight_items.completed_at is
  'Set when the owner marks the deadline done. Open items keep this null.';

-- 曜日ごとの可処分時間。DateTime.weekday (月=1 .. 日=7) に合わせて列を持つ。
-- 配列にすると CHECK で要素範囲を検証できない (CHECK は副問い合わせ不可) ため列に展開する。
create table public.deadline_weight_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  monday_minutes integer not null default 120,
  tuesday_minutes integer not null default 120,
  wednesday_minutes integer not null default 120,
  thursday_minutes integer not null default 120,
  friday_minutes integer not null default 120,
  saturday_minutes integer not null default 300,
  sunday_minutes integer not null default 300,
  updated_at timestamptz not null default now(),
  constraint deadline_weight_settings_monday_range
    check (monday_minutes between 0 and 1440),
  constraint deadline_weight_settings_tuesday_range
    check (tuesday_minutes between 0 and 1440),
  constraint deadline_weight_settings_wednesday_range
    check (wednesday_minutes between 0 and 1440),
  constraint deadline_weight_settings_thursday_range
    check (thursday_minutes between 0 and 1440),
  constraint deadline_weight_settings_friday_range
    check (friday_minutes between 0 and 1440),
  constraint deadline_weight_settings_saturday_range
    check (saturday_minutes between 0 and 1440),
  constraint deadline_weight_settings_sunday_range
    check (sunday_minutes between 0 and 1440)
);

comment on table public.deadline_weight_settings is
  'Per-owner weekday budget of hands-on minutes, used to convert deadlines into felt time.';

alter table public.deadline_weight_items enable row level security;
alter table public.deadline_weight_settings enable row level security;

revoke all privileges on table public.deadline_weight_items
from public, anon, authenticated;
revoke all privileges on table public.deadline_weight_settings
from public, anon, authenticated;

grant all privileges on table public.deadline_weight_items to service_role;
grant all privileges on table public.deadline_weight_settings to service_role;

grant select, insert, update, delete
  on table public.deadline_weight_items to authenticated;
grant select, insert, update, delete
  on table public.deadline_weight_settings to authenticated;

create policy deadline_weight_items_select_own
  on public.deadline_weight_items
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy deadline_weight_items_insert_own
  on public.deadline_weight_items
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy deadline_weight_items_update_own
  on public.deadline_weight_items
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy deadline_weight_items_delete_own
  on public.deadline_weight_items
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

create policy deadline_weight_settings_select_own
  on public.deadline_weight_settings
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy deadline_weight_settings_insert_own
  on public.deadline_weight_settings
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy deadline_weight_settings_update_own
  on public.deadline_weight_settings
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy deadline_weight_settings_delete_own
  on public.deadline_weight_settings
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

insert into public.feature_releases (
  feature_route,
  feature_label,
  description,
  released_at,
  category
)
select
  '/deadline-weight',
  '締め切りの重さ',
  '締め切りを残り日数ではなく「手を動かせる残り時間」に換算して体感に変える',
  now(),
  'productivity'
where not exists (
  select 1
  from public.feature_releases
  where feature_route = '/deadline-weight'
);

commit;
