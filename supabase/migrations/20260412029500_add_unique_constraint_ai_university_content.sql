-- PS版#52: Fix ON CONFLICT (provider, category) — deploy-prod failure
-- Migrations 20260412030000+ use ON CONFLICT (provider, category) DO UPDATE
-- but no UNIQUE constraint existed, causing SQLSTATE 42P10

-- Remove duplicate (provider, category) rows — keep most recently updated
DELETE FROM ai_university_content a
USING ai_university_content b
WHERE a.id < b.id
  AND a.provider = b.provider
  AND a.category = b.category;

-- Add the UNIQUE constraint required for ON CONFLICT upsert
ALTER TABLE ai_university_content
  ADD CONSTRAINT ai_university_content_provider_category_unique
  UNIQUE (provider, category);
