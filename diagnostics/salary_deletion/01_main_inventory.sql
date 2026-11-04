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