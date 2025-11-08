-- Add metadata column to user_stats table
-- Created: 2025-11-08
-- Purpose: Store user preferences and onboarding status

-- Add metadata column (JSONB type for flexible data storage)
ALTER TABLE user_stats
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::JSONB;

-- Create an index on metadata for faster queries
CREATE INDEX IF NOT EXISTS idx_user_stats_metadata ON user_stats USING GIN (metadata);

-- Add a comment to explain the column
COMMENT ON COLUMN user_stats.metadata IS 'Stores user preferences and onboarding status. Example: {"onboarding_completed": true}';

-- Update existing rows to have empty metadata object
UPDATE user_stats
SET metadata = '{}'::JSONB
WHERE metadata IS NULL;
