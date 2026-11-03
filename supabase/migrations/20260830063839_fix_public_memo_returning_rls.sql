-- Let INSERT/UPSERT ... RETURNING evaluate the public memo SELECT policy
-- without re-reading the row that is still being written by the statement.
--
-- The previous one-argument helper looked the memo up again by id. PostgreSQL
-- evaluates that STABLE helper against the statement snapshot, where a newly
-- inserted row is not yet visible, so PostgREST's return=representation path
-- failed with SQLSTATE 42501 even for the owning authenticated user.

CREATE OR REPLACE FUNCTION note_comments_private.can_read_public_memo(
  p_note_id bigint,
  p_user_id uuid,
  p_is_public boolean
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    p_user_id IS NOT NULL
    AND (
      p_is_public IS TRUE
      OR p_user_id = (SELECT auth.uid())
    )
    AND EXISTS (
      SELECT 1
      FROM public.notes AS n
      WHERE n.id = p_note_id
        AND n.user_id = p_user_id
    )
$$;

REVOKE ALL ON FUNCTION note_comments_private.can_read_public_memo(bigint, uuid, boolean)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION note_comments_private.can_read_public_memo(bigint, uuid, boolean)
  TO anon, authenticated, service_role;

DROP POLICY IF EXISTS public_memos_select_authorized ON public.public_memos;

CREATE POLICY public_memos_select_authorized
  ON public.public_memos FOR SELECT TO anon, authenticated
  USING (
    note_comments_private.can_read_public_memo(
      note_id,
      user_id,
      is_public
    )
  );

DROP FUNCTION IF EXISTS note_comments_private.can_read_public_memo(bigint);
