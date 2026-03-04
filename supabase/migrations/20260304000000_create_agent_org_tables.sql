-- Agent organization foundation
-- Created: 2026-03-04
-- Purpose: add persistent AI agent registry, delegated tasks, and memory logs

CREATE TABLE IF NOT EXISTS agents (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    slug text NOT NULL,
    display_name text NOT NULL,
    role_title text NOT NULL,
    department text NOT NULL,
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused')),
    identity_prompt text NOT NULL DEFAULT '',
    permissions_summary text NOT NULL DEFAULT '',
    supervisor_agent_id uuid REFERENCES agents(id) ON DELETE SET NULL,
    last_active_at timestamptz,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, slug)
);

CREATE TABLE IF NOT EXISTS agent_tasks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    supervisor_agent_id uuid NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    assignee_agent_id uuid NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    title text NOT NULL,
    description text NOT NULL DEFAULT '',
    status text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'in_progress', 'completed', 'cancelled')),
    priority text NOT NULL DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high')),
    task_type text NOT NULL DEFAULT 'delegated_action',
    source text NOT NULL DEFAULT 'manual_delegate',
    completed_at timestamptz,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS agent_memories (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    agent_id uuid NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    memory_layer text NOT NULL DEFAULT 'episode' CHECK (
        memory_layer IN (
            'priming',
            'rag',
            'consolidation',
            'forgetting',
            'contradiction',
            'episode',
            'handoff',
            'identity_note'
        )
    ),
    content text NOT NULL,
    source text NOT NULL DEFAULT 'manual_note',
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_agents_user_status
    ON agents(user_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_agents_supervisor
    ON agents(supervisor_agent_id);

CREATE INDEX IF NOT EXISTS idx_agent_tasks_user_status
    ON agent_tasks(user_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_agent_tasks_assignee
    ON agent_tasks(assignee_agent_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_agent_memories_agent_created
    ON agent_memories(agent_id, created_at DESC);

CREATE OR REPLACE FUNCTION set_agent_org_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_agents_updated_at ON agents;
CREATE TRIGGER trg_agents_updated_at
    BEFORE UPDATE ON agents
    FOR EACH ROW
    EXECUTE FUNCTION set_agent_org_updated_at();

DROP TRIGGER IF EXISTS trg_agent_tasks_updated_at ON agent_tasks;
CREATE TRIGGER trg_agent_tasks_updated_at
    BEFORE UPDATE ON agent_tasks
    FOR EACH ROW
    EXECUTE FUNCTION set_agent_org_updated_at();

ALTER TABLE agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_memories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Agents select own org" ON agents;
DROP POLICY IF EXISTS "Agents insert own org" ON agents;
DROP POLICY IF EXISTS "Agents update own org" ON agents;
DROP POLICY IF EXISTS "Agents delete own org" ON agents;

CREATE POLICY "Agents select own org" ON agents
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Agents insert own org" ON agents
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Agents update own org" ON agents
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Agents delete own org" ON agents
    FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Agent tasks select own org" ON agent_tasks;
DROP POLICY IF EXISTS "Agent tasks insert own org" ON agent_tasks;
DROP POLICY IF EXISTS "Agent tasks update own org" ON agent_tasks;
DROP POLICY IF EXISTS "Agent tasks delete own org" ON agent_tasks;

CREATE POLICY "Agent tasks select own org" ON agent_tasks
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Agent tasks insert own org" ON agent_tasks
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Agent tasks update own org" ON agent_tasks
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Agent tasks delete own org" ON agent_tasks
    FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Agent memories select own org" ON agent_memories;
DROP POLICY IF EXISTS "Agent memories insert own org" ON agent_memories;
DROP POLICY IF EXISTS "Agent memories update own org" ON agent_memories;
DROP POLICY IF EXISTS "Agent memories delete own org" ON agent_memories;

CREATE POLICY "Agent memories select own org" ON agent_memories
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Agent memories insert own org" ON agent_memories
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Agent memories update own org" ON agent_memories
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Agent memories delete own org" ON agent_memories
    FOR DELETE USING (auth.uid() = user_id);

COMMENT ON TABLE agents IS 'Persistent AI agent registry for each user organization';
COMMENT ON TABLE agent_tasks IS 'Delegated tasks between persistent AI agents';
COMMENT ON TABLE agent_memories IS 'Persistent memory stack log for each AI agent';
