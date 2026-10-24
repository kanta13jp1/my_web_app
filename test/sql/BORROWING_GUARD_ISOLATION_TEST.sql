\set ON_ERROR_STOP on
create table public.wealth_struggles (
  id integer primary key,
  action_type text not null,
  amount integer not null check (amount > 0),
  description text not null default '',
  user_id uuid not null default '00000000-0000-0000-0000-000000000001',
  constraint wealth_struggles_action_type_check check (
    action_type in ('defend', 'conquer', 'invest', 'expense', 'transfer')
  )
);
alter table public.wealth_struggles enable row level security;
create policy fixture_owner on public.wealth_struggles
  using (user_id = nullif(current_setting('fixture.user_id', true), '')::uuid);
create temporary table policy_before as
  select polname, polcmd, polroles, polqual::text, polwithcheck::text
  from pg_policy where polrelid='public.wealth_struggles'::regclass;
\ir ../../supabase/migrations/20261024024312_wealth_struggles_borrowing_receipt.sql
\ir BORROWING_RECLASSIFICATION_GUARD_REVIEW.sql
begin;
insert into public.wealth_struggles (id, action_type, amount) values
  (1,'borrowing',10000),(2,'expense',330),(3,'borrowing',1);
do $$
declare target_type text;
begin
  foreach target_type in array array['expense','conquer','transfer','defend','invest'] loop
    begin
      update public.wealth_struggles
        set action_type=target_type, amount=999 where id=1;
      raise exception 'Borrowing type change unexpectedly accepted: %', target_type;
    exception when check_violation then null;
    end;
  end loop;
  if not exists(select 1 from public.wealth_struggles
      where id=1 and action_type='borrowing' and amount=10000) then
    raise exception 'Rejected updates must preserve the original row';
  end if;
  raise notice 'PASS: legacy type rewrites rejected atomically; legitimate type corrections are also blocked';
  update public.wealth_struggles set description='synthetic memo',amount=10001 where id=1;
  update public.wealth_struggles set action_type='conquer' where id=2;
  if not exists(select 1 from public.wealth_struggles where id=2 and action_type='conquer') then
    raise exception 'Existing non-borrowing type correction regressed';
  end if;
  raise notice 'PASS: memo/amount edits and non-borrowing type corrections remain possible';
  delete from public.wealth_struggles where id=3;
  if exists(select 1 from public.wealth_struggles where id=3) then
    raise exception 'Documented deletion limitation changed';
  end if;
  raise notice 'LIMITATION CONFIRMED: this candidate does not block borrowing deletion';
  if not (select relrowsecurity from pg_class where oid='public.wealth_struggles'::regclass) then
    raise exception 'RLS unexpectedly disabled';
  end if;
  if exists (
    (select * from policy_before except
     select polname,polcmd,polroles,polqual::text,polwithcheck::text
     from pg_policy where polrelid='public.wealth_struggles'::regclass)
    union all
    (select polname,polcmd,polroles,polqual::text,polwithcheck::text
     from pg_policy where polrelid='public.wealth_struggles'::regclass
     except select * from policy_before)
  ) then raise exception 'Policy definition changed'; end if;
  if exists(select 1 from pg_proc p, lateral aclexplode(p.proacl) a
      where p.oid='public.reject_borrowing_reclassification()'::regprocedure
      and a.grantee=0 and a.privilege_type='EXECUTE') then
    raise exception 'Public execute unexpectedly granted';
  end if;
  raise notice 'PASS: RLS enabled/policy definition unchanged/public function execute revoked';
end;
$$;
rollback;
