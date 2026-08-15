-- X 週次実測レポート cron の statement timeout 修正 (第 2 弾)。
--
-- listXMetricSnapshots は
--   SELECT ... FROM hub_data
--   WHERE source='x_post_metric_snapshot'
--     AND metadata->>'source_log_id' IN (最大50件)
--   ORDER BY created_at ASC
-- を実行する。cron は service_role で走るため user_id 絞込みが無い。
--
-- #4016 の index は (source_log_id, user_id, created_at) の順で、
-- user_id が固定される「ユーザー個別呼び出し」経路では created_at 順を
-- index から得られるが、user_id が未制約の cron 経路では 2 列目 (user_id) が
-- 開いているため 3 列目 created_at を order に使えず、source_log_id で絞った
-- 大量行を丸ごと sort する。これが本番 PostgREST の statement timeout の真因
-- (20260713213000 で x_post_log 側は index 化したが本経路は未修正だった)。
--
-- user_id を挟まない (source_log_id, created_at) の partial index を追加し、
-- IN リストの各 source_log_id を created_at 昇順で index 走査 → merge-append
-- (sort 不要) で返せるようにする。
CREATE INDEX IF NOT EXISTS idx_hub_data_x_metric_snapshot_log_created
  ON public.hub_data (
    (metadata->>'source_log_id'),
    created_at ASC
  )
  WHERE source = 'x_post_metric_snapshot';
