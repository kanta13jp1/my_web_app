-- Issue #2668: make note comment authorization fail closed.
-- nocheck: time-relative -- UPDATE targets team_memberships only; no date trigger applies.
--
-- The original feature accumulated two generations of permissive policies.
-- PostgreSQL ORs permissive policies, so adding a stricter policy without
-- removing every legacy policy would leave the old write path open.

CREATE SCHEMA IF NOT EXISTS note_comments_private;
REVOKE ALL ON SCHEMA note_comments_private FROM PUBLIC;
GRANT USAGE ON SCHEMA note_comments_private TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION note_comments_private.owns_note(p_note_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.notes AS n
    WHERE n.id = p_note_id
      AND n.user_id = (SELECT auth.uid())
  )
$$;

CREATE OR REPLACE FUNCTION note_comments_private.owns_team(p_team_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.teams AS t
    WHERE t.id = p_team_id
      AND t.owner_id = (SELECT auth.uid())
  )
$$;

ALTER TABLE public.team_memberships
  ADD COLUMN IF NOT EXISTS invite_verified_at timestamptz;

CREATE OR REPLACE FUNCTION note_comments_private.can_participate_in_team(p_team_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.teams AS t
    WHERE t.id = p_team_id
      AND (
        t.owner_id = (SELECT auth.uid())
        OR EXISTS (
          SELECT 1
          FROM public.team_memberships AS tm
          WHERE tm.team_id = t.id
            AND tm.user_id = (SELECT auth.uid())
            AND tm.invite_verified_at IS NOT NULL
        )
      )
  )
$$;

CREATE OR REPLACE FUNCTION note_comments_private.is_valid_team_note_share(
  p_team_id uuid,
  p_note_id bigint,
  p_shared_by uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    note_comments_private.can_participate_in_team(p_team_id)
    AND EXISTS (
      SELECT 1
      FROM public.notes AS n
      WHERE n.id = p_note_id
        AND n.user_id = p_shared_by
    )
$$;

CREATE OR REPLACE FUNCTION note_comments_private.can_access_note_comments(p_note_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.notes AS n
    WHERE n.id = p_note_id
      AND (
        n.user_id = (SELECT auth.uid())
        OR EXISTS (
          SELECT 1
          FROM public.public_memos AS pm
          WHERE pm.note_id = n.id
            AND pm.user_id = n.user_id
            AND pm.is_public IS TRUE
        )
        OR (
          (SELECT auth.uid()) IS NOT NULL
          AND EXISTS (
            SELECT 1
            FROM public.team_shared_notes AS tsn
            JOIN public.teams AS t ON t.id = tsn.team_id
            WHERE tsn.note_id = n.id
              AND tsn.shared_by = n.user_id
              AND (
                t.owner_id = (SELECT auth.uid())
                OR EXISTS (
                  SELECT 1
                  FROM public.team_memberships AS tm
                  WHERE tm.team_id = t.id
                    AND tm.user_id = (SELECT auth.uid())
                    AND tm.invite_verified_at IS NOT NULL
                )
              )
          )
        )
      )
  )
$$;

CREATE OR REPLACE FUNCTION note_comments_private.can_read_public_memo(p_public_memo_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.public_memos AS pm
    JOIN public.notes AS n
      ON n.id = pm.note_id
     AND n.user_id = pm.user_id
    WHERE pm.id = p_public_memo_id
      AND (
        pm.is_public IS TRUE
        OR pm.user_id = (SELECT auth.uid())
      )
  )
$$;

REVOKE ALL ON FUNCTION note_comments_private.owns_note(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION note_comments_private.owns_team(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION note_comments_private.can_participate_in_team(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION note_comments_private.is_valid_team_note_share(uuid, bigint, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION note_comments_private.can_access_note_comments(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION note_comments_private.can_read_public_memo(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION note_comments_private.owns_note(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION note_comments_private.owns_team(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION note_comments_private.can_participate_in_team(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION note_comments_private.is_valid_team_note_share(uuid, bigint, uuid)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION note_comments_private.can_access_note_comments(bigint)
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION note_comments_private.can_read_public_memo(bigint)
  TO anon, authenticated, service_role;

-- A public memo is authoritative only when its user owns the referenced note.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'public_memos_note_id_fkey'
      AND conrelid = 'public.public_memos'::regclass
  ) THEN
    ALTER TABLE public.public_memos
      ADD CONSTRAINT public_memos_note_id_fkey
      FOREIGN KEY (note_id) REFERENCES public.notes(id) ON DELETE CASCADE
      NOT VALID;
  END IF;
END
$$;

DROP POLICY IF EXISTS "Public memos viewable by all" ON public.public_memos;
DROP POLICY IF EXISTS "Users can insert own public memos" ON public.public_memos;
DROP POLICY IF EXISTS "Users can update own public memos" ON public.public_memos;
DROP POLICY IF EXISTS "Users can delete own public memos" ON public.public_memos;
DROP POLICY IF EXISTS public_memos_select_authorized ON public.public_memos;
DROP POLICY IF EXISTS public_memos_insert_owner ON public.public_memos;
DROP POLICY IF EXISTS public_memos_update_owner ON public.public_memos;
DROP POLICY IF EXISTS public_memos_delete_owner ON public.public_memos;

CREATE POLICY public_memos_select_authorized
  ON public.public_memos FOR SELECT TO anon, authenticated
  USING (note_comments_private.can_read_public_memo(id));

CREATE POLICY public_memos_insert_owner
  ON public.public_memos FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT auth.uid())
    AND note_comments_private.owns_note(note_id)
  );

CREATE POLICY public_memos_update_owner
  ON public.public_memos FOR UPDATE TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    AND note_comments_private.owns_note(note_id)
  )
  WITH CHECK (
    user_id = (SELECT auth.uid())
    AND note_comments_private.owns_note(note_id)
  );

CREATE POLICY public_memos_delete_owner
  ON public.public_memos FOR DELETE TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    AND note_comments_private.owns_note(note_id)
  );

-- Direct self-join is no longer an authorization path. Existing rows remain
-- intact but do not grant comment access until re-verified by invite code.
DROP POLICY IF EXISTS "team_memberships_select" ON public.team_memberships;
DROP POLICY IF EXISTS "team_memberships_insert" ON public.team_memberships;
DROP POLICY IF EXISTS "team_memberships_delete" ON public.team_memberships;
DROP POLICY IF EXISTS team_memberships_select_authorized ON public.team_memberships;
DROP POLICY IF EXISTS team_memberships_insert_owner ON public.team_memberships;
DROP POLICY IF EXISTS team_memberships_delete_authorized ON public.team_memberships;

CREATE POLICY team_memberships_select_authorized
  ON public.team_memberships FOR SELECT TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR note_comments_private.owns_team(team_id)
  );

CREATE POLICY team_memberships_insert_owner
  ON public.team_memberships FOR INSERT TO authenticated
  WITH CHECK (note_comments_private.owns_team(team_id));

CREATE POLICY team_memberships_delete_authorized
  ON public.team_memberships FOR DELETE TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR note_comments_private.owns_team(team_id)
  );

CREATE OR REPLACE FUNCTION note_comments_private.stamp_owner_added_membership()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.teams AS t
    WHERE t.id = NEW.team_id
      AND t.owner_id = (SELECT auth.uid())
  ) THEN
    NEW.invite_verified_at := COALESCE(NEW.invite_verified_at, clock_timestamp());
  ELSIF (SELECT auth.uid()) IS NOT NULL THEN
    NEW.invite_verified_at := NULL;
  END IF;
  RETURN NEW;
END
$$;

REVOKE ALL ON FUNCTION note_comments_private.stamp_owner_added_membership() FROM PUBLIC;
DROP TRIGGER IF EXISTS stamp_owner_added_membership ON public.team_memberships;
CREATE TRIGGER stamp_owner_added_membership
  BEFORE INSERT ON public.team_memberships
  FOR EACH ROW EXECUTE FUNCTION note_comments_private.stamp_owner_added_membership();

REVOKE ALL ON public.team_memberships FROM PUBLIC, anon, authenticated;
GRANT SELECT, DELETE ON public.team_memberships TO authenticated;
GRANT INSERT (team_id, user_id, role) ON public.team_memberships TO authenticated;
GRANT ALL ON public.team_memberships TO service_role;

-- The legacy teams policy trusted every membership row and exposed invite_code.
-- Only owners and verified members may read the team row after this migration.
DROP POLICY IF EXISTS "teams_select" ON public.teams;
DROP POLICY IF EXISTS teams_select_authorized ON public.teams;
CREATE POLICY teams_select_authorized
  ON public.teams FOR SELECT TO authenticated
  USING (
    owner_id = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1
      FROM public.team_memberships AS tm
      WHERE tm.team_id = teams.id
        AND tm.user_id = (SELECT auth.uid())
        AND tm.invite_verified_at IS NOT NULL
    )
  );

CREATE TABLE IF NOT EXISTS note_comments_private.team_invite_attempts (
  user_id uuid PRIMARY KEY,
  window_started_at timestamptz NOT NULL,
  attempt_count integer NOT NULL CHECK (attempt_count > 0)
);
REVOKE ALL ON note_comments_private.team_invite_attempts FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.join_team_with_invite_code(p_invite_code text)
RETURNS TABLE (team_id uuid, team_name text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_team_id uuid;
  v_team_name text;
  v_code text := btrim(p_invite_code);
  v_attempt_count integer;
  v_now timestamptz := clock_timestamp();
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Authentication required';
  END IF;

  INSERT INTO note_comments_private.team_invite_attempts AS attempts (
    user_id,
    window_started_at,
    attempt_count
  )
  VALUES (v_actor, v_now, 1)
  ON CONFLICT (user_id) DO UPDATE
  SET
    window_started_at = CASE
      WHEN attempts.window_started_at < v_now - interval '15 minutes' THEN v_now
      ELSE attempts.window_started_at
    END,
    attempt_count = CASE
      WHEN attempts.window_started_at < v_now - interval '15 minutes' THEN 1
      ELSE attempts.attempt_count + 1
    END
  RETURNING attempt_count INTO v_attempt_count;

  IF v_attempt_count > 10 THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'Invite attempts temporarily limited';
  END IF;

  IF v_code = '' OR char_length(v_code) > 128 THEN
    RETURN;
  END IF;

  SELECT t.id, t.name
  INTO v_team_id, v_team_name
  FROM public.teams AS t
  WHERE t.invite_code = v_code;

  IF v_team_id IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.team_memberships (team_id, user_id, role)
  VALUES (v_team_id, v_actor, 'member')
  ON CONFLICT ON CONSTRAINT team_memberships_team_id_user_id_key DO NOTHING;

  UPDATE public.team_memberships AS tm
  SET invite_verified_at = clock_timestamp()
  WHERE tm.team_id = v_team_id
    AND tm.user_id = v_actor;

  RETURN QUERY SELECT v_team_id, v_team_name;
END
$$;

REVOKE ALL ON FUNCTION public.join_team_with_invite_code(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.join_team_with_invite_code(text)
  TO authenticated, service_role;

ALTER TABLE public.teams
  ALTER COLUMN invite_code SET DEFAULT replace(gen_random_uuid()::text, '-', '');

-- A team share is valid only when the sharer owns the note and participates in
-- the team. Old forged rows remain stored but grant no access.
DROP POLICY IF EXISTS "team_shared_notes_select" ON public.team_shared_notes;
DROP POLICY IF EXISTS "team_shared_notes_insert" ON public.team_shared_notes;
DROP POLICY IF EXISTS "team_shared_notes_delete" ON public.team_shared_notes;
DROP POLICY IF EXISTS team_shared_notes_select_authorized ON public.team_shared_notes;
DROP POLICY IF EXISTS team_shared_notes_insert_note_owner ON public.team_shared_notes;
DROP POLICY IF EXISTS team_shared_notes_delete_authorized ON public.team_shared_notes;

CREATE POLICY team_shared_notes_select_authorized
  ON public.team_shared_notes FOR SELECT TO authenticated
  USING (note_comments_private.is_valid_team_note_share(team_id, note_id, shared_by));

CREATE POLICY team_shared_notes_insert_note_owner
  ON public.team_shared_notes FOR INSERT TO authenticated
  WITH CHECK (
    shared_by = (SELECT auth.uid())
    AND note_comments_private.owns_note(note_id)
    AND note_comments_private.can_participate_in_team(team_id)
  );

CREATE POLICY team_shared_notes_delete_authorized
  ON public.team_shared_notes FOR DELETE TO authenticated
  USING (
    shared_by = (SELECT auth.uid())
    OR note_comments_private.owns_team(team_id)
  );

REVOKE ALL ON public.team_shared_notes FROM PUBLIC, anon, authenticated;
GRANT SELECT, DELETE ON public.team_shared_notes TO authenticated;
GRANT INSERT (team_id, note_id, shared_by) ON public.team_shared_notes
  TO authenticated;
GRANT ALL ON public.team_shared_notes TO service_role;

-- Remove both generations plus any canonical policies from a previous retry.
DROP POLICY IF EXISTS "Comments on public notes are viewable by everyone" ON public.note_comments;
DROP POLICY IF EXISTS "Users can create comments" ON public.note_comments;
DROP POLICY IF EXISTS "Users can update their own comments" ON public.note_comments;
DROP POLICY IF EXISTS "Users can delete their own comments" ON public.note_comments;
DROP POLICY IF EXISTS "Users can view own note comments" ON public.note_comments;
DROP POLICY IF EXISTS "Users can insert own note comments" ON public.note_comments;
DROP POLICY IF EXISTS "Users can update own note comments" ON public.note_comments;
DROP POLICY IF EXISTS "Users can delete own note comments" ON public.note_comments;
DROP POLICY IF EXISTS note_comments_select_authorized ON public.note_comments;
DROP POLICY IF EXISTS note_comments_insert_authorized ON public.note_comments;
DROP POLICY IF EXISTS note_comments_update_author ON public.note_comments;
DROP POLICY IF EXISTS note_comments_delete_author ON public.note_comments;

CREATE POLICY note_comments_select_authorized
  ON public.note_comments FOR SELECT TO anon, authenticated
  USING (note_comments_private.can_access_note_comments(note_id));

CREATE POLICY note_comments_insert_authorized
  ON public.note_comments FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT auth.uid())
    AND note_comments_private.can_access_note_comments(note_id)
  );

CREATE POLICY note_comments_update_author
  ON public.note_comments FOR UPDATE TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    AND note_comments_private.can_access_note_comments(note_id)
  )
  WITH CHECK (
    user_id = (SELECT auth.uid())
    AND note_comments_private.can_access_note_comments(note_id)
  );

CREATE POLICY note_comments_delete_author
  ON public.note_comments FOR DELETE TO authenticated
  USING (user_id = (SELECT auth.uid()));

ALTER TABLE public.note_comments
  DROP CONSTRAINT IF EXISTS note_comments_content_bounded_check;
ALTER TABLE public.note_comments
  ADD CONSTRAINT note_comments_content_bounded_check
  CHECK (char_length(btrim(content)) BETWEEN 1 AND 2000)
  NOT VALID;

REVOKE ALL ON public.note_comments FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.note_comments TO anon, authenticated;
GRANT INSERT (note_id, user_id, content) ON public.note_comments TO authenticated;
GRANT UPDATE (content) ON public.note_comments TO authenticated;
GRANT DELETE ON public.note_comments TO authenticated;
GRANT ALL ON public.note_comments TO service_role;

ALTER VIEW public.note_comment_counts SET (security_invoker = true);
REVOKE ALL ON public.note_comment_counts FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.note_comment_counts TO service_role;
