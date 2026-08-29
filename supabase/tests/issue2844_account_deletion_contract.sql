-- Runtime PostgreSQL contract for Issue #2844. Any mismatch raises and fails
-- the disposable Testcontainers integration smoke.

insert into auth.users (id)
values
  ('00000000-0000-4000-8000-000000002844'::uuid),
  ('00000000-0000-4000-8000-000000012844'::uuid)
on conflict (id) do nothing;

create table public.issue2844_cascade_fixture (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade
);

create table public.issue2844_unclassified_fixture (
  id bigint generated always as identity primary key,
  owner_user_id uuid not null
);

insert into public.issue2844_cascade_fixture (user_id)
values ('00000000-0000-4000-8000-000000002844'::uuid);
insert into public.issue2844_unclassified_fixture (owner_user_id)
values ('00000000-0000-4000-8000-000000002844'::uuid);

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
  v_blocker record;
  v_claimed public.account_deletion_requests;
  v_storage_count integer;
begin
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
    300
  );
  if not exists (
    select 1
    from public.account_deletion_requests
    where id = v_claimed.id
      and status = 'failed'
      and database_rows_remaining = 1
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
  processing_started_at
) values (
  '00000000-0000-4000-8000-000000012844'::uuid,
  'processing',
  '2026-08-29.v1',
  now() - interval '31 days',
  now() - interval '1 day',
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
  where user_id = '00000000-0000-4000-8000-000000012844'::uuid;

  perform public.complete_account_deletion(v_request_id, 2, true);
  if not exists (
    select 1
    from public.account_deletion_requests
    where id = v_request_id
      and status = 'completed'
      and user_id is null
      and completed_at is not null
      and storage_objects_deleted = 2
      and stripe_customer_deleted
  ) then
    raise exception 'completion did not anonymize the request row';
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
    'public.claim_due_account_deletion()'::regprocedure::oid,
    'public.fail_account_deletion(bigint,text,bigint,integer)'::regprocedure::oid,
    'public.complete_account_deletion(bigint,integer,boolean)'::regprocedure::oid,
    'public.account_deletion_dependency_inventory(uuid)'::regprocedure::oid,
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
drop table public.issue2844_cascade_fixture;
