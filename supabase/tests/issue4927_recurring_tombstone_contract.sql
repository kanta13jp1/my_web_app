-- Runtime PostgreSQL contract for Issue #4927. Any mismatch raises and fails
-- the Testcontainers integration smoke.

insert into auth.users (id)
values ('00000000-0000-4000-8000-000000004927'::uuid)
on conflict (id) do nothing;

-- Exercise the trigger itself rather than relying on ambient table grants in
-- the disposable Testcontainers database.
grant select, insert, update, delete on public.asset_pref_mirror
  to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000004927',
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('app.recurring_tombstone_rpc', 'sentinel', true);

do $contract$
declare
  v_value jsonb;
begin
  v_value := public.apply_recurring_fixed_cost_tombstones(
    array['alpha', 'beta', '', ' alpha ', null]::text[],
    array[]::text[]
  );
  if v_value -> 'ids' is distinct from '["alpha", "beta"]'::jsonb then
    raise exception 'initial tombstone normalization failed: %', v_value;
  end if;

  if current_setting('app.recurring_tombstone_rpc', true)
    is distinct from 'sentinel'
  then
    raise exception 'RPC guard marker was not restored after success';
  end if;

  v_value := public.apply_recurring_fixed_cost_tombstones(
    array['gamma', 'same']::text[],
    array[' beta ', null, '', 'same']::text[]
  );
  if v_value -> 'ids' is distinct from '["alpha", "gamma"]'::jsonb then
    raise exception 'atomic add/remove contract failed: %', v_value;
  end if;

  v_value := public.apply_recurring_fixed_cost_tombstones(
    null,
    array[null, ' ']::text[]
  );
  if v_value -> 'ids' is distinct from '["alpha", "gamma"]'::jsonb then
    raise exception 'NULL input contract failed: %', v_value;
  end if;

  if exists (
    select 1
    from pg_catalog.pg_proc as procedure
    where procedure.oid =
      'public.apply_recurring_fixed_cost_tombstones(text[],text[])'::regprocedure
      and (
        not procedure.prosecdef
        or not has_function_privilege(
          'authenticated',
          procedure.oid,
          'execute'
        )
        or has_function_privilege('anon', procedure.oid, 'execute')
      )
  ) then
    raise exception 'RPC privilege contract is invalid';
  end if;
end;
$contract$;

-- An authenticated caller can set a custom GUC, so the guard must also prove
-- that the write is executing under the SECURITY DEFINER RPC owner.
select set_config('app.recurring_tombstone_rpc', 'on', true);
do $guard$
begin
  begin
    insert into public.asset_pref_mirror (user_id, pref_key, value)
    values (
      auth.uid(),
      'recurring_fixed_costs_deleted',
      '{"ids": ["insert-bypass"]}'::jsonb
    );
    raise exception 'direct protected insert unexpectedly succeeded';
  exception
    when insufficient_privilege then null;
  end;

  begin
    update public.asset_pref_mirror
    set value = '{"ids": ["update-bypass"]}'::jsonb
    where user_id = auth.uid()
      and pref_key = 'recurring_fixed_costs_deleted';
    raise exception 'direct protected update unexpectedly succeeded';
  exception
    when insufficient_privilege then null;
  end;

  begin
    update public.asset_pref_mirror
    set pref_key = 'renamed-away'
    where user_id = auth.uid()
      and pref_key = 'recurring_fixed_costs_deleted';
    raise exception 'protected-key rename unexpectedly succeeded';
  exception
    when insufficient_privilege then null;
  end;

  begin
    delete from public.asset_pref_mirror
    where user_id = auth.uid()
      and pref_key = 'recurring_fixed_costs_deleted';
    raise exception 'direct protected delete unexpectedly succeeded';
  exception
    when insufficient_privilege then null;
  end;

  insert into public.asset_pref_mirror (user_id, pref_key, value)
  values (auth.uid(), 'issue4927_unrelated', '{"ok": true}'::jsonb);

  update public.asset_pref_mirror
  set value = '{"ok": false}'::jsonb,
      pref_key = 'issue4927_unrelated_renamed'
  where user_id = auth.uid()
    and pref_key = 'issue4927_unrelated';

  begin
    update public.asset_pref_mirror
    set pref_key = 'recurring_fixed_costs_deleted'
    where user_id = auth.uid()
      and pref_key = 'issue4927_unrelated_renamed';
    raise exception 'rename into protected key unexpectedly succeeded';
  exception
    when insufficient_privilege then null;
  end;

  delete from public.asset_pref_mirror
  where user_id = auth.uid()
    and pref_key = 'issue4927_unrelated_renamed';
end;
$guard$;

-- The successful RPC restored the marker; a direct write immediately after an
-- RPC in the same transaction is still rejected.
select set_config('app.recurring_tombstone_rpc', 'sentinel', true);
do $post_rpc_guard$
begin
  perform public.apply_recurring_fixed_cost_tombstones(
    array['post-rpc']::text[],
    array[]::text[]
  );
  if current_setting('app.recurring_tombstone_rpc', true)
    is distinct from 'sentinel'
  then
    raise exception 'RPC guard marker leaked after call';
  end if;

  begin
    update public.asset_pref_mirror
    set value = '{"ids": ["post-rpc-bypass"]}'::jsonb
    where user_id = auth.uid()
      and pref_key = 'recurring_fixed_costs_deleted';
    raise exception 'post-RPC direct write unexpectedly succeeded';
  exception
    when insufficient_privilege then null;
  end;
end;
$post_rpc_guard$;

reset role;

-- Owner-only fixture mutation poisons the row with mixed JSON element types.
-- The RPC must reject it without changing the row.
select set_config('app.recurring_tombstone_rpc', 'on', true);
update public.asset_pref_mirror
set value = '{"ids": ["valid", 42, {}, null]}'::jsonb
where user_id = '00000000-0000-4000-8000-000000004927'::uuid
  and pref_key = 'recurring_fixed_costs_deleted';
select set_config('app.recurring_tombstone_rpc', 'off', true);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000004927',
  true
);
do $malformed$
begin
  begin
    perform public.apply_recurring_fixed_cost_tombstones(
      array['must-not-overwrite']::text[],
      array[]::text[]
    );
    raise exception 'mixed-type mirror unexpectedly accepted';
  exception
    when invalid_parameter_value then null;
  end;

  if (
    select value
    from public.asset_pref_mirror
    where user_id = auth.uid()
      and pref_key = 'recurring_fixed_costs_deleted'
  ) is distinct from '{"ids": ["valid", 42, {}, null]}'::jsonb then
    raise exception 'malformed rejection changed the protected row';
  end if;
end;
$malformed$;
reset role;

select set_config('app.recurring_tombstone_rpc', 'on', true);
update public.asset_pref_mirror
set value = '{"ids": []}'::jsonb
where user_id = '00000000-0000-4000-8000-000000004927'::uuid
  and pref_key = 'recurring_fixed_costs_deleted';
select set_config('app.recurring_tombstone_rpc', 'off', true);
