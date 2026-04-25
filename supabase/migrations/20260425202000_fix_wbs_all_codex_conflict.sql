-- Fix SQLSTATE 23505 in 20260425203000:
-- 203000 does INSERT copies for non-codex instances then UPDATE 'all'→'codex',
-- but 20260425170000_business_wbs_phase1.sql already seeded tasks with instance='codex'.
-- Those 'codex' rows conflict with the UPDATE. Pre-delete them so 203000 can succeed.
DELETE FROM public.wbs_tasks a
USING public.wbs_tasks b
WHERE a.instance = 'all'
  AND b.title = a.title
  AND b.category = a.category
  AND b.instance = 'codex';
