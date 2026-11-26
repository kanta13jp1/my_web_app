-- Wave 2-B: Unlimited nested subpages hierarchy for public.notes
-- Adds nullable self-referencing parent_note_id with cycle & cross-tenant guards.

ALTER TABLE public.notes
  ADD COLUMN IF NOT EXISTS parent_note_id bigint
  REFERENCES public.notes(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.notes.parent_note_id IS
  'Optional parent note ID for Notion-style nested subpage trees and breadcrumbs.';

ALTER TABLE public.notes
  DROP CONSTRAINT IF EXISTS notes_parent_not_self;

ALTER TABLE public.notes
  ADD CONSTRAINT notes_parent_not_self
  CHECK (parent_note_id IS NULL OR parent_note_id <> id);

CREATE INDEX IF NOT EXISTS idx_notes_user_parent_updated
  ON public.notes (user_id, parent_note_id, updated_at DESC)
  WHERE parent_note_id IS NOT NULL;

-- SECURITY INVOKER (default) is intentional: under authenticated RLS,
-- foreign-tenant parent rows are filtered out cleanly (NOT FOUND -> uniform
-- 'Invalid parent_note_id' SQLSTATE 23514 without a cross-tenant existence oracle),
-- while v_parent_user_id IS DISTINCT FROM NEW.user_id enforces the same tenant
-- boundary even under service_role without privilege escalation.
CREATE OR REPLACE FUNCTION public.validate_note_parent_hierarchy()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_cursor bigint;
  v_next_parent_id bigint;
  v_parent_user_id uuid;
  v_depth integer := 0;
  v_max_depth constant integer := 32;
BEGIN
  IF NEW.parent_note_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.id IS NOT NULL AND NEW.parent_note_id = NEW.id THEN
    RAISE EXCEPTION 'Invalid parent_note_id'
      USING ERRCODE = '23514';
  END IF;

  v_cursor := NEW.parent_note_id;
  WHILE v_cursor IS NOT NULL LOOP
    v_depth := v_depth + 1;
    IF v_depth > v_max_depth THEN
      RAISE EXCEPTION 'Invalid parent_note_id'
        USING ERRCODE = '23514';
    END IF;

    IF NEW.id IS NOT NULL AND v_cursor = NEW.id THEN
      RAISE EXCEPTION 'Invalid parent_note_id'
        USING ERRCODE = '23514';
    END IF;

    SELECT n.parent_note_id, n.user_id
      INTO v_next_parent_id, v_parent_user_id
      FROM public.notes AS n
      WHERE n.id = v_cursor;

    IF NOT FOUND OR v_parent_user_id IS DISTINCT FROM NEW.user_id THEN
      RAISE EXCEPTION 'Invalid parent_note_id'
        USING ERRCODE = '23514';
    END IF;

    IF NEW.id IS NOT NULL AND v_next_parent_id = NEW.id THEN
      RAISE EXCEPTION 'Invalid parent_note_id'
        USING ERRCODE = '23514';
    END IF;

    v_cursor := v_next_parent_id;
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notes_validate_parent_hierarchy ON public.notes;

CREATE TRIGGER trg_notes_validate_parent_hierarchy
  BEFORE INSERT OR UPDATE OF parent_note_id, user_id ON public.notes
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_note_parent_hierarchy();
