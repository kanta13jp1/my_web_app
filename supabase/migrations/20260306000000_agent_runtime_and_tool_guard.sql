-- Agent runtime hardening
-- Created: 2026-03-06
-- Purpose:
-- 1) Strict memory-layer separation
-- 2) Periodic runtime job functions (heartbeat/nightly/forgetting)
-- 3) Tool execution audit log for fail-close guard

-- ---------------------------------------------------------------------------
-- 1) Strict memory-layer separation for agent_memories
-- ---------------------------------------------------------------------------

ALTER TABLE agent_memories
    DROP CONSTRAINT IF EXISTS agent_memories_memory_layer_check;

UPDATE agent_memories
SET memory_layer = 'episodes'
WHERE memory_layer = 'episode';

UPDATE agent_memories
SET memory_layer = 'activity_log'
WHERE memory_layer IN ('handoff', 'forgetting');

UPDATE agent_memories
SET memory_layer = 'knowledge'
WHERE memory_layer IN ('rag', 'consolidation');

UPDATE agent_memories
SET memory_layer = 'state'
WHERE memory_layer IN ('priming', 'identity_note', 'contradiction');

ALTER TABLE agent_memories
    ADD CONSTRAINT agent_memories_memory_layer_check
    CHECK (
        memory_layer IN (
            'episodes',
            'knowledge',
            'procedures',
            'skills',
            'state',
            'activity_log'
        )
    );

ALTER TABLE agent_memories
    ALTER COLUMN memory_layer SET DEFAULT 'episodes';

-- ---------------------------------------------------------------------------
-- 2) Runtime job run-log
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS agent_runtime_job_runs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    job_type text NOT NULL CHECK (
        job_type IN (
            'heartbeat',
            'nightly_consolidation',
            'forgetting',
            'runtime_cycle'
        )
    ),
    status text NOT NULL DEFAULT 'success' CHECK (
        status IN ('success', 'partial', 'failed')
    ),
    processed_agents int NOT NULL DEFAULT 0,
    detail jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_agent_runtime_job_runs_created
    ON agent_runtime_job_runs(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_agent_runtime_job_runs_user_created
    ON agent_runtime_job_runs(user_id, created_at DESC);

ALTER TABLE agent_runtime_job_runs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Agent runtime jobs select own org" ON agent_runtime_job_runs;
DROP POLICY IF EXISTS "Agent runtime jobs insert own org" ON agent_runtime_job_runs;
DROP POLICY IF EXISTS "Agent runtime jobs update own org" ON agent_runtime_job_runs;
DROP POLICY IF EXISTS "Agent runtime jobs delete own org" ON agent_runtime_job_runs;

CREATE POLICY "Agent runtime jobs select own org" ON agent_runtime_job_runs
    FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);
CREATE POLICY "Agent runtime jobs insert own org" ON agent_runtime_job_runs
    FOR INSERT WITH CHECK (auth.uid() = user_id OR user_id IS NULL);
CREATE POLICY "Agent runtime jobs update own org" ON agent_runtime_job_runs
    FOR UPDATE USING (auth.uid() = user_id OR user_id IS NULL);
CREATE POLICY "Agent runtime jobs delete own org" ON agent_runtime_job_runs
    FOR DELETE USING (auth.uid() = user_id OR user_id IS NULL);

-- ---------------------------------------------------------------------------
-- 3) Tool execution logs (fail-close audit)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS agent_tool_execution_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    actor_agent_id uuid REFERENCES agents(id) ON DELETE SET NULL,
    tool_name text NOT NULL,
    allowed boolean NOT NULL DEFAULT false,
    blocked_reason text,
    payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_agent_tool_execution_logs_user_created
    ON agent_tool_execution_logs(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_agent_tool_execution_logs_actor_created
    ON agent_tool_execution_logs(actor_agent_id, created_at DESC);

ALTER TABLE agent_tool_execution_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Agent tool logs select own org" ON agent_tool_execution_logs;
DROP POLICY IF EXISTS "Agent tool logs insert own org" ON agent_tool_execution_logs;
DROP POLICY IF EXISTS "Agent tool logs update own org" ON agent_tool_execution_logs;
DROP POLICY IF EXISTS "Agent tool logs delete own org" ON agent_tool_execution_logs;

CREATE POLICY "Agent tool logs select own org" ON agent_tool_execution_logs
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Agent tool logs insert own org" ON agent_tool_execution_logs
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Agent tool logs update own org" ON agent_tool_execution_logs
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Agent tool logs delete own org" ON agent_tool_execution_logs
    FOR DELETE USING (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 4) Runtime functions
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION run_agent_heartbeat(
    p_user_id uuid DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_count integer := 0;
    v_agent record;
    v_open_tasks integer;
BEGIN
    FOR v_agent IN
        SELECT id, user_id, display_name
        FROM agents
        WHERE status = 'active'
          AND (p_user_id IS NULL OR user_id = p_user_id)
    LOOP
        SELECT COUNT(*)
        INTO v_open_tasks
        FROM agent_tasks
        WHERE user_id = v_agent.user_id
          AND assignee_agent_id = v_agent.id
          AND status <> 'completed';

        INSERT INTO agent_memories (
            user_id,
            agent_id,
            memory_layer,
            content,
            source,
            metadata
        )
        VALUES (
            v_agent.user_id,
            v_agent.id,
            'state',
            format('Heartbeat: %s open tasks=%s', v_agent.display_name, v_open_tasks),
            'runtime_heartbeat',
            jsonb_build_object(
                'job', 'heartbeat',
                'open_tasks', v_open_tasks
            )
        );

        UPDATE agents
        SET last_active_at = now()
        WHERE id = v_agent.id
          AND user_id = v_agent.user_id;

        v_count := v_count + 1;
    END LOOP;

    INSERT INTO agent_runtime_job_runs (
        user_id,
        job_type,
        status,
        processed_agents,
        detail
    )
    VALUES (
        p_user_id,
        'heartbeat',
        'success',
        v_count,
        jsonb_build_object('scope_user_id', p_user_id)
    );

    RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION run_agent_nightly_consolidation(
    p_user_id uuid DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_count integer := 0;
    v_agent record;
    v_episode_summary text;
    v_completed_meeting_actions integer;
BEGIN
    FOR v_agent IN
        SELECT id, user_id, display_name
        FROM agents
        WHERE status = 'active'
          AND (p_user_id IS NULL OR user_id = p_user_id)
    LOOP
        SELECT string_agg(content, E'\n- ' ORDER BY created_at DESC)
        INTO v_episode_summary
        FROM (
            SELECT content, created_at
            FROM agent_memories
            WHERE user_id = v_agent.user_id
              AND agent_id = v_agent.id
              AND memory_layer IN ('episodes', 'activity_log')
              AND created_at >= now() - interval '1 day'
            ORDER BY created_at DESC
            LIMIT 5
        ) recent_memory;

        IF v_episode_summary IS NOT NULL THEN
            INSERT INTO agent_memories (
                user_id,
                agent_id,
                memory_layer,
                content,
                source,
                metadata
            )
            VALUES (
                v_agent.user_id,
                v_agent.id,
                'knowledge',
                format('Nightly consolidation:%s- %s', E'\n', v_episode_summary),
                'runtime_nightly',
                jsonb_build_object('job', 'nightly_consolidation')
            );
        END IF;

        SELECT COUNT(*)
        INTO v_completed_meeting_actions
        FROM agent_tasks
        WHERE user_id = v_agent.user_id
          AND assignee_agent_id = v_agent.id
          AND task_type = 'meeting_execution'
          AND status = 'completed'
          AND updated_at >= now() - interval '14 days';

        IF v_completed_meeting_actions >= 3 THEN
            INSERT INTO agent_memories (
                user_id,
                agent_id,
                memory_layer,
                content,
                source,
                metadata
            )
            VALUES (
                v_agent.user_id,
                v_agent.id,
                'procedures',
                'Procedure candidate: meeting_execution tasks complete pattern detected. Keep a 48h execution checklist.',
                'runtime_nightly',
                jsonb_build_object(
                    'job', 'nightly_consolidation',
                    'completed_meeting_actions', v_completed_meeting_actions
                )
            );
        END IF;

        v_count := v_count + 1;
    END LOOP;

    INSERT INTO agent_runtime_job_runs (
        user_id,
        job_type,
        status,
        processed_agents,
        detail
    )
    VALUES (
        p_user_id,
        'nightly_consolidation',
        'success',
        v_count,
        jsonb_build_object('scope_user_id', p_user_id)
    );

    RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION run_agent_memory_forgetting(
    p_user_id uuid DEFAULT NULL,
    p_retention_days integer DEFAULT 30
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_count integer := 0;
    v_agent record;
    v_archived integer := 0;
BEGIN
    FOR v_agent IN
        SELECT id, user_id, display_name
        FROM agents
        WHERE status = 'active'
          AND (p_user_id IS NULL OR user_id = p_user_id)
    LOOP
        WITH updated_rows AS (
            UPDATE agent_memories
            SET metadata = jsonb_set(
                COALESCE(metadata, '{}'::jsonb),
                '{archived_at}',
                to_jsonb(now()),
                true
            )
            WHERE user_id = v_agent.user_id
              AND agent_id = v_agent.id
              AND memory_layer = 'activity_log'
              AND created_at < now() - make_interval(days => p_retention_days)
              AND COALESCE(metadata->>'archived_at', '') = ''
            RETURNING 1
        )
        SELECT COUNT(*) INTO v_archived FROM updated_rows;

        IF v_archived > 0 THEN
            INSERT INTO agent_memories (
                user_id,
                agent_id,
                memory_layer,
                content,
                source,
                metadata
            )
            VALUES (
                v_agent.user_id,
                v_agent.id,
                'activity_log',
                format('Forgetting cycle: archived %s low-value activity logs.', v_archived),
                'runtime_forgetting',
                jsonb_build_object(
                    'job', 'forgetting',
                    'archived_count', v_archived,
                    'retention_days', p_retention_days
                )
            );
        END IF;

        v_count := v_count + 1;
    END LOOP;

    INSERT INTO agent_runtime_job_runs (
        user_id,
        job_type,
        status,
        processed_agents,
        detail
    )
    VALUES (
        p_user_id,
        'forgetting',
        'success',
        v_count,
        jsonb_build_object(
            'scope_user_id', p_user_id,
            'retention_days', p_retention_days
        )
    );

    RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION run_agent_runtime_cycle(
    p_user_id uuid DEFAULT NULL,
    p_run_nightly boolean DEFAULT false,
    p_run_forgetting boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    v_heartbeat integer := 0;
    v_nightly integer := 0;
    v_forgetting integer := 0;
BEGIN
    v_heartbeat := run_agent_heartbeat(p_user_id);
    IF p_run_nightly THEN
        v_nightly := run_agent_nightly_consolidation(p_user_id);
    END IF;
    IF p_run_forgetting THEN
        v_forgetting := run_agent_memory_forgetting(p_user_id, 30);
    END IF;

    INSERT INTO agent_runtime_job_runs (
        user_id,
        job_type,
        status,
        processed_agents,
        detail
    )
    VALUES (
        p_user_id,
        'runtime_cycle',
        'success',
        v_heartbeat + v_nightly + v_forgetting,
        jsonb_build_object(
            'heartbeat_agents', v_heartbeat,
            'nightly_agents', v_nightly,
            'forgetting_agents', v_forgetting,
            'run_nightly', p_run_nightly,
            'run_forgetting', p_run_forgetting
        )
    );

    RETURN jsonb_build_object(
        'heartbeat_agents', v_heartbeat,
        'nightly_agents', v_nightly,
        'forgetting_agents', v_forgetting,
        'run_nightly', p_run_nightly,
        'run_forgetting', p_run_forgetting
    );
END;
$$;

GRANT EXECUTE ON FUNCTION run_agent_heartbeat(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION run_agent_nightly_consolidation(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION run_agent_memory_forgetting(uuid, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION run_agent_runtime_cycle(uuid, boolean, boolean) TO authenticated, service_role;

COMMENT ON TABLE agent_runtime_job_runs IS 'Scheduled runtime job logs for agent heartbeat and memory maintenance';
COMMENT ON TABLE agent_tool_execution_logs IS 'Audit logs for fail-close tool boundary decisions';

-- ---------------------------------------------------------------------------
-- 5) Periodic jobs (pg_cron)
-- ---------------------------------------------------------------------------
DO $$
DECLARE
    v_job_id bigint;
BEGIN
    BEGIN
        CREATE EXTENSION IF NOT EXISTS pg_cron;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'pg_cron extension is not available in this environment.';
            RETURN;
    END;

    SELECT jobid INTO v_job_id
    FROM cron.job
    WHERE jobname = 'agent_runtime_heartbeat_10m'
    LIMIT 1;
    IF v_job_id IS NOT NULL THEN
        PERFORM cron.unschedule(v_job_id);
    END IF;
    PERFORM cron.schedule(
        'agent_runtime_heartbeat_10m',
        '*/10 * * * *',
        $cmd$SELECT run_agent_heartbeat(NULL);$cmd$
    );

    SELECT jobid INTO v_job_id
    FROM cron.job
    WHERE jobname = 'agent_runtime_nightly_knowledge'
    LIMIT 1;
    IF v_job_id IS NOT NULL THEN
        PERFORM cron.unschedule(v_job_id);
    END IF;
    PERFORM cron.schedule(
        'agent_runtime_nightly_knowledge',
        '15 18 * * *',
        $cmd$SELECT run_agent_nightly_consolidation(NULL);$cmd$
    );

    SELECT jobid INTO v_job_id
    FROM cron.job
    WHERE jobname = 'agent_runtime_forgetting_daily'
    LIMIT 1;
    IF v_job_id IS NOT NULL THEN
        PERFORM cron.unschedule(v_job_id);
    END IF;
    PERFORM cron.schedule(
        'agent_runtime_forgetting_daily',
        '25 18 * * *',
        $cmd$SELECT run_agent_memory_forgetting(NULL, 30);$cmd$
    );
END;
$$;
