-- No game telemetry is stored. Reuses private quota counters; expense limits are unchanged.
-- Called only by ai-hub after verified, non-anonymous user authentication.
-- All three reservations commit together; no read/write race across isolates.
create function public.reserve_jev_mario_call(p_user_id uuid)
returns boolean language plpgsql security invoker set search_path = '' as $$
declare
  epoch_seconds bigint := extract(epoch from clock_timestamp())::bigint;
  scopes text[] := array['mario:global:day', 'mario:' || p_user_id::text || ':day', 'mario:' || p_user_id::text || ':minute'];
  buckets bigint[] := array[epoch_seconds / 86400, epoch_seconds / 86400, epoch_seconds / 60];
  limits integer[] := array[3000, 1000, 300];
  previous public.jev_expense_quota%rowtype;
  i integer;
begin
  if p_user_id is null then return false; end if;
  perform pg_catalog.pg_advisory_xact_lock(20260921, 5466);
  for i in 1..3 loop
    select * into previous from public.jev_expense_quota where scope = scopes[i];
    if found and previous.bucket = buckets[i] and previous.used >= limits[i] then
      return false;
    end if;
  end loop;
  for i in 1..3 loop
    insert into public.jev_expense_quota(scope, bucket, used)
      values (scopes[i], buckets[i], 1)
      on conflict (scope) do update set
        used = case when jev_expense_quota.bucket = excluded.bucket
          then jev_expense_quota.used + 1 else 1 end,
        bucket = excluded.bucket;
  end loop;
  return true;
end;
$$;
revoke all on function public.reserve_jev_mario_call(uuid) from public, anon, authenticated;
grant execute on function public.reserve_jev_mario_call(uuid) to service_role;
