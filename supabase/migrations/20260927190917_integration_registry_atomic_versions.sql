-- Issue #1237: immutable, owner-scoped integration history.
-- Apply transactionally. Invalid/duplicate history must fail, never be repaired
-- by this migration. The constraint/index validate all pre-existing rows.
BEGIN;

ALTER TABLE public.hub_data ADD CONSTRAINT integration_registry_valid_history
CHECK (source NOT IN (
  'integration_registry_system', 'integration_registry_interface',
  'integration_registry_mapping'
) OR ((
  jsonb_typeof(metadata) = 'object'
  AND jsonb_typeof(metadata->'user_id') = 'string'
  AND metadata->>'user_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  AND jsonb_typeof(metadata->(CASE source
    WHEN 'integration_registry_system' THEN 'system_key'
    WHEN 'integration_registry_interface' THEN 'interface_key'
    ELSE 'mapping_key' END)) = 'string'
  AND metadata->>(CASE source
    WHEN 'integration_registry_system' THEN 'system_key'
    WHEN 'integration_registry_interface' THEN 'interface_key'
    ELSE 'mapping_key' END) ~ '^[a-z0-9_-]{1,80}$'
  AND jsonb_typeof(metadata->'version') = 'number'
  AND metadata->>'version' ~ '^[1-9][0-9]{0,8}$'
) IS TRUE));

CREATE UNIQUE INDEX integration_registry_owner_key_version_unique
ON public.hub_data (
  (metadata->>'user_id'), source,
  (metadata->>(CASE source
    WHEN 'integration_registry_system' THEN 'system_key'
    WHEN 'integration_registry_interface' THEN 'interface_key'
    ELSE 'mapping_key' END)),
  ((metadata->>'version')::integer)
)
WHERE source IN ('integration_registry_system',
  'integration_registry_interface', 'integration_registry_mapping');

-- Existing hub_data policies permit owner writes for unrelated sources. Do not
-- broaden or remove them; protect only these immutable server-managed sources.
CREATE FUNCTION public.guard_integration_registry_history()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
BEGIN
  IF TG_OP <> 'INSERT' AND OLD.source IN ('integration_registry_system',
      'integration_registry_interface', 'integration_registry_mapping') THEN
    RAISE EXCEPTION 'Integration history is immutable' USING ERRCODE = '42501';
  END IF;
  IF TG_OP <> 'DELETE' AND NEW.source IN ('integration_registry_system',
      'integration_registry_interface', 'integration_registry_mapping') THEN
    IF TG_OP <> 'INSERT' OR current_user <> 'service_role' THEN
      RAISE EXCEPTION 'Integration history requires server insert'
        USING ERRCODE = '42501';
    END IF;
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.guard_integration_registry_history() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER guard_integration_registry_history
BEFORE INSERT OR UPDATE OR DELETE ON public.hub_data
FOR EACH ROW EXECUTE FUNCTION public.guard_integration_registry_history();

CREATE FUNCTION public.insert_integration_registry_version(
  p_source text, p_user_id uuid, p_metadata jsonb
) RETURNS public.hub_data
LANGUAGE plpgsql VOLATILE SECURITY INVOKER SET search_path = '' AS $$
DECLARE
  key_field text;
  registry_key text;
  next_version integer;
  result public.hub_data;
BEGIN
  IF current_user <> 'service_role' THEN
    RAISE EXCEPTION 'Server role required' USING ERRCODE = '42501';
  END IF;
  key_field := CASE p_source
    WHEN 'integration_registry_system' THEN 'system_key'
    WHEN 'integration_registry_interface' THEN 'interface_key'
    WHEN 'integration_registry_mapping' THEN 'mapping_key'
    ELSE NULL END;
  IF key_field IS NULL OR p_user_id IS NULL
      OR jsonb_typeof(p_metadata) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'Invalid integration registry input' USING ERRCODE = '22023';
  END IF;
  registry_key := p_metadata->>key_field;
  IF jsonb_typeof(p_metadata->key_field) IS DISTINCT FROM 'string'
      OR registry_key IS NULL OR registry_key !~ '^[a-z0-9_-]{1,80}$' THEN
    RAISE EXCEPTION 'Invalid integration registry key' USING ERRCODE = '22023';
  END IF;

  -- Transaction-scoped: always released on commit/rollback. Hash collisions
  -- only serialize unrelated keys; the unique index remains authoritative.
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'integration-registry:' || p_user_id::text || ':' || p_source || ':' || registry_key, 0));
  SELECT coalesce(max((h.metadata->>'version')::integer), 0) + 1
    INTO next_version
    FROM public.hub_data h
    WHERE h.source = p_source AND h.metadata->>'user_id' = p_user_id::text
      AND h.metadata->>key_field = registry_key;
  IF next_version > 999999999 THEN
    RAISE EXCEPTION 'Integration version exhausted' USING ERRCODE = '22003';
  END IF;
  INSERT INTO public.hub_data(source, metadata)
    VALUES (p_source, p_metadata || jsonb_build_object(
      'user_id', p_user_id::text, 'version', next_version))
    RETURNING * INTO result;
  RETURN result;
END;
$$;
REVOKE ALL ON FUNCTION public.insert_integration_registry_version(text, uuid, jsonb)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.insert_integration_registry_version(text, uuid, jsonb)
  TO service_role;

COMMIT;
