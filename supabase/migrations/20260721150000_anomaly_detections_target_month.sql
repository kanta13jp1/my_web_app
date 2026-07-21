-- Issue #2477: detect_anomalies の冪等な月次スキャンには対象月の安定キーが必要。
-- anomaly_detections は 20260721120000 で追加されたばかりで書き込みコードは
-- 本変更 (ai-hub detect_anomalies) が初 = 空テーブルへの追加列。
-- (時間依存 UPDATE は migration replay guard 対象のため backfill は置かない。
--  万一行が存在すれば SET NOT NULL が明示的に失敗する = 無言破損しない。)

alter table public.anomaly_detections
  add column if not exists target_month date;

alter table public.anomaly_detections
  alter column target_month set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'anomaly_detections_target_month_first_day'
  ) then
    alter table public.anomaly_detections
      add constraint anomaly_detections_target_month_first_day
      check (extract(day from target_month) = 1);
  end if;
end $$;

-- upsert onConflict (user_id, category, target_month) 用の一意キー。
create unique index if not exists anomaly_detections_user_category_month_key
  on public.anomaly_detections (user_id, category, target_month);

comment on column public.anomaly_detections.target_month is
  '検知対象月の月初日付 (YYYY-MM-01)。(user_id, category, target_month) で一意 = 再スキャンは更新のみ。';
