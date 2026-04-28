-- PS#5 S83: SQLSTATE 23514 根本原因解消 — pre-push backfill migration 配置
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#5 S83: SQLSTATE 23514 根本原因解消 — timestamp ordering fix',
  '20260425xxx migrations の broad UPDATE wbs_tasks が 20260426090000 より先に実行されて '
  'wbs_enforce_recovery_plan_trg SQLSTATE 23514 を発火する根本原因を特定・解消。'
  '20260424225000_pre_push_recovery_plan_backfill.sql を pending queue 先頭に配置し '
  'task 714ee4a4 (deadline=2026-04-27) を含む全超過タスクへ recovery_plan を事前 SET。'
  '合わせて S82 の bypass+v2 migration pattern (20260426100000 → 20260428146000) も維持。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
