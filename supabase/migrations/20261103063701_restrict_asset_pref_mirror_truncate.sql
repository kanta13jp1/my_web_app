-- DRAFT ONLY. Not applied. Review runtime roles, all writers and rollback first.
-- Stops atomically if effective privileges or relation owner differ from reviewed state.
begin;
do $$
declare
 role_name text;
 privilege_name text;
 privilege_names text[] := array['SELECT','INSERT','UPDATE','DELETE','REFERENCES','TRIGGER'];
 target_oid oid := 'public.asset_pref_mirror'::regclass;
 owner_name name;
 service_before boolean;
begin
 if pg_catalog.current_setting('server_version_num')::integer >= 170000 then
  privilege_names := pg_catalog.array_append(privilege_names, 'MAINTAIN');
 end if;
 select pg_catalog.pg_get_userbyid(c.relowner) into strict owner_name
 from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
 where c.oid=target_oid and n.nspname='public' and c.relname='asset_pref_mirror'
   and c.relkind in ('r','p') and c.relrowsecurity;
 if owner_name is distinct from 'postgres' then raise exception 'unexpected owner'; end if;
 foreach role_name in array array['anon','authenticated'] loop
  if not pg_catalog.has_table_privilege(role_name,target_oid,'TRUNCATE') then
   raise exception 'unexpected starting truncate privilege'; end if;
  foreach privilege_name in array privilege_names loop
   if not pg_catalog.has_table_privilege(role_name,target_oid,privilege_name) then
    raise exception 'unexpected starting table privileges'; end if;
  end loop;
 end loop;
 service_before:=pg_catalog.has_table_privilege('service_role',target_oid,'TRUNCATE');
 execute 'revoke truncate on table public.asset_pref_mirror from anon, authenticated';
 foreach role_name in array array['anon','authenticated'] loop
  if pg_catalog.has_table_privilege(role_name,target_oid,'TRUNCATE') then
   raise exception 'remaining effective truncate privilege'; end if;
  foreach privilege_name in array privilege_names loop
   if not pg_catalog.has_table_privilege(role_name,target_oid,privilege_name) then
    raise exception 'unrelated table privilege changed'; end if;
  end loop;
 end loop;
 if pg_catalog.has_table_privilege('service_role',target_oid,'TRUNCATE') is distinct from service_before then
  raise exception 'service role changed'; end if;
end $$;
commit;