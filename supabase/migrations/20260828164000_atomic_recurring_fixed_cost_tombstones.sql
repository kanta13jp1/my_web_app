-- #4927: update recurring-fixed-cost tombstones without whole-blob lost updates.
-- Concurrent devices serialize on the asset_pref_mirror primary key; every write
-- unions additions with the current row and applies explicit removals atomically.

create or replace function public.apply_recurring_fixed_cost_tombstones(
  p_add_ids text[] default array[]::text[],
  p_remove_ids text[] default array[]::text[]
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_existing jsonb;
  v_value jsonb;
begin
  if v_user_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select mirror.value
  into v_existing
  from public.asset_pref_mirror as mirror
  where mirror.user_id = v_user_id
    and mirror.pref_key = 'recurring_fixed_costs_deleted'
  for update;

  if found and (
    jsonb_typeof(v_existing) is distinct from 'object'
    or jsonb_typeof(v_existing -> 'ids') is distinct from 'array'
  ) then
    raise exception 'recurring fixed cost tombstone mirror is malformed'
      using errcode = '22023';
  end if;

  perform set_config('app.recurring_tombstone_rpc', 'on', true);

  insert into public.asset_pref_mirror as mirror (
    user_id,
    pref_key,
    value,
    updated_at
  )
  values (
    v_user_id,
    'recurring_fixed_costs_deleted',
    jsonb_build_object(
      'ids',
      to_jsonb(
        coalesce(
          (
            select array_agg(clean.id order by clean.id)
            from (
              select distinct btrim(raw.id) as id
              from unnest(coalesce(p_add_ids, array[]::text[])) as raw(id)
              where btrim(raw.id) <> ''
                and not exists (
                  select 1
                  from unnest(
                    coalesce(p_remove_ids, array[]::text[])
                  ) as removed(id)
                  where removed.id is not null
                    and btrim(removed.id) <> ''
                    and btrim(removed.id) = btrim(raw.id)
                )
            ) as clean
          ),
          array[]::text[]
        )
      )
    ),
    now()
  )
  on conflict (user_id, pref_key) do update
  set
    value = (
      select jsonb_build_object(
        'ids',
        coalesce(jsonb_agg(merged.id order by merged.id), '[]'::jsonb)
      )
      from (
        select distinct btrim(source.id) as id
        from (
          select jsonb_array_elements_text(
            case
              when jsonb_typeof(mirror.value -> 'ids') = 'array'
                then mirror.value -> 'ids'
              else '[]'::jsonb
            end
          ) as id
          union all
          select jsonb_array_elements_text(
            case
              when jsonb_typeof(excluded.value -> 'ids') = 'array'
                then excluded.value -> 'ids'
              else '[]'::jsonb
            end
          ) as id
        ) as source
        where btrim(source.id) <> ''
          and not exists (
            select 1
            from unnest(
              coalesce(p_remove_ids, array[]::text[])
            ) as removed(id)
            where removed.id is not null
              and btrim(removed.id) <> ''
              and btrim(removed.id) = btrim(source.id)
          )
      ) as merged
    ),
    updated_at = now()
  returning mirror.value into v_value;

  return v_value;
end;
$$;

create or replace function public.guard_recurring_fixed_cost_tombstone_writes()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
begin
  if new.pref_key = 'recurring_fixed_costs_deleted'
    and coalesce(
      current_setting('app.recurring_tombstone_rpc', true),
      ''
    ) <> 'on'
  then
    raise exception 'use apply_recurring_fixed_cost_tombstones()'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_recurring_fixed_cost_tombstone_writes
  on public.asset_pref_mirror;
create trigger guard_recurring_fixed_cost_tombstone_writes
before insert or update on public.asset_pref_mirror
for each row
execute function public.guard_recurring_fixed_cost_tombstone_writes();

revoke all on function public.apply_recurring_fixed_cost_tombstones(text[], text[])
  from public;
revoke all on function public.apply_recurring_fixed_cost_tombstones(text[], text[])
  from anon;
grant execute on function public.apply_recurring_fixed_cost_tombstones(text[], text[])
  to authenticated;

comment on function public.apply_recurring_fixed_cost_tombstones(text[], text[])
is 'Atomically union/remove recurring fixed-cost tombstone IDs for auth.uid() (#4927).';

revoke all on function public.guard_recurring_fixed_cost_tombstone_writes()
  from public, anon, authenticated;
