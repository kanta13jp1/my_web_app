-- Prevent authenticated users from promoting their own profile to admin.
-- X posting and account-wide metric reads trust this flag, so it must only be
-- writable from a service-role/backend path.

CREATE OR REPLACE FUNCTION public.guard_user_profile_admin_flag()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF auth.role() = 'service_role'
     OR current_user IN ('postgres', 'supabase_admin', 'supabase_auth_admin') THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF COALESCE(NEW.is_admin, false) THEN
      RAISE EXCEPTION 'is_admin can only be assigned by service_role'
        USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.is_admin IS DISTINCT FROM OLD.is_admin THEN
    RAISE EXCEPTION 'is_admin can only be changed by service_role'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_user_profile_admin_flag
  ON public.user_profiles;
CREATE TRIGGER guard_user_profile_admin_flag
  BEFORE INSERT OR UPDATE ON public.user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_user_profile_admin_flag();

-- The existing helper is SECURITY DEFINER. Pin its search_path and qualify the
-- table so a caller-controlled schema cannot shadow user_profiles.
CREATE OR REPLACE FUNCTION public.is_user_admin(check_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT COALESCE(
    (SELECT up.is_admin
       FROM public.user_profiles AS up
      WHERE up.user_id = check_user_id),
    false
  );
$$;

COMMENT ON FUNCTION public.guard_user_profile_admin_flag() IS
  'Rejects authenticated self-promotion of user_profiles.is_admin; service role only.';
