-- 20260426125000 was applied to prod DB before the DROP NOT NULL was added to it.
-- This standalone migration applies the missing constraint relaxation.
-- Runs between 125000 (already applied) and 130000 (otter_ai seed).
-- PostgreSQL: DROP NOT NULL on an already-nullable column is a safe no-op.
ALTER TABLE public.ai_university_content
  ALTER COLUMN provider   DROP NOT NULL,
  ALTER COLUMN category   DROP NOT NULL,
  ALTER COLUMN title      DROP NOT NULL,
  ALTER COLUMN content    DROP NOT NULL;
