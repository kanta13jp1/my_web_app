-- Atomic server-side upvote RPC for public.feature_requests.
-- public.feature_requests enforces RLS with INSERT/SELECT policies only, so
-- direct client .update() calls fail with 0 updated rows. A narrow
-- SECURITY DEFINER RPC keeps arbitrary column updates blocked while allowing
-- atomic +1 vote increments on open requests.

CREATE OR REPLACE FUNCTION public.increment_feature_request_vote(
  p_request_id uuid
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_votes integer;
BEGIN
  UPDATE public.feature_requests
  SET votes = COALESCE(votes, 0) + 1
  WHERE id = p_request_id
    AND status = 'open'
  RETURNING votes INTO v_votes;

  RETURN v_votes;
END;
$$;

REVOKE ALL ON FUNCTION public.increment_feature_request_vote(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.increment_feature_request_vote(uuid)
  TO anon, authenticated, service_role;

COMMENT ON FUNCTION public.increment_feature_request_vote(uuid) IS
  'Atomically increments votes by 1 for an open feature_requests row and returns the updated count (or NULL when not open/not found).';
