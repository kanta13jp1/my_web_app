-- ============================================================
-- EMERGENCY: Disable ALL triggers on auth.users
-- ============================================================
-- This migration disables ALL triggers on auth.users to isolate the issue
-- Date: 2025-11-09 (Critical Emergency)
-- ============================================================

-- Disable the profile creation trigger
DROP TRIGGER IF EXISTS on_auth_user_created_profile ON auth.users;

-- Disable the function as well
DROP FUNCTION IF EXISTS create_default_user_profile();

-- Disable the referral code trigger (in case previous migration didn't work)
DROP TRIGGER IF EXISTS create_referral_code_on_signup ON auth.users;
DROP FUNCTION IF EXISTS create_user_referral_code();

-- ============================================================
-- VERIFICATION
-- ============================================================
-- After this migration, there should be NO triggers on auth.users
-- Signups should work without any database errors

COMMENT ON SCHEMA public IS
'All auth.users triggers temporarily disabled for emergency signup fix';
