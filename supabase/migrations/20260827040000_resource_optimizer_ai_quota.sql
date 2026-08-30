-- Bound consented resource-optimizer AI calls per authenticated user.
create table if not exists public.resource_optimizer_ai_quota (
  user_id uuid not null,
  usage_date date not null,
  request_count integer not null,
  last_requested_at timestamptz not null,
  constraint resource_optimizer_ai_quota_pkey primary key (user_id, usage_date),
  constraint resource_optimizer_ai_quota_user_id_fkey
    foreign key (user_id) references auth.users(id) on delete cascade,
  constraint resource_optimizer_ai_quota_request_count_check
    check (request_count between 1 and 10)
);

alter table public.resource_optimizer_ai_quota
  add column if not exists user_id uuid,
  add column if not exists usage_date date,
  add column if not exists request_count integer,
  add column if not exists last_requested_at timestamptz;

-- A re-apply may need to normalize column types. PostgreSQL does not permit
-- ALTER TYPE while policies, triggers, or constraints depend on those
-- columns, even when the canonical type is already installed. Remove the
-- dependent objects first; they are recreated below in their exact form.
drop policy if exists "users_read_own_resource_optimizer_ai_quota"
  on public.resource_optimizer_ai_quota;
drop policy if exists "users_insert_own_resource_optimizer_ai_quota"
  on public.resource_optimizer_ai_quota;
drop policy if exists "users_update_own_resource_optimizer_ai_quota"
  on public.resource_optimizer_ai_quota;
drop trigger if exists validate_resource_optimizer_ai_quota_write
  on public.resource_optimizer_ai_quota;

alter table public.resource_optimizer_ai_quota
  drop constraint if exists resource_optimizer_ai_quota_request_count_check,
  drop constraint if exists resource_optimizer_ai_quota_user_id_fkey,
  drop constraint if exists resource_optimizer_ai_quota_pkey;

-- Fail loudly on unconvertible drift; otherwise converge compatible partial
-- definitions to the exact types consumed by the RLS policies and RPC.
alter table public.resource_optimizer_ai_quota
  alter column user_id type uuid using user_id::text::uuid,
  alter column usage_date type date using usage_date::text::date,
  alter column request_count type integer using request_count::text::integer,
  alter column last_requested_at type timestamptz
    using last_requested_at::text::timestamptz;

-- Quota rows are disposable enforcement state. Remove malformed partial rows
-- before restoring the canonical constraints on a re-applied migration.
delete from public.resource_optimizer_ai_quota as quota
where quota.user_id is null
  or quota.usage_date is null
  or quota.request_count is null
  or quota.request_count not between 1 and 10
  or quota.last_requested_at is null
  or not exists (
    select 1 from auth.users as users where users.id = quota.user_id
  );

delete from public.resource_optimizer_ai_quota as duplicate
using public.resource_optimizer_ai_quota as keeper
where duplicate.user_id = keeper.user_id
  and duplicate.usage_date = keeper.usage_date
  and duplicate.ctid < keeper.ctid;

alter table public.resource_optimizer_ai_quota
  alter column user_id drop default,
  alter column user_id set not null,
  alter column usage_date drop default,
  alter column usage_date set not null,
  alter column request_count drop default,
  alter column request_count set not null,
  alter column last_requested_at drop default,
  alter column last_requested_at set not null;

alter table public.resource_optimizer_ai_quota
  drop constraint if exists resource_optimizer_ai_quota_request_count_check,
  drop constraint if exists resource_optimizer_ai_quota_user_id_fkey,
  drop constraint if exists resource_optimizer_ai_quota_pkey;

alter table public.resource_optimizer_ai_quota
  add constraint resource_optimizer_ai_quota_pkey
    primary key (user_id, usage_date),
  add constraint resource_optimizer_ai_quota_user_id_fkey
    foreign key (user_id) references auth.users(id) on delete cascade,
  add constraint resource_optimizer_ai_quota_request_count_check
    check (request_count between 1 and 10);

alter table public.resource_optimizer_ai_quota enable row level security;
alter table public.resource_optimizer_ai_quota force row level security;

revoke all on table public.resource_optimizer_ai_quota
  from public, anon, authenticated;
grant select on table public.resource_optimizer_ai_quota to authenticated;
grant insert (user_id, usage_date, request_count, last_requested_at)
  on table public.resource_optimizer_ai_quota to authenticated;
grant update (request_count, last_requested_at)
  on table public.resource_optimizer_ai_quota to authenticated;

drop policy if exists "users_read_own_resource_optimizer_ai_quota"
  on public.resource_optimizer_ai_quota;
create policy "users_read_own_resource_optimizer_ai_quota"
  on public.resource_optimizer_ai_quota for select
  to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "users_insert_own_resource_optimizer_ai_quota"
  on public.resource_optimizer_ai_quota;
create policy "users_insert_own_resource_optimizer_ai_quota"
  on public.resource_optimizer_ai_quota for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and usage_date = (pg_catalog.timezone('UTC', pg_catalog.clock_timestamp()))::date
  );

drop policy if exists "users_update_own_resource_optimizer_ai_quota"
  on public.resource_optimizer_ai_quota;
create policy "users_update_own_resource_optimizer_ai_quota"
  on public.resource_optimizer_ai_quota for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create or replace function public.validate_resource_optimizer_ai_quota_write()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_now timestamptz := pg_catalog.clock_timestamp();
  v_today date := (pg_catalog.timezone('UTC', v_now))::date;
begin
  if new.user_id is distinct from (select auth.uid())
    or new.usage_date <> v_today
    or new.last_requested_at < v_now - interval '5 seconds'
    or new.last_requested_at > v_now + interval '5 seconds'
  then
    raise exception 'invalid resource optimizer quota write';
  end if;

  if tg_op = 'INSERT' and new.request_count <> 1 then
    raise exception 'invalid resource optimizer quota insert';
  end if;

  if tg_op = 'UPDATE' and (
    new.user_id is distinct from old.user_id
    or new.usage_date is distinct from old.usage_date
    or new.request_count <> old.request_count + 1
    or new.last_requested_at <= old.last_requested_at
  ) then
    raise exception 'invalid resource optimizer quota update';
  end if;

  return new;
end;
$$;

revoke all on function public.validate_resource_optimizer_ai_quota_write()
  from public, anon, authenticated;

drop trigger if exists validate_resource_optimizer_ai_quota_write
  on public.resource_optimizer_ai_quota;
create trigger validate_resource_optimizer_ai_quota_write
before insert or update on public.resource_optimizer_ai_quota
for each row execute function public.validate_resource_optimizer_ai_quota_write();

create or replace function public.consume_resource_optimizer_ai_quota()
returns table (
  allowed boolean,
  reason text,
  remaining_daily integer,
  retry_after_seconds integer
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_now timestamptz := pg_catalog.clock_timestamp();
  v_today date := (pg_catalog.timezone('UTC', v_now))::date;
  v_count integer;
  v_last_requested_at timestamptz;
begin
  if v_user_id is null then
    raise exception 'authentication required';
  end if;

  insert into public.resource_optimizer_ai_quota as quota (
    user_id,
    usage_date,
    request_count,
    last_requested_at
  )
  values (v_user_id, v_today, 1, v_now)
  on conflict (user_id, usage_date) do update
  set
    request_count = quota.request_count + 1,
    last_requested_at = v_now
  where quota.request_count < 10
    and quota.last_requested_at <= v_now - interval '60 seconds'
  returning request_count, last_requested_at
    into v_count, v_last_requested_at;

  if found then
    return query select true, 'allowed'::text, 10 - v_count, 0;
    return;
  end if;

  select quota.request_count, quota.last_requested_at
    into v_count, v_last_requested_at
  from public.resource_optimizer_ai_quota as quota
  where quota.user_id = v_user_id
    and quota.usage_date = v_today;

  if v_count >= 10 then
    return query select false, 'daily_limit'::text, 0, 0;
  else
    return query select
      false,
      'cooldown'::text,
      case when 10 - v_count > 0 then 10 - v_count else 0 end,
      case
        when pg_catalog.ceil(
          extract(epoch from (
            v_last_requested_at + interval '60 seconds' - v_now
          ))
        )::integer > 0
        then pg_catalog.ceil(
          extract(epoch from (
            v_last_requested_at + interval '60 seconds' - v_now
          ))
        )::integer
        else 0
      end;
  end if;
end;
$$;

revoke all on function public.consume_resource_optimizer_ai_quota()
  from public, anon, authenticated;
grant execute on function public.consume_resource_optimizer_ai_quota()
  to authenticated;

comment on function public.consume_resource_optimizer_ai_quota() is
  'Atomically consumes one consented resource-optimizer AI request for auth.uid(), with a 60-second cooldown and 10-request UTC daily limit.';
