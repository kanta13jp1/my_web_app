-- ============================================================================
-- Fix for 406 Error on user_stats Endpoint
-- ============================================================================
-- Issue: Leaderboard cannot access user_stats due to restrictive RLS policy
-- Solution: Allow public read access while maintaining write security
-- Date: 2025-11-09
-- ============================================================================

-- Step 1: Drop the old restrictive policy
DROP POLICY IF EXISTS "Users can view their own stats" ON user_stats;

-- Step 2: Create new public read policy
CREATE POLICY "Anyone can view user stats for leaderboard"
  ON user_stats FOR SELECT
  USING (true);

-- Step 3: Verify the changes
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'user_stats'
ORDER BY cmd, policyname;

-- Expected output:
-- - SELECT policy: "Anyone can view user stats for leaderboard" with qual = 'true'
-- - INSERT policy: "Users can insert their own stats"
-- - UPDATE policy: "Users can update their own stats"

-- ============================================================================
-- INSTRUCTIONS:
-- ============================================================================
-- 1. Go to https://app.supabase.com
-- 2. Select your project (smmkxxavexumewbfaqpy)
-- 3. Click "SQL Editor" in the sidebar
-- 4. Click "New query"
-- 5. Copy and paste this entire file
-- 6. Click "Run" (or press Cmd/Ctrl + Enter)
-- 7. Check the output to verify all policies are correct
-- 8. Test your app - the 406 error should be resolved!
-- ============================================================================
