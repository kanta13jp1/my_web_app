-- Staged rollout and tenant-boundary contract for Issue #2844. This fixture
-- runs only in the disposable cloud PostgreSQL integration job.

insert into auth.users (id)
values
  ('00000000-0000-4000-8000-000000032844'::uuid),
  ('00000000-0000-4000-8000-000000042844'::uuid);

create table public.issue2844_rollout_cascade_fixture (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade
);

create table public.issue2844_rollout_direct_fixture (
  id bigint generated always as identity primary key,
  user_id uuid not null
);

insert into public.account_deletion_direct_delete_adapters (table_name)
values ('issue2844_rollout_direct_fixture');

insert into public.issue2844_rollout_cascade_fixture (user_id)
values
  ('00000000-0000-4000-8000-000000032844'::uuid),
  ('00000000-0000-4000-8000-000000042844'::uuid);

insert into public.issue2844_rollout_direct_fixture (user_id)
values
  ('00000000-0000-4000-8000-000000032844'::uuid),
  ('00000000-0000-4000-8000-000000042844'::uuid);

insert into public.user_api_audit_log (user_id, action, status)
values
  (
    '00000000-0000-4000-8000-000000032844'::uuid,
    'account_deletion_target',
    200
  ),
  (
    '00000000-0000-4000-8000-000000042844'::uuid,
    'account_deletion_control',
    200
  );

insert into storage.objects (bucket_id, name, owner_id)
values
  (
    'avatars',
    '00000000-0000-4000-8000-000000032844/target.png',
    '00000000-0000-4000-8000-000000032844'
  ),
  (
    'avatars',
    '00000000-0000-4000-8000-000000042844/control.png',
    '00000000-0000-4000-8000-000000042844'
  );

insert into public.account_deletion_requests (
  user_id,
  policy_version,
  requested_at,
  scheduled_for
)
values
  (
    '00000000-0000-4000-8000-000000032844'::uuid,
    '2026-08-29.v1',
    now() - interval '31 days',
    now() - interval '1 day'
  ),
  (
    '00000000-0000-4000-8000-000000042844'::uuid,
    '2026-08-29.v1',
    now() - interval '31 days',
    now() - interval '1 day'
  );

set role service_role;
select set_config('request.jwt.claim.role', 'service_role', false);

do $contract$
declare
  v_target_request_id bigint;
  v_control_request_id bigint;
  v_preflight record;
  v_claimed public.account_deletion_requests;
begin
  select id into v_target_request_id
  from public.account_deletion_requests
  where user_id = '00000000-0000-4000-8000-000000032844'::uuid;
  select id into v_control_request_id
  from public.account_deletion_requests
  where user_id = '00000000-0000-4000-8000-000000042844'::uuid;

  select * into v_preflight
  from public.preflight_due_account_deletion(v_target_request_id);
  if not found
     or v_preflight.request_id is distinct from v_target_request_id
     or v_preflight.blocking_rows is distinct from 0::bigint
     or v_preflight.remaining_rows is distinct from 2::bigint
     or v_preflight.storage_objects is distinct from 1::bigint then
    raise exception 'non-destructive preflight inventory failed: %',
      row_to_json(v_preflight);
  end if;
  if to_jsonb(v_preflight) ? 'user_id' then
    raise exception 'preflight response exposed a user identifier';
  end if;
  if not exists (
    select 1
    from public.account_deletion_requests
    where id = v_target_request_id
      and status = 'pending'
      and attempt_count = 0
  ) then
    raise exception 'preflight mutated the target request';
  end if;

  select * into v_claimed
  from public.claim_due_account_deletion_by_id(v_target_request_id);
  if v_claimed.id is distinct from v_target_request_id
     or v_claimed.status is distinct from 'processing'
     or v_claimed.attempt_count is distinct from 1 then
    raise exception 'exact-id canary claim failed: %', row_to_json(v_claimed);
  end if;
  if not exists (
    select 1
    from public.account_deletion_requests
    where id = v_control_request_id
      and status = 'pending'
      and attempt_count = 0
  ) then
    raise exception 'exact-id canary claimed the control tenant';
  end if;

  perform public.delete_account_deletion_direct_rows(
    '00000000-0000-4000-8000-000000032844'::uuid
  );
end;
$contract$;

reset role;

delete from storage.objects
where (bucket_id, name) in (
  select bucket_id, object_name
  from public.account_deletion_storage_objects(
    '00000000-0000-4000-8000-000000032844'::uuid,
    1000
  )
);
delete from auth.users
where id = '00000000-0000-4000-8000-000000032844'::uuid;
update public.account_deletion_requests
set auth_user_deleted_at = now() - interval '66 minutes'
where user_id = '00000000-0000-4000-8000-000000032844'::uuid;

set role service_role;
select set_config('request.jwt.claim.role', 'service_role', false);

do $contract$
declare
  v_target_request_id bigint;
  v_non_retained_rows bigint;
begin
  select id into v_target_request_id
  from public.account_deletion_requests
  where user_id = '00000000-0000-4000-8000-000000032844'::uuid;

  select coalesce(sum(matching_rows), 0)
    into v_non_retained_rows
  from public.account_deletion_dependency_inventory(
    '00000000-0000-4000-8000-000000032844'::uuid
  )
  where deletion_strategy <> 'retain_90_days';
  if v_non_retained_rows is distinct from 0::bigint then
    raise exception 'target tenant retained deletable database rows: %',
      v_non_retained_rows;
  end if;
  if exists (
    select 1
    from public.account_deletion_storage_objects(
      '00000000-0000-4000-8000-000000032844'::uuid,
      1000
    )
  ) then
    raise exception 'target tenant retained storage objects';
  end if;
  if not exists (
    select 1
    from public.user_api_audit_log
    where user_id = '00000000-0000-4000-8000-000000032844'::uuid
      and action = 'account_deletion_target'
  ) then
    raise exception 'documented 90-day audit exception was not retained';
  end if;

  perform public.complete_account_deletion(v_target_request_id, 1, false);
  if not exists (
    select 1
    from public.account_deletion_requests
    where id = v_target_request_id
      and status = 'completed'
      and user_id is null
      and database_rows_remaining = 0
  ) then
    raise exception 'residual-zero target request did not complete anonymously';
  end if;
end;
$contract$;

reset role;

do $contract$
begin
  if not exists (
    select 1 from auth.users
    where id = '00000000-0000-4000-8000-000000042844'::uuid
  ) or not exists (
    select 1 from public.issue2844_rollout_cascade_fixture
    where user_id = '00000000-0000-4000-8000-000000042844'::uuid
  ) or not exists (
    select 1 from public.issue2844_rollout_direct_fixture
    where user_id = '00000000-0000-4000-8000-000000042844'::uuid
  ) or not exists (
    select 1 from storage.objects
    where name = '00000000-0000-4000-8000-000000042844/control.png'
  ) or not exists (
    select 1 from public.user_api_audit_log
    where user_id = '00000000-0000-4000-8000-000000042844'::uuid
      and action = 'account_deletion_control'
  ) then
    raise exception 'control tenant data crossed the deletion boundary';
  end if;
end;
$contract$;

delete from public.account_deletion_requests
where user_id = '00000000-0000-4000-8000-000000042844'::uuid;
delete from public.user_api_audit_log
where user_id in (
  '00000000-0000-4000-8000-000000032844'::uuid,
  '00000000-0000-4000-8000-000000042844'::uuid
);
delete from storage.objects
where name = '00000000-0000-4000-8000-000000042844/control.png';
delete from auth.users
where id = '00000000-0000-4000-8000-000000042844'::uuid;
delete from public.account_deletion_direct_delete_adapters
where table_name = 'issue2844_rollout_direct_fixture';
drop table public.issue2844_rollout_direct_fixture;
drop table public.issue2844_rollout_cascade_fixture;
