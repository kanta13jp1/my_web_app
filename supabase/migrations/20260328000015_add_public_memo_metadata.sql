ALTER TABLE public_memos
ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public_memos.metadata IS
'Structured metadata for public memo share cards and OGP generation.';
