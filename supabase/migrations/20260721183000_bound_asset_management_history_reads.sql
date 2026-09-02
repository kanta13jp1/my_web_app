-- Keep asset-management startup reads bounded without dropping the last known
-- balance for accounts that have no activity inside the chart window.
CREATE OR REPLACE FUNCTION public.asset_management_recent_cfo_assets(
  p_lookback_days integer DEFAULT 400
)
RETURNS TABLE (
  id bigint,
  title text,
  amount numeric,
  created_at timestamp with time zone
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $function$
  WITH cutoff AS (
    SELECT now() - make_interval(
      days => LEAST(GREATEST(COALESCE(p_lookback_days, 400), 1), 3650)
    ) AS value
  ),
  recent_rows AS (
    SELECT asset.id, asset.title, asset.amount, asset.created_at
    FROM public.cfo_assets AS asset
    CROSS JOIN cutoff
    WHERE asset.user_id = auth.uid()
      AND asset.created_at >= cutoff.value
  ),
  account_anchors AS (
    SELECT DISTINCT ON (asset.title)
      asset.id,
      asset.title,
      asset.amount,
      asset.created_at
    FROM public.cfo_assets AS asset
    CROSS JOIN cutoff
    WHERE asset.user_id = auth.uid()
      AND asset.created_at < cutoff.value
    ORDER BY
      asset.title,
      asset.created_at DESC NULLS LAST,
      asset.id DESC
  )
  SELECT
    result_rows.id,
    result_rows.title,
    result_rows.amount,
    result_rows.created_at
  FROM (
    SELECT * FROM recent_rows
    UNION ALL
    SELECT * FROM account_anchors
  ) AS result_rows
  ORDER BY
    result_rows.created_at ASC,
    result_rows.title ASC,
    result_rows.id ASC;
$function$;

REVOKE ALL ON FUNCTION public.asset_management_recent_cfo_assets(integer)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.asset_management_recent_cfo_assets(integer)
TO authenticated;

COMMENT ON FUNCTION public.asset_management_recent_cfo_assets(integer) IS
  'Returns projected cfo_assets rows for a bounded chart window plus one pre-window anchor per account.';
