-- Account retention and deletion control plane for Issue #2844.
--
-- Subscription cancellation and account deletion are intentionally separate:
-- cancelling a paid plan keeps the user's free account and its data. An
-- authenticated, recently signed-in user may instead create an account
-- deletion request through the account-lifecycle Edge Function. Requests are
-- cancellable for 30 days before a service-role worker may process them.

create table public.account_deletion_requests (
  id bigint generated always as identity primary key,
  user_id uuid,
  status text not null default 'pending'
    check (status in (
      'pending',
      'processing',
      'awaiting_token_expiry',
      'failed',
      'cancelled',
      'completed'
    )),
  policy_version text not null,
  requested_at timestamptz not null default now(),
  scheduled_for timestamptz not null,
  processing_started_at timestamptz,
  auth_user_deleted_at timestamptz,
  retry_after timestamptz,
  cancelled_at timestamptz,
  completed_at timestamptz,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  last_error_code text,
  storage_objects_deleted integer not null default 0
    check (storage_objects_deleted >= 0),
  stripe_customer_deleted boolean not null default false,
  database_rows_remaining bigint not null default 0
    check (database_rows_remaining >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (scheduled_for >= requested_at),
  check ((status = 'cancelled') = (cancelled_at is not null)),
  check ((status = 'completed') = (completed_at is not null)),
  check (
    status not in ('pending', 'processing', 'awaiting_token_expiry', 'failed')
    or user_id is not null
  )
);

comment on table public.account_deletion_requests is
  'Service-role-only queue. Completed rows retain anonymous operational evidence only.';
comment on column public.account_deletion_requests.user_id is
  'Present only while a request is actionable; cleared after completion.';

create unique index account_deletion_requests_active_user_idx
  on public.account_deletion_requests (user_id)
  where user_id is not null
    and status in ('pending', 'processing', 'awaiting_token_expiry', 'failed');

create index account_deletion_requests_due_idx
  on public.account_deletion_requests (scheduled_for, id)
  where status in ('pending', 'awaiting_token_expiry', 'failed');

alter table public.account_deletion_requests enable row level security;
revoke all on table public.account_deletion_requests
  from public, anon, authenticated;
grant select, insert, update on table public.account_deletion_requests
  to service_role;

-- Explicit adapters keep future plain user_id tables fail-closed. Adding a
-- user-owned table without an auth.users FK requires a reviewed row here (or a
-- purpose-built anonymization/retention adapter) in the same migration.
create table public.account_deletion_direct_delete_adapters (
  schema_name text not null default 'public'
    check (schema_name = 'public'),
  table_name text not null,
  column_name text not null default 'user_id'
    check (column_name = 'user_id'),
  primary key (schema_name, table_name, column_name)
);

comment on table public.account_deletion_direct_delete_adapters is
  'Reviewed legacy user-owned columns that account deletion may hard-delete.';

insert into public.account_deletion_direct_delete_adapters (table_name)
values
  ('ab_assignments'),
  ('abstinence_slips'),
  ('ai_task_budget_job_steps'),
  ('ai_task_budget_jobs'),
  ('daily_habit_logs'),
  ('daily_habits'),
  ('email_accounts'),
  ('email_clean_logs'),
  ('email_cleanup_routines'),
  ('email_subscriptions'),
  ('feature_requests'),
  ('musubi_thread_members'),
  ('note_search_index'),
  ('notion_migration_capabilities'),
  ('notion_migration_checks'),
  ('notion_migration_items'),
  ('notion_migration_vault_entries'),
  ('notion_migration_vault_manifests'),
  ('notion_migration_wbs_staging'),
  ('payment_logs'),
  ('payment_reminders'),
  ('resource_optimizer_ai_quota'),
  ('shopping_items'),
  ('shopping_purchase_logs'),
  ('user_theme_preferences'),
  ('user_writer_knowledge_graph_documents');

alter table public.account_deletion_direct_delete_adapters
  enable row level security;
revoke all on table public.account_deletion_direct_delete_adapters
  from public, anon, authenticated;
grant select on table public.account_deletion_direct_delete_adapters
  to service_role;
grant usage, select on sequence public.account_deletion_requests_id_seq
  to service_role;

create or replace function public.set_account_deletion_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function public.set_account_deletion_updated_at() from public;

create trigger account_deletion_requests_updated_at
before update on public.account_deletion_requests
for each row execute function public.set_account_deletion_updated_at();

-- Service-role RPCs live in public because the Data API exposes only public,
-- storage, and graphql_public in this project. Every function checks the JWT
-- role, pins search_path, and has EXECUTE revoked from browser roles.
create or replace function public.has_recent_account_deletion_session(
  p_user_id uuid,
  p_session_id uuid
)
returns boolean
language plpgsql
security definer
stable
set search_path = ''
as $$
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'service_role_required' using errcode = '42501';
  end if;
  if p_user_id is null or p_session_id is null then
    return false;
  end if;

  -- A refresh keeps the same auth.sessions row. Checking its creation time
  -- binds the destructive request to a fresh sign-in on this exact session,
  -- rather than another device's account-wide last_sign_in_at timestamp.
  return exists (
    select 1
    from auth.sessions as session_record
    where session_record.id = p_session_id
      and session_record.user_id = p_user_id
      and session_record.created_at >= now() - interval '15 minutes'
  );
end;
$$;

comment on function public.has_recent_account_deletion_session(uuid, uuid) is
  'Service-role check that binds account-deletion reauthentication to the current Auth session.';

create or replace function public.claim_due_account_deletion()
returns setof public.account_deletion_requests
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'service_role_required' using errcode = '42501';
  end if;

  return query
  with candidate as (
    select request.id
    from public.account_deletion_requests as request
    where (
      request.status in ('pending', 'awaiting_token_expiry', 'failed')
      and request.scheduled_for <= now()
      and coalesce(request.retry_after, request.scheduled_for) <= now()
      and request.attempt_count < 10
    ) or (
      request.status = 'processing'
      and request.processing_started_at < now() - interval '30 minutes'
      and request.attempt_count < 10
    )
    order by request.scheduled_for, request.id
    limit 1
    for update skip locked
  )
  update public.account_deletion_requests as request
  set status = 'processing',
      processing_started_at = now(),
      retry_after = null,
      attempt_count = request.attempt_count + 1,
      last_error_code = null
  from candidate
  where request.id = candidate.id
  returning request.*;
end;
$$;

create or replace function public.fail_account_deletion(
  p_request_id bigint,
  p_error_code text,
  p_database_rows_remaining bigint default 0,
  p_retry_seconds integer default 86400,
  p_storage_objects_deleted integer default 0,
  p_stripe_customer_deleted boolean default false,
  p_auth_user_deleted boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'service_role_required' using errcode = '42501';
  end if;
  if p_error_code is null or btrim(p_error_code) = '' then
    raise exception 'error_code_required' using errcode = '22023';
  end if;

  update public.account_deletion_requests
  set status = 'failed',
      processing_started_at = null,
      retry_after = now() + make_interval(
        secs => greatest(300, least(coalesce(p_retry_seconds, 86400), 604800))
      ),
      last_error_code = left(btrim(p_error_code), 120),
      auth_user_deleted_at = case
        when coalesce(p_auth_user_deleted, false)
          then coalesce(auth_user_deleted_at, now())
        else auth_user_deleted_at
      end,
      storage_objects_deleted = storage_objects_deleted + greatest(
        0,
        coalesce(p_storage_objects_deleted, 0)
      ),
      stripe_customer_deleted = stripe_customer_deleted
        or coalesce(p_stripe_customer_deleted, false),
      database_rows_remaining = greatest(
        0,
        coalesce(p_database_rows_remaining, 0)
      )
  where id = p_request_id
    and status = 'processing';

  if not found then
    raise exception 'account_deletion_request_not_processing'
      using errcode = 'P0002';
  end if;
end;
$$;

create or replace function public.complete_account_deletion(
  p_request_id bigint,
  p_storage_objects_deleted integer default 0,
  p_stripe_customer_deleted boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'service_role_required' using errcode = '42501';
  end if;

  update public.account_deletion_requests
  set status = 'completed',
      user_id = null,
      processing_started_at = null,
      retry_after = null,
      completed_at = now(),
      last_error_code = null,
      storage_objects_deleted = storage_objects_deleted + greatest(
        0,
        coalesce(p_storage_objects_deleted, 0)
      ),
      stripe_customer_deleted = stripe_customer_deleted
        or coalesce(p_stripe_customer_deleted, false),
      database_rows_remaining = 0
  where id = p_request_id
    and status = 'processing'
    and auth_user_deleted_at is not null
    and auth_user_deleted_at <= now() - interval '65 minutes';

  if not found then
    raise exception 'account_deletion_request_not_processing'
      using errcode = 'P0002';
  end if;
end;
$$;

-- Access tokens issued before auth deletion remain valid until their exp claim.
-- Keep the request identifiable and schedule one final cleanup only after the
-- configured one-hour JWT lifetime plus a five-minute safety margin.
create or replace function public.defer_account_deletion_finalization(
  p_request_id bigint,
  p_storage_objects_deleted integer default 0,
  p_stripe_customer_deleted boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'service_role_required' using errcode = '42501';
  end if;

  update public.account_deletion_requests
  set status = 'awaiting_token_expiry',
      processing_started_at = null,
      auth_user_deleted_at = coalesce(auth_user_deleted_at, now()),
      retry_after = greatest(
        now() + interval '5 minutes',
        coalesce(auth_user_deleted_at, now()) + interval '65 minutes'
      ),
      last_error_code = null,
      storage_objects_deleted = storage_objects_deleted + greatest(
        0,
        coalesce(p_storage_objects_deleted, 0)
      ),
      stripe_customer_deleted = stripe_customer_deleted
        or coalesce(p_stripe_customer_deleted, false)
  where id = p_request_id
    and status = 'processing';

  if not found then
    raise exception 'account_deletion_request_not_processing'
      using errcode = 'P0002';
  end if;
end;
$$;

-- Inventory every current public UUID subject column. Direct auth.users
-- CASCADE/SET NULL references and reviewed direct-delete adapters are safe.
-- The API audit log is deliberately retained for its existing 90-day policy;
-- every other populated unclassified/restricting column fails closed.
create or replace function public.account_deletion_dependency_inventory(
  p_user_id uuid
)
returns table (
  schema_name text,
  table_name text,
  column_name text,
  deletion_strategy text,
  matching_rows bigint,
  is_blocking boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_column record;
  v_delete_rule "char";
  v_matches bigint;
  v_strategy text;
  v_direct_delete boolean;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'service_role_required' using errcode = '42501';
  end if;
  if p_user_id is null then
    raise exception 'user_id_required' using errcode = '22023';
  end if;

  for v_column in
    select
      namespace.nspname as schema_name,
      relation.relname as table_name,
      attribute.attname as column_name,
      relation.oid as relation_id,
      attribute.attnum as attribute_number
    from pg_catalog.pg_attribute as attribute
    join pg_catalog.pg_class as relation
      on relation.oid = attribute.attrelid
    join pg_catalog.pg_namespace as namespace
      on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relkind in ('r', 'p')
      and attribute.attnum > 0
      and not attribute.attisdropped
      and attribute.atttypid = 'pg_catalog.uuid'::regtype
      and attribute.attname ~ '(^user_id$|_user_id$|^owner_id$|_owner_id$|^author_id$|^created_by$|^updated_by$|^requested_by$)'
      and relation.relname <> 'account_deletion_requests'
    order by namespace.nspname, relation.relname, attribute.attname
  loop
    v_delete_rule := null;
    select constraint_record.confdeltype
      into v_delete_rule
    from pg_catalog.pg_constraint as constraint_record
    where constraint_record.contype = 'f'
      and constraint_record.conrelid = v_column.relation_id
      and v_column.attribute_number = any(constraint_record.conkey)
      and constraint_record.confrelid = 'auth.users'::regclass
    limit 1;

    select exists (
      select 1
      from public.account_deletion_direct_delete_adapters as adapter
      where adapter.schema_name = v_column.schema_name
        and adapter.table_name = v_column.table_name
        and adapter.column_name = v_column.column_name
    ) into v_direct_delete;

    v_strategy := case
      when v_delete_rule = 'c' then 'cascade'
      when v_delete_rule = 'n' then 'set_null'
      when v_column.table_name = 'user_api_audit_log'
        and v_column.column_name = 'user_id' then 'retain_90_days'
      when v_direct_delete then 'delete_direct'
      when v_delete_rule = 'd' then 'set_default_blocked'
      when v_delete_rule = 'r' then 'restrict_blocked'
      when v_delete_rule = 'a' then 'no_action_blocked'
      else 'unclassified_blocked'
    end;

    execute format(
      'select count(*) from %I.%I where %I = $1',
      v_column.schema_name,
      v_column.table_name,
      v_column.column_name
    ) into v_matches using p_user_id;

    schema_name := v_column.schema_name;
    table_name := v_column.table_name;
    column_name := v_column.column_name;
    deletion_strategy := v_strategy;
    matching_rows := v_matches;
    is_blocking := v_matches > 0
      and v_strategy not in (
        'cascade',
        'set_null',
        'delete_direct',
        'retain_90_days'
      );
    return next;
  end loop;
end;
$$;

-- Delete legacy user-owned rows that have a direct user_id but no automatic
-- auth.users CASCADE/SET NULL path. Multiple passes tolerate parent/child
-- ordering; an unresolved FK remains fail-closed.
create or replace function public.delete_account_deletion_direct_rows(
  p_user_id uuid
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_column record;
  v_deleted bigint;
  v_total_deleted bigint := 0;
  v_progress boolean;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'service_role_required' using errcode = '42501';
  end if;
  if p_user_id is null then
    raise exception 'user_id_required' using errcode = '22023';
  end if;

  for v_pass in 1..8 loop
    v_progress := false;
    for v_column in
      select inventory.schema_name, inventory.table_name, inventory.column_name
      from public.account_deletion_dependency_inventory(p_user_id) as inventory
      where inventory.deletion_strategy = 'delete_direct'
        and inventory.matching_rows > 0
      order by inventory.schema_name, inventory.table_name, inventory.column_name
    loop
      begin
        execute format(
          'delete from %I.%I where %I = $1',
          v_column.schema_name,
          v_column.table_name,
          v_column.column_name
        ) using p_user_id;
        get diagnostics v_deleted = row_count;
        if v_deleted > 0 then
          v_total_deleted := v_total_deleted + v_deleted;
          v_progress := true;
        end if;
      exception when foreign_key_violation then
        -- A later pass can succeed after its dependent table is emptied.
        null;
      end;
    end loop;

    exit when not exists (
      select 1
      from public.account_deletion_dependency_inventory(p_user_id) as inventory
      where inventory.deletion_strategy = 'delete_direct'
        and inventory.matching_rows > 0
    );
    exit when not v_progress;
  end loop;

  if exists (
    select 1
    from public.account_deletion_dependency_inventory(p_user_id) as inventory
    where inventory.deletion_strategy = 'delete_direct'
      and inventory.matching_rows > 0
  ) then
    raise exception 'account_deletion_direct_delete_blocked'
      using errcode = '23503';
  end if;

  return v_total_deleted;
end;
$$;

-- Storage objects must be removed through the Storage API. This helper avoids
-- depending on a particular storage.objects owner column version by reading
-- its JSON representation. It also covers this repository's established
-- user-id-first paths and service-generated openai/<user-id>/ paths.
create or replace function public.account_deletion_storage_objects(
  p_user_id uuid,
  p_limit integer default 1000
)
returns table (bucket_id text, object_name text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'service_role_required' using errcode = '42501';
  end if;
  if p_user_id is null then
    raise exception 'user_id_required' using errcode = '22023';
  end if;

  return query
  select object_record.bucket_id::text, object_record.name::text
  from storage.objects as object_record
  where coalesce(
    nullif(to_jsonb(object_record) ->> 'owner_id', ''),
    nullif(to_jsonb(object_record) ->> 'owner', '')
  ) = p_user_id::text
    or split_part(object_record.name, '/', 1) = p_user_id::text
    or (
      object_record.bucket_id = 'ai-generated-images'
      and split_part(object_record.name, '/', 1) = 'openai'
      and split_part(object_record.name, '/', 2) = p_user_id::text
    )
  order by object_record.bucket_id, object_record.name
  limit greatest(1, least(coalesce(p_limit, 1000), 1000));
end;
$$;

revoke all on function public.claim_due_account_deletion()
  from public, anon, authenticated;
revoke all on function public.has_recent_account_deletion_session(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.fail_account_deletion(
  bigint, text, bigint, integer, integer, boolean, boolean
)
  from public, anon, authenticated;
revoke all on function public.complete_account_deletion(bigint, integer, boolean)
  from public, anon, authenticated;
revoke all on function public.defer_account_deletion_finalization(
  bigint, integer, boolean
)
  from public, anon, authenticated;
revoke all on function public.account_deletion_dependency_inventory(uuid)
  from public, anon, authenticated;
revoke all on function public.delete_account_deletion_direct_rows(uuid)
  from public, anon, authenticated;
revoke all on function public.account_deletion_storage_objects(uuid, integer)
  from public, anon, authenticated;

grant execute on function public.claim_due_account_deletion()
  to service_role;
grant execute on function public.has_recent_account_deletion_session(uuid, uuid)
  to service_role;
grant execute on function public.fail_account_deletion(
  bigint, text, bigint, integer, integer, boolean, boolean
)
  to service_role;
grant execute on function public.complete_account_deletion(bigint, integer, boolean)
  to service_role;
grant execute on function public.defer_account_deletion_finalization(
  bigint, integer, boolean
)
  to service_role;
grant execute on function public.account_deletion_dependency_inventory(uuid)
  to service_role;
grant execute on function public.delete_account_deletion_direct_rows(uuid)
  to service_role;
grant execute on function public.account_deletion_storage_objects(uuid, integer)
  to service_role;
