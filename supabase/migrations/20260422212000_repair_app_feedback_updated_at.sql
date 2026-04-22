-- Repair app_feedback schema drift.
-- 2026-04-22
--
-- The original create-table migration used CREATE TABLE IF NOT EXISTS, so
-- environments where app_feedback already existed can miss updated_at while
-- still retaining the update_app_feedback_updated_at trigger.

ALTER TABLE app_feedback
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
