\set ON_ERROR_STOP on
create role authenticated nologin nobypassrls;
create schema auth;
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
grant usage on schema auth to authenticated;
create table public.wealth_struggles (
  id integer primary key,
  action_type text,
  amount integer not null check(amount>0),
  user_id uuid not null,
  constraint wealth_struggles_action_type_check check (
    action_type in ('defend','conquer','invest','expense','transfer')
  )
);
alter table public.wealth_struggles enable row level security;
create policy fixture_owner on public.wealth_struggles for all
  using (auth.uid()=user_id);
grant select,insert,update,delete on public.wealth_struggles to authenticated;
create temporary table policy_before as
  select polname,polcmd,polroles,polqual::text,polwithcheck::text
  from pg_policy where polrelid='public.wealth_struggles'::regclass;
\ir ../../supabase/migrations/20261024024312_wealth_struggles_borrowing_receipt.sql
\ir BORROWING_VERSION_POLICY_REVIEW.sql
insert into public.wealth_struggles values
  (1,'borrowing',10000,'00000000-0000-0000-0000-000000000001'),
  (2,'expense',330,'00000000-0000-0000-0000-000000000001'),
  (3,'borrowing',20000,'00000000-0000-0000-0000-000000000002'),
  (4,'expense',500,'00000000-0000-0000-0000-000000000002'),
  (7,null,1,'00000000-0000-0000-0000-000000000001');
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select set_config('request.headers','',true);
do $$
declare affected integer;
begin
  if (select array_agg(id order by id) from public.wealth_struggles) <> array[2,7] then
    raise exception 'Legacy owner visibility incorrect';
  end if;
  update public.wealth_struggles set action_type='expense' where id=1;
  get diagnostics affected=row_count;
  if affected<>0 then raise exception 'Legacy borrowing update accepted'; end if;
  delete from public.wealth_struggles where id=1;
  get diagnostics affected=row_count;
  if affected<>0 then raise exception 'Legacy borrowing delete accepted'; end if;
  begin
    insert into public.wealth_struggles values
      (5,'borrowing',1,'00000000-0000-0000-0000-000000000001');
    raise exception 'Legacy borrowing insert accepted';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.wealth_struggles set action_type='borrowing' where id=2;
    raise exception 'Legacy conversion to borrowing accepted';
  exception when insufficient_privilege then null;
  end;
  update public.wealth_struggles set amount=331 where id=2;
  if not exists(select 1 from public.wealth_struggles where id=2 and amount=331) then
    raise exception 'Existing expense edit regressed';
  end if;
  raise notice 'PASS: legacy borrowing hidden/updates and deletes affect zero/insert rejected; existing and null types preserved';
end;
$$;
select set_config('request.headers','{"x-asset-flow-version":"wrong"}',true);
do $$ begin
  if exists(select 1 from public.wealth_struggles where id=1) then
    raise exception 'Wrong version exposed borrowing';
  end if;
end; $$;
select set_config('request.headers','{"x-asset-flow-version":"borrowing-v1"}',true);
do $$
declare affected integer;
begin
  if not exists(select 1 from public.wealth_struggles where id=1 and action_type='borrowing' and amount=10000) then
    raise exception 'Compatible owner cannot read preserved borrowing';
  end if;
  update public.wealth_struggles set amount=10001 where id=1;
  update public.wealth_struggles set action_type='conquer' where id=1;
  if not exists(select 1 from public.wealth_struggles where id=1 and action_type='conquer') then
    raise exception 'Legitimate type correction rejected';
  end if;
  update public.wealth_struggles set action_type='borrowing' where id=1;
  insert into public.wealth_struggles values
    (5,'borrowing',1,'00000000-0000-0000-0000-000000000001');
  delete from public.wealth_struggles where id=5;
  get diagnostics affected=row_count;
  if affected<>1 then raise exception 'Compatible owner deletion regressed'; end if;
  if exists(select 1 from public.wealth_struggles where id in (3,4)) then
    raise exception 'Compatible header bypassed ownership';
  end if;
  update public.wealth_struggles set amount=1 where id=3;
  get diagnostics affected=row_count;
  if affected<>0 then raise exception 'Other owner update accepted'; end if;
  delete from public.wealth_struggles where id=3;
  get diagnostics affected=row_count;
  if affected<>0 then raise exception 'Other owner delete accepted'; end if;
  begin
    update public.wealth_struggles set user_id='00000000-0000-0000-0000-000000000002' where id=1;
    raise exception 'Owner reassignment accepted';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.wealth_struggles values
      (6,'borrowing',1,'00000000-0000-0000-0000-000000000002');
    raise exception 'Other owner insert accepted';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS: compatible owner CRUD and type correction allowed; other-owner access/reassignment denied';
end;
$$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
select set_config('request.headers','{}',true);
do $$ begin
  if (select array_agg(id order by id) from public.wealth_struggles) <> array[4] then
    raise exception 'Header/owner transaction changes leaked visibility';
  end if;
end; $$;
reset role;
do $$ begin
  if exists(
    (select * from policy_before except
     select polname,polcmd,polroles,polqual::text,polwithcheck::text
     from pg_policy where polrelid='public.wealth_struggles'::regclass
       and polname='fixture_owner')
    union all
    (select polname,polcmd,polroles,polqual::text,polwithcheck::text
     from pg_policy where polrelid='public.wealth_struggles'::regclass
       and polname='fixture_owner' except select * from policy_before)
  ) then raise exception 'Original ownership policy changed'; end if;
  if (select rolbypassrls from pg_roles where rolname='authenticated') then
    raise exception 'Test role bypassed RLS';
  end if;
  raise notice 'PASS: existing ownership policy unchanged; tests used non-bypass role';
end; $$;
rollback;
