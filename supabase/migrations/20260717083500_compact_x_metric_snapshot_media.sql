-- Metric snapshots run every three hours. Copying a multi-megabyte data URL
-- into every snapshot caused report reads to exceed statement_timeout.
-- nocheck: time-relative -- this cleanup updates JSON media metadata only;
-- no date or status column is changed.
-- Rewriting the existing payloads can exceed the normal request timeout, so
-- widen it only for this bounded cleanup and restore the session default.
SET statement_timeout = '15min';

UPDATE public.hub_data
SET metadata = metadata - 'media_url'
WHERE source = 'x_post_metric_snapshot'
  AND metadata->>'media_url' LIKE 'data:%';

RESET statement_timeout;
