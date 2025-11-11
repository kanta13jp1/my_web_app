-- Add display_name to leaderboard
-- This migration creates a view that joins user_stats with user_profiles
-- to provide display names for the leaderboard

-- Create a view that combines user_stats with user profile information
CREATE OR REPLACE VIEW user_stats_with_profiles AS
SELECT
  us.user_id,
  us.total_points,
  us.current_level,
  us.notes_created,
  us.current_streak,
  us.longest_streak,
  us.notes_edited,
  us.notes_deleted,
  us.categories_created,
  us.tags_created,
  us.achievements_unlocked,
  us.last_activity_date,
  us.created_at,
  us.updated_at,
  COALESCE(up.display_name, au.email) as user_name,
  up.avatar_url
FROM user_stats us
LEFT JOIN user_profiles up ON us.user_id = up.user_id
LEFT JOIN auth.users au ON us.user_id = au.id;

-- Grant access to the view
GRANT SELECT ON user_stats_with_profiles TO authenticated, anon;

-- Update RLS: Ensure user_stats can be read by everyone for leaderboard
-- (This should already exist from previous migrations, but we ensure it here)
DO $$
BEGIN
  -- Drop old restrictive policies if they exist
  DROP POLICY IF EXISTS "Users can view their own stats" ON user_stats;
  DROP POLICY IF EXISTS "Users can view all stats for leaderboard" ON user_stats;

  -- Create new policy that allows everyone to view user_stats for leaderboard
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'user_stats'
    AND policyname = 'Anyone can view user stats for leaderboard'
  ) THEN
    CREATE POLICY "Anyone can view user stats for leaderboard"
      ON user_stats FOR SELECT
      USING (true);
  END IF;
END $$;

-- Comment for documentation
COMMENT ON VIEW user_stats_with_profiles IS
'View that combines user stats with profile information for leaderboard display.
Provides display_name as user_name, falling back to email if no display_name is set.';
