-- Agent communication and relationship layer
-- Created: 2026-03-05
-- Purpose: add structured communication channels between persistent agents

CREATE TABLE IF NOT EXISTS agent_relationships (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    from_agent_id uuid NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    to_agent_id uuid NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    relationship_type text NOT NULL CHECK (
        relationship_type IN (
            'supervises',
            'reports_to',
            'peer',
            'handoff'
        )
    ),
    communication_protocol text NOT NULL DEFAULT 'structured_brief',
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused')),
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, from_agent_id, to_agent_id, relationship_type)
);

CREATE TABLE IF NOT EXISTS agent_messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    from_agent_id uuid NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    to_agent_id uuid NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    linked_task_id uuid REFERENCES agent_tasks(id) ON DELETE SET NULL,
    conversation_id text,
    message_kind text NOT NULL DEFAULT 'directive' CHECK (
        message_kind IN (
            'directive',
            'brief',
            'status',
            'handoff',
            'question',
            'answer',
            'memory_sync'
        )
    ),
    summary text NOT NULL DEFAULT '',
    payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    status text NOT NULL DEFAULT 'sent' CHECK (
        status IN ('sent', 'acknowledged', 'resolved', 'ignored')
    ),
    acknowledged_at timestamptz,
    resolved_at timestamptz,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_agent_relationships_user_from_to
    ON agent_relationships(user_id, from_agent_id, to_agent_id);

CREATE INDEX IF NOT EXISTS idx_agent_relationships_user_type_status
    ON agent_relationships(user_id, relationship_type, status);

CREATE INDEX IF NOT EXISTS idx_agent_messages_user_to_created
    ON agent_messages(user_id, to_agent_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_agent_messages_user_conversation
    ON agent_messages(user_id, conversation_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_agent_memories_agent_layer_created
    ON agent_memories(agent_id, memory_layer, created_at DESC);

CREATE OR REPLACE FUNCTION set_agent_org_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_agent_relationships_updated_at ON agent_relationships;
CREATE TRIGGER trg_agent_relationships_updated_at
    BEFORE UPDATE ON agent_relationships
    FOR EACH ROW
    EXECUTE FUNCTION set_agent_org_updated_at();

DROP TRIGGER IF EXISTS trg_agent_messages_updated_at ON agent_messages;
CREATE TRIGGER trg_agent_messages_updated_at
    BEFORE UPDATE ON agent_messages
    FOR EACH ROW
    EXECUTE FUNCTION set_agent_org_updated_at();

ALTER TABLE agent_relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Agent relationships select own org" ON agent_relationships;
DROP POLICY IF EXISTS "Agent relationships insert own org" ON agent_relationships;
DROP POLICY IF EXISTS "Agent relationships update own org" ON agent_relationships;
DROP POLICY IF EXISTS "Agent relationships delete own org" ON agent_relationships;

CREATE POLICY "Agent relationships select own org" ON agent_relationships
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Agent relationships insert own org" ON agent_relationships
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Agent relationships update own org" ON agent_relationships
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Agent relationships delete own org" ON agent_relationships
    FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Agent messages select own org" ON agent_messages;
DROP POLICY IF EXISTS "Agent messages insert own org" ON agent_messages;
DROP POLICY IF EXISTS "Agent messages update own org" ON agent_messages;
DROP POLICY IF EXISTS "Agent messages delete own org" ON agent_messages;

CREATE POLICY "Agent messages select own org" ON agent_messages
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Agent messages insert own org" ON agent_messages
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Agent messages update own org" ON agent_messages
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Agent messages delete own org" ON agent_messages
    FOR DELETE USING (auth.uid() = user_id);

COMMENT ON TABLE agent_relationships IS 'Directed relationships between AI agents';
COMMENT ON TABLE agent_messages IS 'Structured messages exchanged between AI agents';
