-- ============================================================
-- EMERGENCY: Completely disable trigger to allow signups
-- ============================================================
-- This migration completely removes the trigger to allow user signups
-- We'll add it back later once we fix the root cause
-- Date: 2025-11-09 (Critical Emergency)
-- ============================================================

-- Completely remove the trigger
DROP TRIGGER IF EXISTS create_referral_code_on_signup ON auth.users;

-- Drop the function as well
DROP FUNCTION IF EXISTS create_user_referral_code();

-- ============================================================
-- NOTE: This allows signups to work, but referral codes and
-- onboarding status won't be initialized automatically.
-- We'll add a background job or manual process to handle this later.
-- ============================================================

COMMENT ON TABLE referral_codes IS
'Referral codes table - trigger temporarily disabled to fix signup issues';

COMMENT ON TABLE user_onboarding IS
'Onboarding tracking - trigger temporarily disabled to fix signup issues';
