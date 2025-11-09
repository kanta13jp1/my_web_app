-- ============================================================
-- FIX: Authentication 500 Error
-- ============================================================
-- Problem: create_user_referral_code() trigger fails due to RLS policies
-- Solution: Add SECURITY DEFINER to bypass RLS during trigger execution
-- Date: 2025-11-09
-- ============================================================

-- Drop existing trigger
DROP TRIGGER IF EXISTS create_referral_code_on_signup ON auth.users;

-- Recreate function with SECURITY DEFINER
CREATE OR REPLACE FUNCTION create_user_referral_code()
RETURNS TRIGGER
SECURITY DEFINER  -- This allows the function to bypass RLS policies
SET search_path = public  -- Explicitly set search path for security
AS $$
DECLARE
    new_code TEXT;
    code_exists BOOLEAN;
BEGIN
    -- Generate unique referral code
    LOOP
        new_code := generate_referral_code();
        SELECT EXISTS(SELECT 1 FROM referral_codes WHERE referral_code = new_code) INTO code_exists;
        EXIT WHEN NOT code_exists;
    END LOOP;

    -- Insert referral code for new user
    INSERT INTO referral_codes (user_id, referral_code)
    VALUES (NEW.id, new_code);

    -- Initialize onboarding status
    INSERT INTO user_onboarding (user_id)
    VALUES (NEW.id);

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Log error but don't fail the user signup
        RAISE WARNING 'Failed to create referral code for user %: %', NEW.id, SQLERRM;
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
'Creates referral code and initializes onboarding for new users.
SECURITY DEFINER allows bypassing RLS policies during trigger execution.';
