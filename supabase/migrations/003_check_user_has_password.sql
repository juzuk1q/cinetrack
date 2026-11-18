-- ============================================================================
-- Migration 003: Check if current authenticated user has an encrypted password set
-- ============================================================================

CREATE OR REPLACE FUNCTION public.check_user_has_password()
RETURNS BOOLEAN AS $$
DECLARE
    has_pwd BOOLEAN;
BEGIN
    SELECT (encrypted_password IS NOT NULL AND encrypted_password <> '')
    INTO has_pwd
    FROM auth.users
    WHERE id = auth.uid();

    RETURN COALESCE(has_pwd, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

REVOKE EXECUTE ON FUNCTION public.check_user_has_password() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_user_has_password() TO authenticated;
