-- Metric snapshots run every three hours. Copying a multi-megabyte data URL
-- into every snapshot caused report reads to exceed statement_timeout.
UPDATE public.hub_data
SET metadata = metadata - 'media_url'
WHERE source = 'x_post_metric_snapshot'
  AND metadata->>'media_url' LIKE 'data:%';
