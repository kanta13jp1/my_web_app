-- ============================================================
-- EMERGENCY FIX: Temporarily disable trigger to allow signups
-- ============================================================
-- This migration disables the problematic trigger temporarily
-- to allow user signups while we investigate the root cause
-- Date: 2025-11-09 (Emergency)
-- ============================================================

-- Temporarily disable the trigger
DROP TRIGGER IF EXISTS create_referral_code_on_signup ON auth.users;

-- Create a simpler version that logs errors but always succeeds
CREATE OR REPLACE FUNCTION create_user_referral_code()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Try to create referral code and onboarding, but don't fail if it doesn't work
    BEGIN
        -- Generate a simple referral code without the helper function
        INSERT INTO referral_codes (user_id, referral_code)
        VALUES (
            NEW.id,
            substring(md5(random()::text || NEW.id::text) from 1 for 8)
        )
        ON CONFLICT (user_id) DO NOTHING;

        -- Initialize onboarding status
        INSERT INTO user_onboarding (user_id)
        VALUES (NEW.id)
        ON CONFLICT (user_id) DO NOTHING;

    EXCEPTION WHEN OTHERS THEN
        -- Log the error but don't fail signup
        RAISE WARNING 'Failed to initialize user data for %: %', NEW.id, SQLERRM;
    END;

    -- Always return NEW to allow signup to succeed
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate trigger
CREATE TRIGGER create_referral_code_on_signup
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION create_user_referral_code();

-- ============================================================
-- COMMENTS
-- ============================================================
COMMENT ON FUNCTION create_user_referral_code() IS
'Emergency fix: Simplified version that generates referral code inline
and uses ON CONFLICT to handle edge cases. Always returns NEW to prevent
signup failures.';
