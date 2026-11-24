-- Run only in the disposable CI database. Apply the actual review script.
\set ON_ERROR_STOP on
create table public.wealth_struggles (
  action_type text not null,
  amount integer not null check (amount > 0),
  user_id uuid not null default '00000000-0000-0000-0000-000000000001',
  constraint wealth_struggles_action_type_check check (action_type in (
    'defend', 'conquer', 'invest', 'expense', 'transfer'
  ))
);
alter table public.wealth_struggles enable row level security;
create policy fixture_owner on public.wealth_struggles
  using (user_id = nullif(current_setting('fixture.user_id', true), '')::uuid);
create temporary table policy_before as
  select polname, polcmd, polroles, polqual::text, polwithcheck::text
  from pg_policy where polrelid='public.wealth_struggles'::regclass;
\ir ../../supabase/migrations/20261024024312_wealth_struggles_borrowing_receipt.sql
begin;
insert into public.wealth_struggles (action_type, amount) values
  ('defend', 1), ('conquer', 480), ('invest', 1), ('expense', 330),
  ('transfer', 20000), ('borrowing', 10000);
do $$
begin
  if (select count(*) from public.wealth_struggles) <> 6 then
    raise exception 'Existing types or borrowing rejected';
  end if;
  begin
    insert into public.wealth_struggles (action_type, amount) values ('unknown_kind', 1);
    raise exception 'Unknown kind unexpectedly accepted';
  exception when check_violation then null;
  end;
  begin
    insert into public.wealth_struggles (action_type, amount) values ('borrowing', 0);
    raise exception 'Zero borrowing unexpectedly accepted';
  exception when check_violation then null;
  end;
  begin
    insert into public.wealth_struggles (action_type, amount) values ('borrowing', -1);
    raise exception 'Negative borrowing unexpectedly accepted';
  exception when check_violation then null;
  end;
  if not (select relrowsecurity from pg_class
          where oid='public.wealth_struggles'::regclass) then
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
  ) then
    raise exception 'RLS policy unexpectedly changed';
  end if;
end $$;
rollback;
