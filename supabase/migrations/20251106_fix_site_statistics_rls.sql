-- Fix Site Statistics RLS and Function Permissions
-- Created: 2025-11-06
-- Purpose: Fix 403 and 406 errors on site_statistics API calls

-- ============================================================
-- 1. DROP THE PROBLEMATIC "FOR ALL" POLICY
-- ============================================================
-- The "FOR ALL" policy was too restrictive and interfering with SELECT queries
DROP POLICY IF EXISTS "Only service role can modify site statistics" ON site_statistics;

-- ============================================================
-- 2. CREATE SPECIFIC POLICIES FOR INSERT, UPDATE, DELETE
-- ============================================================
-- These policies explicitly deny non-service-role modifications
-- while allowing the SELECT policy to work properly

-- Drop existing policies if they exist to avoid conflicts
DROP POLICY IF EXISTS "Only service role can insert site statistics" ON site_statistics;
DROP POLICY IF EXISTS "Only service role can update site statistics" ON site_statistics;
DROP POLICY IF EXISTS "Only service role can delete site statistics" ON site_statistics;

-- Create new policies
CREATE POLICY "Only service role can insert site statistics"
    ON site_statistics
    FOR INSERT
    WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Only service role can update site statistics"
    ON site_statistics
    FOR UPDATE
    USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Only service role can delete site statistics"
    ON site_statistics
    FOR DELETE
    USING (auth.jwt() ->> 'role' = 'service_role');

-- ============================================================
-- 3. UPDATE FUNCTIONS TO RUN WITH SECURITY DEFINER
-- ============================================================
-- This allows the functions to execute with elevated privileges
-- regardless of who calls them

-- Update site statistics function with SECURITY DEFINER
CREATE OR REPLACE FUNCTION update_site_statistics()
RETURNS void
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO site_statistics (
        stat_date,
        total_users,
        new_users_today,
        active_users_today,
        total_notes_created,
        total_shares,
        total_achievements_unlocked
    )
    SELECT
        CURRENT_DATE,
        (SELECT COUNT(*) FROM auth.users),
        (SELECT COUNT(*) FROM auth.users WHERE DATE(created_at) = CURRENT_DATE),
        (SELECT COUNT(DISTINCT user_id) FROM user_presence WHERE DATE(last_seen) = CURRENT_DATE),
        (SELECT COALESCE(SUM(notes_created), 0) FROM user_stats),
        (SELECT COALESCE(SUM(notes_shared), 0) FROM user_stats),
        (SELECT COUNT(*) FROM user_achievements WHERE is_unlocked = true)
    ON CONFLICT (stat_date)
    DO UPDATE SET
        total_users = EXCLUDED.total_users,
        new_users_today = EXCLUDED.new_users_today,
        active_users_today = EXCLUDED.active_users_today,
        total_notes_created = EXCLUDED.total_notes_created,
        total_shares = EXCLUDED.total_shares,
        total_achievements_unlocked = EXCLUDED.total_achievements_unlocked,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- Update cleanup function with SECURITY DEFINER
CREATE OR REPLACE FUNCTION cleanup_old_presence()
RETURNS void
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Mark users as offline if not seen in 5 minutes
    UPDATE user_presence
    SET is_online = false
    WHERE last_seen < NOW() - INTERVAL '5 minutes'
    AND is_online = true;

    -- Delete old offline records (older than 24 hours)
    DELETE FROM user_presence
    WHERE last_seen < NOW() - INTERVAL '24 hours'
    AND is_online = false;

    -- Delete old guest presence (older than 30 minutes)
    DELETE FROM guest_presence
    WHERE last_seen < NOW() - INTERVAL '30 minutes';
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 4. GRANT EXECUTE PERMISSIONS TO AUTHENTICATED USERS
-- ============================================================
-- Allow authenticated users to call these RPC functions

GRANT EXECUTE ON FUNCTION update_site_statistics() TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_old_presence() TO authenticated;

-- Also grant to anon role for guest access if needed
GRANT EXECUTE ON FUNCTION update_site_statistics() TO anon;
GRANT EXECUTE ON FUNCTION cleanup_old_presence() TO anon;

-- ============================================================
-- COMMENTS
-- ============================================================
COMMENT ON POLICY "Only service role can insert site statistics" ON site_statistics IS
    'Prevents regular users from inserting site statistics directly';
COMMENT ON POLICY "Only service role can update site statistics" ON site_statistics IS
    'Prevents regular users from updating site statistics directly';
COMMENT ON POLICY "Only service role can delete site statistics" ON site_statistics IS
    'Prevents regular users from deleting site statistics directly';
