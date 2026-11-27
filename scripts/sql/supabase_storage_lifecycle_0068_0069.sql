-- Isolated restore only. Official supabase/storage commit 7a0dd891f5133e1831cbf430ec79e24b303c3006
-- 0068-bucket-lifecycle-configuration.sql
-- Add lifecycle configuration.

ALTER TABLE storage.buckets
ADD COLUMN IF NOT EXISTS lifecycle_configuration jsonb,
ADD COLUMN IF NOT EXISTS lifecycle_configuration_generation uuid;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_constraint
    WHERE conrelid = 'storage.buckets'::regclass
      AND conname = 'buckets_lifecycle_configuration_pair_check'
  ) THEN
    ALTER TABLE storage.buckets
    ADD CONSTRAINT buckets_lifecycle_configuration_pair_check CHECK (
      (lifecycle_configuration IS NULL) =
      (lifecycle_configuration_generation IS NULL)
    ) NOT VALID;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_constraint
    WHERE conrelid = 'storage.buckets'::regclass
      AND conname = 'buckets_lifecycle_configuration_shape_check'
  ) THEN
    ALTER TABLE storage.buckets
    ADD CONSTRAINT buckets_lifecycle_configuration_shape_check CHECK (
      lifecycle_configuration IS NULL
      OR (
        jsonb_typeof(lifecycle_configuration) = 'object'
        AND lifecycle_configuration ? 'rules'
        AND CASE
          WHEN jsonb_typeof(lifecycle_configuration -> 'rules') = 'array'
            THEN jsonb_array_length(lifecycle_configuration -> 'rules') BETWEEN 1 AND 1000
          ELSE false
        END
      )
    ) NOT VALID;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_constraint
    WHERE conrelid = 'storage.buckets'::regclass
      AND conname = 'buckets_lifecycle_configuration_standard_only_check'
  ) THEN
    ALTER TABLE storage.buckets
    ADD CONSTRAINT buckets_lifecycle_configuration_standard_only_check CHECK (
      type = 'STANDARD'
      OR (
        lifecycle_configuration IS NULL
        AND lifecycle_configuration_generation IS NULL
      )
    ) NOT VALID;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION storage.protect_bucket_control_columns()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
DECLARE
  configuration_changed boolean;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.lifecycle_configuration IS NOT NULL
       OR NEW.lifecycle_configuration_generation IS NOT NULL THEN
      IF NOT pg_has_role(current_user, TG_ARGV[0], 'MEMBER') THEN
        RAISE EXCEPTION 'only members of the configured storage service role may insert lifecycle policy state'
          USING ERRCODE = '42501',
                HINT = format(
                  'Insert with both lifecycle columns NULL and configure lifecycle through the Storage API afterward, or insert as a member of %I.',
                  TG_ARGV[0]
                );
      END IF;
    END IF;

    RETURN NEW;
  END IF;

  configuration_changed =
    OLD.lifecycle_configuration IS DISTINCT FROM NEW.lifecycle_configuration
    OR OLD.lifecycle_configuration_generation IS DISTINCT FROM NEW.lifecycle_configuration_generation;

  IF NOT configuration_changed THEN
    RETURN NEW;
  END IF;

  IF NEW.type IS DISTINCT FROM 'STANDARD' THEN
    RAISE EXCEPTION 'bucket versioning and lifecycle controls require a Standard bucket'
      USING ERRCODE = '0A000';
  END IF;

  IF NEW.lifecycle_configuration IS NULL
     AND NEW.lifecycle_configuration_generation IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.lifecycle_configuration IS NULL
     OR NEW.lifecycle_configuration_generation IS NULL
     OR OLD.lifecycle_configuration IS NOT DISTINCT FROM NEW.lifecycle_configuration
     OR OLD.lifecycle_configuration_generation IS NOT DISTINCT FROM NEW.lifecycle_configuration_generation THEN
    RAISE EXCEPTION 'a changed lifecycle policy requires a new non-null generation'
      USING ERRCODE = '22023';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION storage.enforce_bucket_lifecycle_service_role()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
  IF current_user::text IS DISTINCT FROM TG_ARGV[0]
     AND (
       OLD.lifecycle_configuration IS DISTINCT FROM NEW.lifecycle_configuration
       OR OLD.lifecycle_configuration_generation IS DISTINCT FROM NEW.lifecycle_configuration_generation
     ) THEN
    -- AFTER runs only after caller RLS has accepted the proposed row. The API
    -- recognizes this specific error after rolling back its permission probe;
    -- direct non-service writes still fail and cannot persist the change.
    RAISE EXCEPTION 'bucket control columns may only be changed by the configured storage service role'
      USING ERRCODE = 'PST01',
            SCHEMA = TG_TABLE_SCHEMA,
            TABLE = TG_TABLE_NAME,
            CONSTRAINT = TG_NAME;
  END IF;

  RETURN NULL;
END;
$$;

DO $$
DECLARE
  service_role text = COALESCE(current_setting('storage.service_role', true), 'service_role');
BEGIN
  DROP TRIGGER IF EXISTS protect_bucket_control_insert ON storage.buckets;
  EXECUTE format(
    'CREATE TRIGGER protect_bucket_control_insert BEFORE INSERT ON storage.buckets FOR EACH ROW EXECUTE FUNCTION storage.protect_bucket_control_columns(%L)',
    service_role
  );

  DROP TRIGGER IF EXISTS protect_bucket_control_update ON storage.buckets;
  CREATE TRIGGER protect_bucket_control_update
    BEFORE UPDATE OF lifecycle_configuration, lifecycle_configuration_generation ON storage.buckets
    FOR EACH ROW EXECUTE FUNCTION storage.protect_bucket_control_columns();

  DROP TRIGGER IF EXISTS protect_bucket_control_update_role ON storage.buckets;
  EXECUTE format(
    'CREATE TRIGGER protect_bucket_control_update_role AFTER UPDATE OF lifecycle_configuration, lifecycle_configuration_generation ON storage.buckets FOR EACH ROW EXECUTE FUNCTION storage.enforce_bucket_lifecycle_service_role(%L)',
    service_role
  );
END;
$$;

-- 0069-validate-bucket-lifecycle-constraints.sql
ALTER TABLE storage.buckets
VALIDATE CONSTRAINT buckets_lifecycle_configuration_pair_check;

ALTER TABLE storage.buckets
VALIDATE CONSTRAINT buckets_lifecycle_configuration_shape_check;

ALTER TABLE storage.buckets
VALIDATE CONSTRAINT buckets_lifecycle_configuration_standard_only_check;

-- 0076-noncurrent-lifecycle.sql (Isolated restore only)
-- Add durable lifecycle execution state with one row per bucket.

CREATE TABLE IF NOT EXISTS storage.bucket_lifecycle_states (
    bucket_id text PRIMARY KEY,
    generation uuid,
    next_run_at timestamptz,
    claim_id uuid,
    claim_until timestamptz,
    continuation jsonb,
    last_started_at timestamptz,
    last_completed_at timestamptz,
    last_success_at timestamptz,
    last_result jsonb,
    failure_count integer NOT NULL DEFAULT 0,
    last_error jsonb,
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT bucket_lifecycle_states_bucket_id_fkey
      FOREIGN KEY (bucket_id)
      REFERENCES storage.buckets(id)
      ON DELETE CASCADE,

    CONSTRAINT bucket_lifecycle_failure_count_check
      CHECK (failure_count >= 0),

    CONSTRAINT bucket_lifecycle_continuation_object_check
      CHECK (
        continuation IS NULL
        OR jsonb_typeof(continuation) = 'object'
      ),

    CONSTRAINT bucket_lifecycle_recovery_due_check
      CHECK (
        next_run_at IS NOT NULL
        OR NOT jsonb_path_exists(
          COALESCE(continuation, '{}'::jsonb),
          '$.batch.inFlight'
        )
      ),

    CONSTRAINT bucket_lifecycle_last_result_object_check
      CHECK (
        last_result IS NULL
        OR jsonb_typeof(last_result) = 'object'
      )
);

DO $$
BEGIN
    IF NOT (SELECT relrowsecurity FROM pg_catalog.pg_class
            WHERE oid = 'storage.bucket_lifecycle_states'::regclass) THEN
        ALTER TABLE storage.bucket_lifecycle_states ENABLE ROW LEVEL SECURITY;
    END IF;
    IF to_regclass('storage.bucket_lifecycle_states_due_idx') IS NULL THEN
        CREATE INDEX IF NOT EXISTS bucket_lifecycle_states_due_idx
        ON storage.bucket_lifecycle_states (next_run_at, bucket_id)
        WHERE next_run_at IS NOT NULL;
    END IF;
END;
$$;

DO $$
DECLARE
    anon_role text = COALESCE(current_setting('storage.anon_role', true), 'anon');
    authenticated_role text = COALESCE(current_setting('storage.authenticated_role', true), 'authenticated');
    service_role text = COALESCE(current_setting('storage.service_role', true), 'service_role');
    super_user text = COALESCE(current_setting('storage.super_user', true), 'postgres');
    role_name text;
BEGIN
    REVOKE ALL ON TABLE storage.bucket_lifecycle_states FROM PUBLIC;

    FOREACH role_name IN ARRAY ARRAY[anon_role, authenticated_role]
    LOOP
      IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = role_name) THEN
        EXECUTE format('REVOKE ALL ON TABLE storage.bucket_lifecycle_states FROM %I', role_name);
      END IF;
    END LOOP;

    FOREACH role_name IN ARRAY ARRAY['postgres', super_user, service_role]
    LOOP
      IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = role_name) THEN
        EXECUTE format('GRANT ALL ON TABLE storage.bucket_lifecycle_states TO %I', role_name);
      END IF;
    END LOOP;
END;
$$;

-- 0079-lifecycle-writer-coordination.sql (Isolated restore only)
-- Lock buckets before installing triggers and backfilling lifecycle state,
-- so bucket writes cannot race with the backfill. This migration does not
-- touch objects avoiding a lock cycle with object writers.
-- Try briefly and pause between attempts so writers queued behind the lock
-- request wait for one attempt at most while another transaction blocks it.
-- Give up after the caller's lock_timeout, or a minute when unset, so the
-- runner can retry instead of leaving callers waiting indefinitely.
DO $$
DECLARE
    previous_lock_timeout text := current_setting('lock_timeout');
    deadline timestamptz := clock_timestamp() + CASE previous_lock_timeout
        WHEN '0' THEN interval '1 minute'
        ELSE previous_lock_timeout::interval
    END;
BEGIN
    LOOP
        -- PostgreSQL lock_timeout uses milliseconds.
        -- Never set it to zero because that would disable the timeout.
        PERFORM set_config(
            'lock_timeout',
            greatest(1, least(250, floor(extract(epoch FROM deadline - clock_timestamp()) * 1000)))::text || 'ms',
            true
        );
        BEGIN
            LOCK TABLE storage.buckets IN EXCLUSIVE MODE;
            EXIT;
        EXCEPTION WHEN lock_not_available THEN
            IF clock_timestamp() >= deadline THEN
                RAISE;
            END IF;
            PERFORM pg_sleep(greatest(0, least(2, extract(epoch FROM deadline - clock_timestamp()))));
            IF clock_timestamp() >= deadline THEN
                RAISE;
            END IF;
        END;
    END LOOP;
    PERFORM set_config('lock_timeout', previous_lock_timeout, true);
END;
$$;

-- Older builds rely on the foreign key to delete lifecycle state with the bucket.
-- Allow this only when there is no in-flight batch and the continuation is understood.
-- The check does not change state so a later trigger can still cancel the deletion.
CREATE OR REPLACE FUNCTION storage.protect_active_lifecycle_states()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM storage.bucket_lifecycle_states
        WHERE bucket_id = OLD.id
          AND NOT (
              continuation IS NULL
              OR (continuation @> '{"continuationVersion": 1}' AND continuation #> '{batch,inFlight}' IS NULL)
          )
    ) THEN
        RAISE EXCEPTION 'update or delete on table "buckets" violates foreign key constraint "bucket_lifecycle_states_bucket_id_fkey" on table "bucket_lifecycle_states"'
            USING ERRCODE = 'foreign_key_violation',
                  DETAIL = format('Key (id)=(%s) is still referenced from table "bucket_lifecycle_states".', OLD.id),
                  SCHEMA = 'storage',
                  TABLE = 'bucket_lifecycle_states',
                  CONSTRAINT = 'bucket_lifecycle_states_bucket_id_fkey';
    END IF;
    RETURN OLD;
END;
$$;

REVOKE ALL ON FUNCTION storage.protect_active_lifecycle_states() FROM PUBLIC;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_trigger
        WHERE tgrelid = 'storage.buckets'::regclass AND tgname = 'protect_active_lifecycle_states'
    ) THEN
        CREATE TRIGGER protect_active_lifecycle_states
        BEFORE DELETE ON storage.buckets
        FOR EACH ROW
        EXECUTE FUNCTION storage.protect_active_lifecycle_states();
    END IF;
END;
$$;

-- Policy changes reset pending work but an in-flight batch must finish
-- recovery before its state can be cleared.
CREATE OR REPLACE FUNCTION storage.reconcile_lifecycle_state(target_bucket_id text, policy_changed boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
DECLARE
    bucket storage.buckets%ROWTYPE;
    active boolean;
    idle boolean;
    state_generation uuid;
BEGIN
    SELECT * INTO bucket FROM storage.buckets WHERE id = target_bucket_id FOR NO KEY UPDATE;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    SELECT continuation IS NULL OR (
               continuation @> '{"continuationVersion": 1}'
               AND continuation #> '{batch,inFlight}' IS NULL
           ), generation
    INTO idle, state_generation
    FROM storage.bucket_lifecycle_states
    WHERE bucket_id = target_bucket_id
    FOR UPDATE;

    IF bucket.lifecycle_configuration IS NULL THEN
        DELETE FROM storage.bucket_lifecycle_states
        WHERE bucket_id = target_bucket_id
          AND idle IS TRUE;

        UPDATE storage.bucket_lifecycle_states
        SET next_run_at = clock_timestamp(), updated_at = clock_timestamp()
        WHERE bucket_id = target_bucket_id
          AND idle IS NOT TRUE;
        RETURN;
    END IF;

    active := bucket.versioning_status <> 'DISABLED'
        AND bucket.lifecycle_configuration @> '{"rules":[{"status":"Enabled"}]}'::jsonb;

    -- The state row records the generation it was reconciled with so callers need not detect
    -- policy changes. Rows without a recorded generation keep their work.
    policy_changed := policy_changed OR (
        state_generation IS NOT NULL AND state_generation <> bucket.lifecycle_configuration_generation
    );

    INSERT INTO storage.bucket_lifecycle_states AS state (bucket_id, generation, next_run_at)
    VALUES (bucket.id, bucket.lifecycle_configuration_generation, CASE WHEN active THEN clock_timestamp() END)
    ON CONFLICT (bucket_id) DO UPDATE
    SET next_run_at = CASE
            WHEN policy_changed THEN
                CASE WHEN active OR idle IS NOT TRUE THEN clock_timestamp() END
            ELSE EXCLUDED.next_run_at
        END,
        generation = EXCLUDED.generation,
        claim_id = CASE WHEN policy_changed AND idle IS TRUE
                        THEN NULL ELSE state.claim_id END,
        claim_until = CASE WHEN policy_changed AND idle IS TRUE
                           THEN NULL ELSE state.claim_until END,
        continuation = CASE WHEN policy_changed AND idle IS TRUE
                            THEN NULL ELSE state.continuation END,
        failure_count = CASE WHEN policy_changed AND idle IS TRUE
                             THEN 0 ELSE state.failure_count END,
        last_error = CASE WHEN policy_changed AND idle IS TRUE
                          THEN NULL ELSE state.last_error END,
        updated_at = clock_timestamp()
    WHERE policy_changed OR (state.next_run_at IS NULL AND EXCLUDED.next_run_at IS NOT NULL);
END;
$$;

REVOKE ALL ON FUNCTION storage.reconcile_lifecycle_state(text, boolean) FROM PUBLIC;

DO $$
DECLARE
    role_name text;
BEGIN
    FOR role_name IN
        SELECT DISTINCT acl.grantee::regrole::text
        FROM pg_catalog.pg_proc AS proc, pg_catalog.aclexplode(proc.proacl) AS acl
        WHERE proc.oid = 'storage.reconcile_lifecycle_state(text, boolean)'::regprocedure
          AND acl.grantee NOT IN (0, proc.proowner)
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION storage.reconcile_lifecycle_state(text, boolean) FROM %s', role_name);
    END LOOP;

    FOREACH role_name IN ARRAY ARRAY[
        'postgres',
        COALESCE(current_setting('storage.super_user', true), 'postgres'),
        COALESCE(current_setting('storage.service_role', true), 'service_role')
    ] LOOP
        IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = role_name) THEN
            EXECUTE format('GRANT EXECUTE ON FUNCTION storage.reconcile_lifecycle_state(text, boolean) TO %I', role_name);
        END IF;
    END LOOP;
END;
$$;

-- OrioleDB can give AFTER triggers identical OLD/NEW images for a changed row so waking never compares them.
CREATE OR REPLACE FUNCTION storage.wake_lifecycle_state()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.lifecycle_configuration IS NULL THEN
        RETURN NEW;
    END IF;

    PERFORM storage.reconcile_lifecycle_state(NEW.id, false);
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION storage.wake_lifecycle_state() FROM PUBLIC;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_trigger
        WHERE tgrelid = 'storage.buckets'::regclass AND tgname = 'wake_lifecycle_on_versioning_enable'
    ) THEN
        CREATE TRIGGER wake_lifecycle_on_versioning_enable
        AFTER UPDATE OF versioning_status ON storage.buckets
        FOR EACH ROW
        WHEN (NEW.lifecycle_configuration IS NOT NULL)
        EXECUTE FUNCTION storage.wake_lifecycle_state();
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_trigger
        WHERE tgrelid = 'storage.buckets'::regclass AND tgname = 'wake_lifecycle_on_policy_write'
    ) THEN
        CREATE TRIGGER wake_lifecycle_on_policy_write
        AFTER INSERT OR UPDATE OF lifecycle_configuration_generation ON storage.buckets
        FOR EACH ROW
        EXECUTE FUNCTION storage.wake_lifecycle_state();
    END IF;
END;
$$;

-- Delete metadata and record deleted IDs in the same transaction before
-- deleting backend bytes. Blocked rows keep both their metadata and bytes.
-- Deleting metadata also prevents new foreign-key references during recovery.
CREATE OR REPLACE FUNCTION storage.delete_lifecycle_objects(object_ids uuid[])
RETURNS TABLE(id uuid, is_delete_marker boolean, metadata jsonb)
LANGUAGE plpgsql
AS $$
DECLARE
    object_id uuid;
    deleted_row storage.objects%ROWTYPE;
    deleted_ids uuid[];
    deleted_markers boolean[];
    deleted_metadata jsonb[];
    bulk_deleted boolean := false;
BEGIN
    -- Surface pre-existing deferred violations instead of treating them as blocked rows.
    SET CONSTRAINTS ALL IMMEDIATE;
    PERFORM set_config('storage.allow_delete_query', 'true', true);

    -- One subxact keeps the subxid cache from overflowing; rows return only once it commits.
    BEGIN
        WITH deleted AS (
            DELETE FROM storage.objects AS object_row
              WHERE object_row.id = ANY(object_ids) AND object_row.archived_at IS NOT NULL
              RETURNING object_row.id, object_row.is_delete_marker, object_row.metadata
        )
        SELECT array_agg(deleted.id), array_agg(deleted.is_delete_marker), array_agg(deleted.metadata)
          INTO deleted_ids, deleted_markers, deleted_metadata
          FROM deleted;
        bulk_deleted := true;
    EXCEPTION
        WHEN OTHERS THEN
            -- User triggers may use insufficient_privilege to block a row.
            IF SQLSTATE <> '42501' AND left(SQLSTATE, 2) IN ('08', '40', '42', '53', '55', '57', '58', 'XX') THEN
                RAISE;
            END IF;
    END;
    IF bulk_deleted THEN
        RETURN QUERY SELECT * FROM unnest(deleted_ids, deleted_markers, deleted_metadata);
        RETURN;
    END IF;

    FOREACH object_id IN ARRAY object_ids LOOP
        BEGIN
            DELETE FROM storage.objects AS object_row
              WHERE object_row.id = object_id AND object_row.archived_at IS NOT NULL
              RETURNING object_row.* INTO deleted_row;
            IF FOUND THEN
                id := deleted_row.id;
                is_delete_marker := deleted_row.is_delete_marker;
                metadata := deleted_row.metadata;
                RETURN NEXT;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLSTATE <> '42501' AND left(SQLSTATE, 2) IN ('08', '40', '42', '53', '55', '57', '58', 'XX') THEN
                    RAISE;
                END IF;
        END;
    END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION storage.delete_lifecycle_objects(uuid[]) FROM PUBLIC;

DO $$
DECLARE
    role_name text;
BEGIN
    FOR role_name IN
        SELECT DISTINCT acl.grantee::regrole::text
        FROM pg_catalog.pg_proc AS proc, pg_catalog.aclexplode(proc.proacl) AS acl
        WHERE proc.oid = 'storage.delete_lifecycle_objects(uuid[])'::regprocedure
          AND acl.grantee NOT IN (0, proc.proowner)
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION storage.delete_lifecycle_objects(uuid[]) FROM %s', role_name);
    END LOOP;

    FOREACH role_name IN ARRAY ARRAY[
        'postgres',
        COALESCE(current_setting('storage.super_user', true), 'postgres'),
        COALESCE(current_setting('storage.service_role', true), 'service_role')
    ] LOOP
        IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = role_name) THEN
            EXECUTE format('GRANT EXECUTE ON FUNCTION storage.delete_lifecycle_objects(uuid[]) TO %I', role_name);
        END IF;
    END LOOP;
END;
$$;

CREATE TABLE IF NOT EXISTS storage.lifecycle_abandoned_artifacts (
    bucket_id text NOT NULL,
    key text NOT NULL,
    name text NOT NULL,
    version text,
    attempted_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (bucket_id, key)
);

DO $$
BEGIN
    IF NOT (SELECT relrowsecurity FROM pg_catalog.pg_class
            WHERE oid = 'storage.lifecycle_abandoned_artifacts'::regclass) THEN
        ALTER TABLE storage.lifecycle_abandoned_artifacts ENABLE ROW LEVEL SECURITY;
    END IF;
    IF to_regclass('storage.lifecycle_abandoned_artifacts_attempted_at_idx') IS NULL THEN
        CREATE INDEX IF NOT EXISTS lifecycle_abandoned_artifacts_attempted_at_idx
          ON storage.lifecycle_abandoned_artifacts (attempted_at);
    END IF;
END;
$$;

DO $$
DECLARE
    anon_role text = COALESCE(current_setting('storage.anon_role', true), 'anon');
    authenticated_role text = COALESCE(current_setting('storage.authenticated_role', true), 'authenticated');
    service_role text = COALESCE(current_setting('storage.service_role', true), 'service_role');
    super_user text = COALESCE(current_setting('storage.super_user', true), 'postgres');
    role_name text;
BEGIN
    REVOKE ALL ON TABLE storage.lifecycle_abandoned_artifacts FROM PUBLIC;

    FOREACH role_name IN ARRAY ARRAY[anon_role, authenticated_role]
    LOOP
      IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = role_name) THEN
        EXECUTE format('REVOKE ALL ON TABLE storage.lifecycle_abandoned_artifacts FROM %I', role_name);
      END IF;
    END LOOP;

    FOREACH role_name IN ARRAY ARRAY['postgres', super_user, service_role]
    LOOP
      IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = role_name) THEN
        EXECUTE format('GRANT ALL ON TABLE storage.lifecycle_abandoned_artifacts TO %I', role_name);
      END IF;
    END LOOP;
END;
$$;

-- Repair missing/dormant state without resetting existing schedules or journals.
SELECT storage.reconcile_lifecycle_state(id, false)
FROM storage.buckets
WHERE lifecycle_configuration IS NOT NULL;

-- 0080-revoke-extra-lifecycle-postgres-grants.sql (Isolated restore only)
-- Retain read access for dumps while removing the extra write and execute
-- grants, unless postgres is a configured role or owns the object.
DO $$
DECLARE
    postgres_oid oid;
    super_user text = COALESCE(current_setting('storage.super_user', true), 'postgres');
    service_role text = COALESCE(current_setting('storage.service_role', true), 'service_role');
BEGIN
    SELECT oid INTO postgres_oid FROM pg_catalog.pg_roles WHERE rolname = 'postgres';
    IF postgres_oid IS NULL OR 'postgres' IN (super_user, service_role) THEN
        RETURN;
    END IF;

    IF (SELECT relowner FROM pg_catalog.pg_class WHERE oid = 'storage.bucket_lifecycle_states'::regclass) <> postgres_oid THEN
        REVOKE ALL ON TABLE storage.bucket_lifecycle_states FROM postgres;
        GRANT SELECT ON TABLE storage.bucket_lifecycle_states TO postgres;
    END IF;
    IF (SELECT relowner FROM pg_catalog.pg_class WHERE oid = 'storage.lifecycle_abandoned_artifacts'::regclass) <> postgres_oid THEN
        REVOKE ALL ON TABLE storage.lifecycle_abandoned_artifacts FROM postgres;
        GRANT SELECT ON TABLE storage.lifecycle_abandoned_artifacts TO postgres;
    END IF;
    IF (SELECT proowner FROM pg_catalog.pg_proc WHERE oid = 'storage.reconcile_lifecycle_state(text, boolean)'::regprocedure) <> postgres_oid THEN
        REVOKE ALL ON FUNCTION storage.reconcile_lifecycle_state(text, boolean) FROM postgres;
    END IF;
    IF (SELECT proowner FROM pg_catalog.pg_proc WHERE oid = 'storage.delete_lifecycle_objects(uuid[])'::regprocedure) <> postgres_oid THEN
        REVOKE ALL ON FUNCTION storage.delete_lifecycle_objects(uuid[]) FROM postgres;
    END IF;
END;
$$;
