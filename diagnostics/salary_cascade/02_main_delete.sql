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