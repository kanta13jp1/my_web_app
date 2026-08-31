-- Runtime PostgreSQL contract for Issue #2844. Any mismatch raises and fails
-- the disposable Testcontainers integration smoke.

insert into auth.users (id)
values
  ('00000000-0000-4000-8000-000000002844'::uuid),
  ('00000000-0000-4000-8000-000000012844'::uuid),
  ('00000000-0000-4000-8000-000000022844'::uuid)
on conflict (id) do nothing;

insert into auth.sessions (id, user_id, created_at)
values
  (
    '00000000-0000-4000-8000-100000002844'::uuid,
    '00000000-0000-4000-8000-000000002844'::uuid,
    now() - interval '14 minutes'
  ),
  (
    '00000000-0000-4000-8000-100000012844'::uuid,
    '00000000-0000-4000-8000-000000002844'::uuid,
    now() - interval '16 minutes'
  )
on conflict (id) do nothing;

create table public.issue2844_cascade_fixture (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade
);

create table public.issue2844_unclassified_fixture (
  id bigint generated always as identity primary key,
  owner_user_id uuid not null
);

create table public.issue2844_direct_fixture (
  id bigint generated always as identity primary key,
  user_id uuid not null
);

create table public.issue2844_direct_a_parent_fixture (
  id uuid primary key,
  user_id uuid not null
);

create table public.issue2844_direct_z_child_fixture (
  id uuid primary key,
  user_id uuid not null,
  parent_id uuid not null
    references public.issue2844_direct_a_parent_fixture(id)
);

grant select on table
  public.issue2844_direct_fixture,
  public.issue2844_direct_a_parent_fixture,
  public.issue2844_direct_z_child_fixture
to service_role;

insert into public.account_deletion_direct_delete_adapters (table_name)
values
  ('issue2844_direct_fixture'),
  ('issue2844_direct_a_parent_fixture'),
  ('issue2844_direct_z_child_fixture');

insert into public.issue2844_cascade_fixture (user_id)
values ('00000000-0000-4000-8000-000000002844'::uuid);
insert into public.issue2844_unclassified_fixture (owner_user_id)
values ('00000000-0000-4000-8000-000000002844'::uuid);
insert into public.issue2844_direct_fixture (user_id)
values ('00000000-0000-4000-8000-000000002844'::uuid);
insert into public.issue2844_direct_a_parent_fixture (id, user_id)
values (
  '00000000-0000-4000-8000-000000102844'::uuid,
  '00000000-0000-4000-8000-000000002844'::uuid
);
insert into public.issue2844_direct_z_child_fixture (
  id,
  user_id,
  parent_id
) values (
  '00000000-0000-4000-8000-000000112844'::uuid,
  '00000000-0000-4000-8000-000000002844'::uuid,
  '00000000-0000-4000-8000-000000102844'::uuid
);
insert into public.user_api_audit_log (user_id, action, status)
values (
  '00000000-0000-4000-8000-000000002844'::uuid,
  'account_deletion_contract',
  200
);

insert into storage.objects (bucket_id, name, owner_id)
values
  ('avatars', 'metadata-owned.png', '00000000-0000-4000-8000-000000002844'),
  (
    'attachments',
    '00000000-0000-4000-8000-000000002844/report.pdf',
    null
  ),
  (
    'ai-generated-images',
    'openai/00000000-0000-4000-8000-000000002844/generated.png',
    null
  );

insert into public.account_deletion_requests (
  user_id,
  policy_version,
  requested_at,
  scheduled_for
) values (
  '00000000-0000-4000-8000-000000002844'::uuid,
  '2026-08-29.v1',
  now() - interval '31 days',
  now() - interval '1 day'
);

set role service_role;
select set_config('request.jwt.claim.role', 'service_role', false);

do $contract$
declare
  v_cascade record;
  v_direct record;
  v_retained record;
  v_blocker record;
  v_claimed public.account_deletion_requests;
  v_storage_count integer;
begin
  if not public.has_recent_account_deletion_session(
    '00000000-0000-4000-8000-000000002844'::uuid,
    '00000000-0000-4000-8000-100000002844'::uuid
  ) then
    raise exception 'fresh current session was rejected';
  end if;
  if public.has_recent_account_deletion_session(
    '00000000-0000-4000-8000-000000002844'::uuid,
    '00000000-0000-4000-8000-100000012844'::uuid
  ) then
    raise exception 'stale current session was accepted';
  end if;
  if public.has_recent_account_deletion_session(
    '00000000-0000-4000-8000-000000012844'::uuid,
    '00000000-0000-4000-8000-100000002844'::uuid
  ) then
    raise exception 'another users session was accepted';
  end if;

  select * into v_cascade
  from public.account_deletion_dependency_inventory(
    '00000000-0000-4000-8000-000000002844'::uuid
  )
  where table_name = 'issue2844_cascade_fixture'
    and column_name = 'user_id';
  if not found
     or v_cascade.deletion_strategy is distinct from 'cascade'
     or v_cascade.matching_rows is distinct from 1::bigint
     or v_cascade.is_blocking is distinct from false then
    raise exception 'cascade inventory classification failed: %',
      row_to_json(v_cascade);
  end if;

  select * into v_direct
  from public.account_deletion_dependency_inventory(
    '00000000-0000-4000-8000-000000002844'::uuid
  )
  where table_name = 'issue2844_direct_fixture'
    and column_name = 'user_id';
  if not found
     or v_direct.deletion_strategy is distinct from 'delete_direct'
     or v_direct.matching_rows is distinct from 1::bigint
     or v_direct.is_blocking is distinct from false then
    raise exception 'direct ownership classification failed: %',
      row_to_json(v_direct);
  end if;

  perform public.delete_account_deletion_direct_rows(
    '00000000-0000-4000-8000-000000002844'::uuid
  );
  if exists (
    select 1
    from public.issue2844_direct_fixture
    where user_id = '00000000-0000-4000-8000-000000002844'::uuid
    union all
    select 1
    from public.issue2844_direct_a_parent_fixture
    where user_id = '00000000-0000-4000-8000-000000002844'::uuid
    union all
    select 1
    from public.issue2844_direct_z_child_fixture
    where user_id = '00000000-0000-4000-8000-000000002844'::uuid
  ) then
    raise exception 'direct ownership rows were not deleted across FK passes';
  end if;

  select * into v_retained
  from public.account_deletion_dependency_inventory(
    '00000000-0000-4000-8000-000000002844'::uuid
  )
  where table_name = 'user_api_audit_log'
    and column_name = 'user_id';
  if not found
     or v_retained.deletion_strategy is distinct from 'retain_90_days'
     or v_retained.matching_rows is distinct from 1::bigint
     or v_retained.is_blocking is distinct from false then
    raise exception '90-day audit retention classification failed: %',
      row_to_json(v_retained);
  end if;
  if not exists (
    select 1
    from public.user_api_audit_log
    where user_id = '00000000-0000-4000-8000-000000002844'::uuid
  ) then
    raise exception '90-day audit evidence was deleted';
  end if;

  select count(*) into v_storage_count
  from public.account_deletion_storage_objects(
    '00000000-0000-4000-8000-000000002844'::uuid,
    1000
  );
  if v_storage_count is distinct from 3 then
    raise exception 'storage ownership/path inventory failed: %',
      v_storage_count;
  end if;

  select * into v_blocker
  from public.account_deletion_dependency_inventory(
    '00000000-0000-4000-8000-000000002844'::uuid
  )
  where table_name = 'issue2844_unclassified_fixture'
    and column_name = 'owner_user_id';
  if not found
     or v_blocker.deletion_strategy is distinct from 'unclassified_blocked'
     or v_blocker.matching_rows is distinct from 1::bigint
     or v_blocker.is_blocking is distinct from true then
    raise exception 'unclassified inventory did not fail closed: %',
      row_to_json(v_blocker);
  end if;

  select * into v_claimed
  from public.claim_due_account_deletion();
  if v_claimed.status is distinct from 'processing'
     or v_claimed.attempt_count is distinct from 1 then
    raise exception 'due request was not atomically claimed: %',
      row_to_json(v_claimed);
  end if;

  perform public.fail_account_deletion(
    v_claimed.id,
    'account_deletion_dependency_blocked',
    1,
    300,
    2,
    true,
    true
  );
  if not exists (
    select 1
    from public.account_deletion_requests
    where id = v_claimed.id
      and status = 'failed'
      and database_rows_remaining = 1
      and storage_objects_deleted = 2
      and stripe_customer_deleted
      and auth_user_deleted_at is not null
      and retry_after >= now() + interval '299 seconds'
  ) then
    raise exception 'failed request retry state was not recorded';
  end if;
end;
$contract$;

reset role;

insert into public.account_deletion_requests (
  user_id,
  status,
  policy_version,
  requested_at,
  scheduled_for,
  processing_started_at,
  auth_user_deleted_at,
  storage_objects_deleted,
  stripe_customer_deleted
) values (
  '00000000-0000-4000-8000-000000012844'::uuid,
  'processing',
  '2026-08-29.v1',
  now() - interval '31 days',
  now() - interval '1 day',
  now(),
  now() - interval '66 minutes',
  2,
  true
);

set role service_role;
select set_config('request.jwt.claim.role', 'service_role', false);

do $contract$
declare
  v_request_id bigint;
begin
  select id into v_request_id
  from public.account_deletion_requests
  where user_id = '00000000-0000-4000-8000-000000012844'::uuid;

  perform public.complete_account_deletion(v_request_id, 3, false);
  if not exists (
    select 1
    from public.account_deletion_requests
    where id = v_request_id
      and status = 'completed'
      and user_id is null
      and completed_at is not null
      and storage_objects_deleted = 5
      and stripe_customer_deleted
  ) then
    raise exception 'completion did not anonymize the request row';
  end if;
end;
$contract$;

reset role;

insert into public.account_deletion_requests (
  user_id,
  status,
  policy_version,
  requested_at,
  scheduled_for,
  processing_started_at,
  auth_user_deleted_at
) values (
  '00000000-0000-4000-8000-000000022844'::uuid,
  'processing',
  '2026-08-29.v1',
  now() - interval '31 days',
  now() - interval '1 day',
  now(),
  now()
);

set role service_role;
select set_config('request.jwt.claim.role', 'service_role', false);

do $contract$
declare
  v_request_id bigint;
begin
  select id into v_request_id
  from public.account_deletion_requests
  where user_id = '00000000-0000-4000-8000-000000022844'::uuid;

  begin
    perform public.complete_account_deletion(v_request_id, 0, false);
    raise exception 'premature completion unexpectedly succeeded';
  exception when sqlstate 'P0002' then
    null;
  end;

  perform public.defer_account_deletion_finalization(
    v_request_id,
    4,
    true
  );
  if not exists (
    select 1
    from public.account_deletion_requests
    where id = v_request_id
      and status = 'awaiting_token_expiry'
      and auth_user_deleted_at is not null
      and retry_after >= now() + interval '3899 seconds'
      and storage_objects_deleted = 4
      and stripe_customer_deleted
  ) then
    raise exception 'token-expiry deferral state was not recorded';
  end if;
end;
$contract$;

reset role;

do $contract$
declare
  v_function oid;
begin
  if not (
    select relrowsecurity
    from pg_catalog.pg_class
    where oid = 'public.account_deletion_requests'::regclass
  ) then
    raise exception 'account deletion request RLS is disabled';
  end if;

  if has_table_privilege(
    'authenticated',
    'public.account_deletion_requests',
    'select'
  ) or has_table_privilege(
    'anon',
    'public.account_deletion_requests',
    'select'
  ) then
    raise exception 'browser roles can read the service-role queue';
  end if;

  foreach v_function in array array[
    'public.has_recent_account_deletion_session(uuid,uuid)'::regprocedure::oid,
    'public.claim_due_account_deletion()'::regprocedure::oid,
    'public.preflight_due_account_deletion(bigint)'::regprocedure::oid,
    'public.claim_due_account_deletion_by_id(bigint)'::regprocedure::oid,
    'public.fail_account_deletion(bigint,text,bigint,integer,integer,boolean,boolean)'::regprocedure::oid,
    'public.complete_account_deletion(bigint,integer,boolean)'::regprocedure::oid,
    'public.defer_account_deletion_finalization(bigint,integer,boolean)'::regprocedure::oid,
    'public.account_deletion_dependency_inventory(uuid)'::regprocedure::oid,
    'public.delete_account_deletion_direct_rows(uuid)'::regprocedure::oid,
    'public.account_deletion_storage_objects(uuid,integer)'::regprocedure::oid
  ] loop
    if has_function_privilege('authenticated', v_function, 'execute')
       or has_function_privilege('anon', v_function, 'execute') then
      raise exception 'browser role can execute service function %', v_function;
    end if;
    if not exists (
      select 1
      from pg_catalog.pg_proc
      where oid = v_function
        and prosecdef
        and exists (
          select 1
          from unnest(coalesce(proconfig, array[]::text[])) as setting
          where setting in ('search_path=', 'search_path=""')
        )
    ) then
      raise exception 'service function is not pinned SECURITY DEFINER: %',
        v_function;
    end if;
  end loop;
end;
$contract$;

drop table public.issue2844_unclassified_fixture;
drop table public.issue2844_direct_fixture;
drop table public.issue2844_direct_z_child_fixture;
drop table public.issue2844_direct_a_parent_fixture;
drop table public.issue2844_cascade_fixture;
