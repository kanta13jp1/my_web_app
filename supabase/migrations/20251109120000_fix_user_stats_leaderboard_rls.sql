-- Fix user_stats RLS policies to allow leaderboard access
-- Created: 2025-11-09
-- Purpose: Allow anyone to read user_stats for leaderboard functionality while maintaining write security

-- First, drop the existing restrictive SELECT policy
DROP POLICY IF EXISTS "Users can view their own stats" ON user_stats;

-- Create a new public read policy for leaderboard access
-- This allows anyone (authenticated or anonymous) to read all user stats
CREATE POLICY "Anyone can view user stats for leaderboard"
  ON user_stats FOR SELECT
  USING (true);

-- Note: INSERT and UPDATE policies remain restricted to the user's own data
-- This ensures users can only modify their own stats while everyone can view the leaderboard
