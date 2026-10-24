begin;
set local lock_timeout = '3s';
set local statement_timeout = '30s';
do $approved_preconditions$
begin
  if exists(select 1 from supabase_migrations.schema_migrations where version in ('20261024024312','20261024050547') or name in ('wealth_struggles_borrowing_receipt','wealth_struggles_borrowing_client_compatibility')) then
    raise exception 'Migration history changed; inspect before retry';
  end if;
  if not exists(select 1 from pg_constraint where conrelid='public.wealth_struggles'::regclass and conname='wealth_struggles_action_type_check' and pg_get_constraintdef(oid) = $expected_check$CHECK ((action_type = ANY (ARRAY['defend'::text, 'conquer'::text, 'invest'::text, 'expense'::text, 'transfer'::text])))$expected_check$) then
    raise exception 'Action type CHECK differs from approved baseline';
  end if;
  if not (select relrowsecurity from pg_class where oid='public.wealth_struggles'::regclass) then
    raise exception 'Baseline RLS is not enabled';
  end if;
  if (select count(*) from pg_policies where schemaname='public' and tablename='wealth_struggles') <> 1 or not exists(select 1 from pg_policies where schemaname='public' and tablename='wealth_struggles' and policyname='Users can manage their own struggle records' and permissive='PERMISSIVE' and cmd='ALL' and roles::text='{public}' and qual='(auth.uid() = user_id)' and with_check is null) then
    raise exception 'Ownership policies differ from approved baseline';
  end if;
end;
$approved_preconditions$;


-- Review draft only. Not executed against production.
-- Keep all existing action types, amount checks, grants and RLS policies.
set local lock_timeout = '3s';
set local statement_timeout = '30s';
alter table public.wealth_struggles
  drop constraint wealth_struggles_action_type_check,
  add constraint wealth_struggles_action_type_check
  check (action_type in (
    'defend', 'conquer', 'invest', 'expense', 'transfer', 'borrowing'
  ));

-- Rollback is permitted only before borrowing rows exist. Never remove rows
-- or relabel a borrowing receipt as income merely to make rollback succeed.
-- If receipts already exist, disable new UI entry and preserve the expanded
-- constraint until a separately reviewed data-preserving plan is available.

insert into supabase_migrations.schema_migrations(version,name,statements) values ('20261024024312','wealth_struggles_borrowing_receipt',array[$approved_source$-- Review draft only. Not executed against production.
-- Keep all existing action types, amount checks, grants and RLS policies.
begin;
set local lock_timeout = '3s';
set local statement_timeout = '30s';
alter table public.wealth_struggles
  drop constraint wealth_struggles_action_type_check,
  add constraint wealth_struggles_action_type_check
  check (action_type in (
    'defend', 'conquer', 'invest', 'expense', 'transfer', 'borrowing'
  ));
commit;

-- Rollback is permitted only before borrowing rows exist. Never remove rows
-- or relabel a borrowing receipt as income merely to make rollback succeed.
-- If receipts already exist, disable new UI entry and preserve the expanded
-- constraint until a separately reviewed data-preserving plan is available.
$approved_source$]);

-- Review draft migration. Not approved or applied to production.
-- Requires compatible client headers plus role/owner/API tests first.
-- Keep the existing permissive ownership policy unchanged.
-- This is a compatibility marker, NOT authentication or authorization.
set local lock_timeout = '3s';
set local statement_timeout = '30s';
create policy borrowing_client_compatibility
on public.wealth_struggles
as restrictive
for all
to authenticated
using (
  action_type is distinct from 'borrowing'
  or coalesce(
    nullif(current_setting('request.headers', true), '')::jsonb
      ->> 'x-asset-flow-version',
    ''
  ) = 'borrowing-v1'
)
with check (
  action_type is distinct from 'borrowing'
  or coalesce(
    nullif(current_setting('request.headers', true), '')::jsonb
      ->> 'x-asset-flow-version',
    ''
  ) = 'borrowing-v1'
);

-- Does not deduplicate CSV deposits against manually entered borrowing.
-- Clients without the marker intentionally cannot see borrowing rows.
-- Rollback must first disable new borrowing entry and review the effect of
-- exposing borrowing rows again to old clients. No rollback is authorized.

insert into supabase_migrations.schema_migrations(version,name,statements) values ('20261024050547','wealth_struggles_borrowing_client_compatibility',array[$approved_source$-- Review draft migration. Not approved or applied to production.
-- Requires compatible client headers plus role/owner/API tests first.
-- Keep the existing permissive ownership policy unchanged.
-- This is a compatibility marker, NOT authentication or authorization.
begin;
set local lock_timeout = '3s';
set local statement_timeout = '30s';
create policy borrowing_client_compatibility
on public.wealth_struggles
as restrictive
for all
to authenticated
using (
  action_type is distinct from 'borrowing'
  or coalesce(
    nullif(current_setting('request.headers', true), '')::jsonb
      ->> 'x-asset-flow-version',
    ''
  ) = 'borrowing-v1'
)
with check (
  action_type is distinct from 'borrowing'
  or coalesce(
    nullif(current_setting('request.headers', true), '')::jsonb
      ->> 'x-asset-flow-version',
    ''
  ) = 'borrowing-v1'
);
commit;

-- Does not deduplicate CSV deposits against manually entered borrowing.
-- Clients without the marker intentionally cannot see borrowing rows.
-- Rollback must first disable new borrowing entry and review the effect of
-- exposing borrowing rows again to old clients. No rollback is authorized.
$approved_source$]);

commit;
