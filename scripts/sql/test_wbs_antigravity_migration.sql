-- PostgreSQL integration regression. Run ONLY against an empty disposable LOCAL DB:
-- psql -X -v ON_ERROR_STOP=1 -f scripts/sql/test_wbs_antigravity_migration.sql
-- No extensions, dependencies, migration ledger, or persistent rows are created.
\set ON_ERROR_STOP on
BEGIN;
DO $$
BEGIN
  IF inet_server_addr() IS NOT NULL
     AND inet_server_addr() NOT IN ('127.0.0.1'::inet, '::1'::inet) THEN
    RAISE EXCEPTION 'This test requires a disposable local PostgreSQL database';
  END IF;
  IF to_regclass('public.wbs_tasks') IS NOT NULL THEN
    RAISE EXCEPTION 'Refusing to test in a database with existing public.wbs_tasks';
  END IF;
END $$;

CREATE TABLE public.wbs_tasks (
  title text NOT NULL,
  category text,
  status text CHECK (status IN ('pending', 'in_progress', 'completed', 'blocked')),
  progress integer CHECK (progress BETWEEN 0 AND 100),
  priority text CHECK (priority IN ('low', 'medium', 'high', 'critical')),
  owner_instance text,
  phase text CHECK (phase IS NULL OR phase IN (
    'planning', 'design', 'impl', 'test', 'release', 'ops', 'maintenance')),
  description text,
  created_at timestamptz,
  updated_at timestamptz
);
\ir ../../supabase/migrations/20260610210400_wbs_drag_unassigned_owner.sql

CREATE TEMP TABLE expected_owners (owner text);
INSERT INTO expected_owners VALUES
  (NULL), (''), ('claude'), ('codex'), ('codex1'), ('codex2'), ('cx'),
  ('automation'), ('auto'), ('user'), ('usr'), ('human'), ('gemini'),
  ('co-pilot'), ('copilot'), ('vscode'), ('win'), ('windows'),
  ('ps'), ('ps1'), ('ps2'), ('ps3'), ('ps4'), ('ps5'), ('ps6'),
  ('web'), ('mobile'), ('schedule'), ('scheduled'), ('gha'),
  ('github-actions'), ('github-copilot'), ('all'), ('unassigned');
INSERT INTO public.wbs_tasks (title, owner_instance)
SELECT 'legacy:' || COALESCE(owner, '<NULL>'), owner FROM expected_owners;
DO $$
BEGIN
  BEGIN
    INSERT INTO public.wbs_tasks (title, owner_instance) VALUES ('pre-fix', 'antigravity');
    RAISE EXCEPTION 'Baseline unexpectedly permits antigravity';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END $$;

\ir ../../supabase/migrations/20261001194000_wbs_sdlc_7phase_comprehensive_coverage.sql
CREATE TEMP TABLE first_seed AS
SELECT * FROM public.wbs_tasks WHERE phase IS NOT NULL;
DO $$
BEGIN
  IF (SELECT count(*) FROM first_seed) <> 10
     OR (SELECT count(DISTINCT title) FROM first_seed) <> 10
     OR (SELECT count(DISTINCT phase) FROM first_seed) <> 7
     OR (SELECT count(*) FROM first_seed WHERE owner_instance = 'antigravity') <> 3 THEN
    RAISE EXCEPTION 'Expected all ten distinct seeds across seven phases (three Antigravity)';
  END IF;
END $$;

-- Re-run the entire migration, including DROP/ADD CHECK, against populated rows.
\ir ../../supabase/migrations/20261001194000_wbs_sdlc_7phase_comprehensive_coverage.sql
DO $$
DECLARE candidate text;
BEGIN
  IF EXISTS (
    (SELECT * FROM public.wbs_tasks WHERE phase IS NOT NULL EXCEPT SELECT * FROM first_seed)
    UNION ALL
    (SELECT * FROM first_seed EXCEPT SELECT * FROM public.wbs_tasks WHERE phase IS NOT NULL)
  ) OR (SELECT count(*) FROM public.wbs_tasks WHERE phase IS NOT NULL) <> 10 THEN
    RAISE EXCEPTION 'Re-running seeds changed rows or created duplicates';
  END IF;
  IF (SELECT count(*) FROM public.wbs_tasks WHERE phase IS NULL) <> 34 THEN
    RAISE EXCEPTION 'Legacy rows were changed';
  END IF;
  INSERT INTO public.wbs_tasks (title, owner_instance)
  SELECT 'post-fix:' || COALESCE(owner, '<NULL>'), owner FROM expected_owners;
  INSERT INTO public.wbs_tasks (title, owner_instance) VALUES ('new-owner', 'antigravity');
  FOREACH candidate IN ARRAY ARRAY['unknown-owner', 'Antigravity', ' antigravity', 'antigravity '] LOOP
    BEGIN
      INSERT INTO public.wbs_tasks (title, owner_instance) VALUES ('invalid', candidate);
      RAISE EXCEPTION 'Unexpected owner accepted: %', candidate;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
  END LOOP;
END $$;
ROLLBACK;
\echo 'PASS: legacy owners, NULL/empty, Antigravity, invalid owners, ten seeds, seven phases, repeat behavior'
