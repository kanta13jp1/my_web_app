-- WBS Codex takeover: life-capital Supabase cloud sync.
-- 2026-04-22
--
-- Scoped to the actual Codex work in this session: move life-capital daily
-- snapshots from local-only monitoring to authenticated Supabase sync while
-- preserving local fallback behavior.

INSERT INTO wbs_tasks (
  category,
  category_icon,
  category_order,
  title,
  description,
  instance,
  owner_instance,
  status,
  progress,
  start_date,
  end_date,
  milestone_code,
  priority,
  remaining_work,
  recovery_plan,
  estimated_hours
)
SELECT
  'コアSaaS機能',
  '💼',
  4,
  'ライフ資本スナップショット Supabase同期',
  '時間・お金・健康・体力・知能・集中力のライフ資本スコアを、ログイン済みユーザーごとにSupabaseへ日次同期し、端末内履歴とクラウド履歴をマージして定期モニタリングを継続する。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-22',
  '2026-04-22',
  'beta',
  'high',
  'Done 2026-04-22: Codex added the life_capital_daily_snapshots table, RLS policies, Supabase repository abstraction, cloud/local merge behavior, sync status UI, and repository-level tests.',
  'Next: route repeated life-capital alerts to notifications after notification rules are finalized.',
  2
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = 'ライフ資本スナップショット Supabase同期'
);

UPDATE wbs_tasks
SET
  remaining_work = 'Done 2026-04-22: Codex followed up local life-capital snapshots with authenticated Supabase sync and local fallback.',
  recovery_plan = 'Completed by task: ライフ資本スナップショット Supabase同期.'
WHERE title = 'ライフ資本日次スナップショット + 継続低下アラート';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'ライフ資本スナップショット Supabase同期',
  'Codex added authenticated Supabase persistence for life-capital daily snapshots. The monitoring service now upserts daily snapshots by user/date, merges cloud and local histories, keeps local fallback for offline or logged-out use, and shows cloud sync state on the home command center.',
  '2026-04-22'
)
ON CONFLICT DO NOTHING;
