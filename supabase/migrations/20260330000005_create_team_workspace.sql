-- Team workspace: teams + team_memberships + team_shared_notes
-- Session: daily-development 2026-03-30 #3

-- teams table
CREATE TABLE IF NOT EXISTS teams (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text NOT NULL DEFAULT '',
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  invite_code text UNIQUE NOT NULL DEFAULT substr(md5(random()::text), 1, 8),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE teams ENABLE ROW LEVEL SECURITY;

-- insert/update/delete policies (no cross-table reference)
CREATE POLICY "teams_insert" ON teams FOR INSERT WITH CHECK (owner_id = auth.uid());
CREATE POLICY "teams_update" ON teams FOR UPDATE USING (owner_id = auth.uid());
CREATE POLICY "teams_delete" ON teams FOR DELETE USING (owner_id = auth.uid());

-- team_memberships table
CREATE TABLE IF NOT EXISTS team_memberships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id uuid NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'member' CHECK (role IN ('member', 'admin')),
  joined_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (team_id, user_id)
);

ALTER TABLE team_memberships ENABLE ROW LEVEL SECURITY;

CREATE POLICY "team_memberships_select" ON team_memberships FOR SELECT
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM teams t WHERE t.id = team_memberships.team_id AND t.owner_id = auth.uid()
    )
  );

CREATE POLICY "team_memberships_insert" ON team_memberships FOR INSERT
  WITH CHECK (
    -- team owner can add members, or user can join via invite code (handled at app layer)
    EXISTS (
      SELECT 1 FROM teams t WHERE t.id = team_memberships.team_id AND t.owner_id = auth.uid()
    ) OR user_id = auth.uid()
  );

CREATE POLICY "team_memberships_delete" ON team_memberships FOR DELETE
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM teams t WHERE t.id = team_memberships.team_id AND t.owner_id = auth.uid()
    )
  );

-- NOW create teams_select policy (after team_memberships exists)
CREATE POLICY "teams_select" ON teams FOR SELECT
  USING (
    owner_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM team_memberships tm
      WHERE tm.team_id = teams.id AND tm.user_id = auth.uid()
    )
  );

-- team_shared_notes: link notes to teams
CREATE TABLE IF NOT EXISTS team_shared_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id uuid NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  note_id bigint NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  shared_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  shared_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (team_id, note_id)
);

ALTER TABLE team_shared_notes ENABLE ROW LEVEL SECURITY;

-- team members can read shared notes metadata
CREATE POLICY "team_shared_notes_select" ON team_shared_notes FOR SELECT
  USING (
    shared_by = auth.uid() OR
    EXISTS (
      SELECT 1 FROM team_memberships tm
      WHERE tm.team_id = team_shared_notes.team_id AND tm.user_id = auth.uid()
    ) OR
    EXISTS (
      SELECT 1 FROM teams t WHERE t.id = team_shared_notes.team_id AND t.owner_id = auth.uid()
    )
  );

CREATE POLICY "team_shared_notes_insert" ON team_shared_notes FOR INSERT
  WITH CHECK (
    shared_by = auth.uid() AND (
      EXISTS (
        SELECT 1 FROM team_memberships tm
        WHERE tm.team_id = team_shared_notes.team_id AND tm.user_id = auth.uid()
      ) OR
      EXISTS (
        SELECT 1 FROM teams t WHERE t.id = team_shared_notes.team_id AND t.owner_id = auth.uid()
      )
    )
  );

CREATE POLICY "team_shared_notes_delete" ON team_shared_notes FOR DELETE
  USING (
    shared_by = auth.uid() OR
    EXISTS (
      SELECT 1 FROM teams t WHERE t.id = team_shared_notes.team_id AND t.owner_id = auth.uid()
    )
  );

-- indexes
CREATE INDEX IF NOT EXISTS idx_team_memberships_user_id ON team_memberships(user_id);
CREATE INDEX IF NOT EXISTS idx_team_memberships_team_id ON team_memberships(team_id);
CREATE INDEX IF NOT EXISTS idx_team_shared_notes_team_id ON team_shared_notes(team_id);
CREATE INDEX IF NOT EXISTS idx_team_shared_notes_note_id ON team_shared_notes(note_id);
