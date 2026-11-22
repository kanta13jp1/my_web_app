\set ON_ERROR_STOP on
begin;
create table public.wealth_struggles (
  action_type text not null,
  amount integer not null check (amount > 0),
  constraint wealth_struggles_action_type_check
    check (action_type in ('defend', 'conquer', 'invest', 'expense'))
);
insert into public.wealth_struggles values ('expense', 110);
\i supabase/migrations/20261002150000_wealth_struggles_allow_transfer.sql
-- Reapplying is safe and retains existing rows.
\i supabase/migrations/20261002150000_wealth_struggles_allow_transfer.sql
insert into public.wealth_struggles
select kind, 20000 from unnest(array['defend','conquer','invest','expense','transfer']) kind;
do $$
begin
  if (select count(*) from public.wealth_struggles) <> 6 then
    raise exception 'Existing rows or allowed action types were lost';
  end if;
  begin
    insert into public.wealth_struggles values ('unknown', 1);
    raise exception 'Unknown action type unexpectedly accepted';
  exception when check_violation then null;
  end;
  begin
    insert into public.wealth_struggles values ('transfer', 0);
    raise exception 'Zero amount unexpectedly accepted';
  exception when check_violation then null;
  end;
end $$;
rollback;
