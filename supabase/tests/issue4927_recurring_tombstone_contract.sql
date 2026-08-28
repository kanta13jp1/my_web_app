-- Runtime PostgreSQL contract for Issue #4927. Any mismatch raises and fails
-- the Testcontainers integration smoke.

insert into auth.users (id)
values ('00000000-0000-4000-8000-000000004927'::uuid)
on conflict (id) do nothing;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000004927',
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);

do $contract$
declare
  v_value jsonb;
begin
  v_value := public.apply_recurring_fixed_cost_tombstones(
    array['alpha', 'beta', '', ' alpha ']::text[],
    array[]::text[]
  );
  if v_value -> 'ids' is distinct from '["alpha", "beta"]'::jsonb then
    raise exception 'initial tombstone normalization failed: %', v_value;
  end if;

  v_value := public.apply_recurring_fixed_cost_tombstones(
    array['gamma', 'same']::text[],
    array[' beta ', null, '', 'same']::text[]
  );
  if v_value -> 'ids' is distinct from '["alpha", "gamma"]'::jsonb then
    raise exception 'atomic add/remove contract failed: %', v_value;
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

reset role;
select set_config('app.recurring_tombstone_rpc', 'off', true);

do $guard$
begin
  begin
    update public.asset_pref_mirror
    set value = '{"ids": ["overwritten"]}'::jsonb
    where user_id = '00000000-0000-4000-8000-000000004927'::uuid
      and pref_key = 'recurring_fixed_costs_deleted';
    raise exception 'direct whole-blob update unexpectedly succeeded';
  exception
    when insufficient_privilege then
      null;
  end;
end;
$guard$;

select set_config('app.recurring_tombstone_rpc', 'on', true);
update public.asset_pref_mirror
set value = '{"ids": "malformed"}'::jsonb
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
    raise exception 'malformed mirror unexpectedly accepted';
  exception
    when invalid_parameter_value then
      null;
  end;
end;
$malformed$;
reset role;

select set_config('app.recurring_tombstone_rpc', 'on', true);
update public.asset_pref_mirror
set value = '{"ids": []}'::jsonb
where user_id = '00000000-0000-4000-8000-000000004927'::uuid
  and pref_key = 'recurring_fixed_costs_deleted';
select set_config('app.recurring_tombstone_rpc', 'off', true);
