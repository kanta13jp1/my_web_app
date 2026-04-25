-- PS#4 S58: ai_university_content schema v2 — provider_id + section + content_md + display_order
-- Required before 20260426130000+ seeds (otter_ai/murf/coqui/resemble) which use new columns.
-- Adds new columns with IF NOT EXISTS (idempotent) and UNIQUE constraint for ON CONFLICT upsert.

ALTER TABLE public.ai_university_content
  ADD COLUMN IF NOT EXISTS provider_id    text,
  ADD COLUMN IF NOT EXISTS section        text,
  ADD COLUMN IF NOT EXISTS content_md     text,
  ADD COLUMN IF NOT EXISTS display_order  int NOT NULL DEFAULT 0;

-- Unique constraint required by ON CONFLICT (provider_id, section) DO UPDATE in seeds
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'ai_university_content_provider_id_section_unique'
  ) THEN
    ALTER TABLE public.ai_university_content
      ADD CONSTRAINT ai_university_content_provider_id_section_unique
      UNIQUE (provider_id, section);
  END IF;
END $$;
