-- PS#4 S58 REVERTED: originally added provider_id/section columns and dropped NOT NULL,
-- but all 130000-134500 seeds use the original (provider, category) schema.
-- This migration is a no-op to preserve the timestamp slot without schema changes.
SELECT 1;
