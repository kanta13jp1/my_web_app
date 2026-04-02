-- Fix user_profiles: add missing id column, missing columns, and fix RLS infinite recursion
--
-- Problems:
-- 1. Original table (20251107) uses user_id as PK with no id column.
--    Flutter frontend queries select=id → 400 Bad Request.
-- 2. Migration 20260330000003 added admin_read_all_profiles RLS policy that
--    queries user_profiles within its own policy → infinite recursion → 500.
-- 3. Migration 20260330000152 tried CREATE TABLE IF NOT EXISTS with new columns
--    but was a no-op since table already existed.

-- Step 1: Add missing id column
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();

-- Step 2: Add columns that 20260330000152 expected but never got created
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS company text;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS website text;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS skills text[] DEFAULT '{}';
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS interests text[] DEFAULT '{}';
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS last_nudge_at timestamptz;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS notification_preferences jsonb DEFAULT '{}';
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS role text DEFAULT 'user';
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS deactivation_requested_at timestamptz;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS deactivation_reason text;

-- Step 3: Fix the self-referencing RLS policy that causes 500 errors
-- The admin_read_all_profiles policy queries user_profiles within itself,
-- causing infinite recursion. Replace with a SECURITY DEFINER function.

-- Create a helper function that bypasses RLS to check admin status
CREATE OR REPLACE FUNCTION is_user_admin(check_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM user_profiles WHERE user_id = check_user_id),
    false
  );
$$;

-- Drop the problematic self-referencing policy
DROP POLICY IF EXISTS "admin_read_all_profiles" ON user_profiles;

-- Recreate using the SECURITY DEFINER function (no self-reference)
CREATE POLICY "admin_read_all_profiles" ON user_profiles
  FOR SELECT
  USING (is_user_admin(auth.uid()));

-- Also fix service_role policy if it exists
DROP POLICY IF EXISTS "service_role_full_access_user_profiles" ON user_profiles;
CREATE POLICY "service_role_full_access_user_profiles" ON user_profiles
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- Ensure authenticated users can always read their own profile
DROP POLICY IF EXISTS "Users can read own profile always" ON user_profiles;
CREATE POLICY "Users can read own profile always" ON user_profiles
  FOR SELECT
  USING (auth.uid() = user_id);

-- Index on id column
CREATE INDEX IF NOT EXISTS idx_user_profiles_id ON user_profiles(id);
