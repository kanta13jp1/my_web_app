-- Restore generated public memos after the ownership hardening in
-- 20260827032000_harden_note_comments_authorization.sql.
--
-- The election dashboard historically used a synthetic public_memos.note_id
-- without creating the authoritative notes row. The hardened RLS correctly
-- rejects and hides those rows. Give every generated memo an owner-backed note
-- and remap public_memos.note_id to the database-assigned integer ID. The
-- synthetic ID remains in source_key so deployed clients can resolve the same
-- generated note after the rollout.
-- nocheck: time-relative -- only source_key is updated; no date-constrained
-- column or time-relative enforcement state is changed.

ALTER TABLE public.notes
  ADD COLUMN IF NOT EXISTS source_key text;

COMMENT ON COLUMN public.notes.source_key IS
  'Stable owner-scoped key for notes generated outside the note editor.';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'notes_user_source_key_unique'
      AND conrelid = 'public.notes'::regclass
  ) THEN
    ALTER TABLE public.notes
      ADD CONSTRAINT notes_user_source_key_unique UNIQUE (user_id, source_key);
  END IF;
END
$$;

INSERT INTO public.notes (
  user_id,
  content,
  source_key
)
SELECT
  pm.user_id,
  COALESCE(pm.content, ''),
  CASE
    WHEN pm.note_id >= 90000000000000
      THEN 'local-election:' || pm.note_id::text
    ELSE 'legacy-public-memo:' || pm.id::text
  END
FROM public.public_memos AS pm
LEFT JOIN public.notes AS n ON n.id = pm.note_id
WHERE n.id IS NULL
  AND pm.user_id IS NOT NULL
ON CONFLICT (user_id, source_key) DO UPDATE
SET content = EXCLUDED.content;

UPDATE public.public_memos AS pm
SET note_id = n.id
FROM public.notes AS n
WHERE n.user_id = pm.user_id
  AND n.source_key = CASE
    WHEN pm.note_id >= 90000000000000
      THEN 'local-election:' || pm.note_id::text
    ELSE 'legacy-public-memo:' || pm.id::text
  END
  AND NOT EXISTS (
    SELECT 1
    FROM public.notes AS current_note
    WHERE current_note.id = pm.note_id
  );

-- All legacy public memo rows are now backed by notes. Validation turns the
-- earlier NOT VALID foreign key into a durable invariant for future writes.
ALTER TABLE public.public_memos
  VALIDATE CONSTRAINT public_memos_note_id_fkey;
