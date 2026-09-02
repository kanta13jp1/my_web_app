-- Issue #2844 staged rollout controls. These service-role-only functions let
-- operators inspect a due request without exposing user identifiers and let a
-- canary run claim exactly the request that was reviewed.
-- nocheck: time-relative -- the detector reads schema-qualified UPDATE public
-- as table "public"; the actual target is account_deletion_requests, which has
-- no time-relative constraint trigger.

create or replace function public.preflight_due_account_deletion(
  p_request_id bigint default null
)
returns table (
  request_id bigint,
  status text,
  scheduled_for timestamptz,
  attempt_count integer,
  blocking_rows bigint,
  remaining_rows bigint,
  storage_objects bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.account_deletion_requests;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'service_role_required' using errcode = '42501';
  end if;
  if p_request_id is not null and p_request_id <= 0 then
    raise exception 'request_id_must_be_positive' using errcode = '22023';
  end if;

  select candidate.*
    into v_request
  from public.account_deletion_requests as candidate
  where (p_request_id is null or candidate.id = p_request_id)
    and (
      (
        candidate.status in ('pending', 'awaiting_token_expiry', 'failed')
        and candidate.scheduled_for <= now()
        and coalesce(candidate.retry_after, candidate.scheduled_for) <= now()
        and candidate.attempt_count < 10
      ) or (
        candidate.status = 'processing'
        and candidate.processing_started_at < now() - interval '30 minutes'
        and candidate.attempt_count < 10
      )
    )
  order by candidate.scheduled_for, candidate.id
  limit 1;

  if not found or v_request.user_id is null then
    return;
  end if;

  request_id := v_request.id;
  status := v_request.status;
  scheduled_for := v_request.scheduled_for;
  attempt_count := v_request.attempt_count;

  select
    coalesce(sum(inventory.matching_rows) filter (
      where inventory.is_blocking
    ), 0),
    coalesce(sum(inventory.matching_rows) filter (
      where inventory.deletion_strategy <> 'retain_90_days'
    ), 0)
    into blocking_rows, remaining_rows
  from public.account_deletion_dependency_inventory(
    v_request.user_id
  ) as inventory;

  select count(*)
    into storage_objects
  from storage.objects as object_record
  where coalesce(
    nullif(to_jsonb(object_record) ->> 'owner_id', ''),
    nullif(to_jsonb(object_record) ->> 'owner', '')
  ) = v_request.user_id::text
    or split_part(object_record.name, '/', 1) = v_request.user_id::text
    or (
      object_record.bucket_id = 'ai-generated-images'
      and split_part(object_record.name, '/', 1) = 'openai'
      and split_part(object_record.name, '/', 2) = v_request.user_id::text
    );

  return next;
end;
$$;

comment on function public.preflight_due_account_deletion(bigint) is
  'Returns a non-PII, non-mutating deletion inventory for the next or specified due request.';

create or replace function public.claim_due_account_deletion_by_id(
  p_request_id bigint
)
returns setof public.account_deletion_requests
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'service_role_required' using errcode = '42501';
  end if;
  if p_request_id is null or p_request_id <= 0 then
    raise exception 'request_id_must_be_positive' using errcode = '22023';
  end if;

  return query
  with candidate as (
    select request.id
    from public.account_deletion_requests as request
    where request.id = p_request_id
      and (
        (
          request.status in ('pending', 'awaiting_token_expiry', 'failed')
          and request.scheduled_for <= now()
          and coalesce(request.retry_after, request.scheduled_for) <= now()
          and request.attempt_count < 10
        ) or (
          request.status = 'processing'
          and request.processing_started_at < now() - interval '30 minutes'
          and request.attempt_count < 10
        )
      )
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

comment on function public.claim_due_account_deletion_by_id(bigint) is
  'Atomically claims one reviewed due request for a staged deletion canary.';

revoke all on function public.preflight_due_account_deletion(bigint)
  from public, anon, authenticated;
revoke all on function public.claim_due_account_deletion_by_id(bigint)
  from public, anon, authenticated;

grant execute on function public.preflight_due_account_deletion(bigint)
  to service_role;
grant execute on function public.claim_due_account_deletion_by_id(bigint)
  to service_role;
