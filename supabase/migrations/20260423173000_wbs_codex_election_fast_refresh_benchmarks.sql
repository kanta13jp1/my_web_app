-- Codex takeover: local-election fast refresh by making CDP benchmarks optional.
-- 2026-04-23
--
-- Scoped to the actual Codex work in this session: latest refresh still timed
-- out in production, so Codex removed optional CDP benchmark scraping from the
-- foreground dashboard refresh path and preserved already-saved benchmark KPIs.

ALTER TABLE wbs_tasks
  ADD COLUMN IF NOT EXISTS owner_instance text NOT NULL DEFAULT 'vscode',
  ADD COLUMN IF NOT EXISTS remaining_work text DEFAULT '',
  ADD COLUMN IF NOT EXISTS recovery_plan text DEFAULT '',
  ADD COLUMN IF NOT EXISTS estimated_hours numeric DEFAULT 0;

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
  'AI統合',
  '🤖',
  5,
  '統一地方選 最新取得CDPベンチマーク任意化',
  '統一地方選700必達管理室の最新取得で、立憲民主党47県ベンチマーク取得を同期必須処理から外す。通常更新は国民民主党公式現職数と予定選挙を優先し、CDP値が空のスナップショットでは保存済みKPIを0上書きしない。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-23',
  '2026-04-23',
  'alpha',
  'high',
  'Done 2026-04-23: Codex added includeCdpBenchmarks=false for dashboard refresh, kept CDP scraping available for full snapshots, and guarded plan sync so omitted optional benchmarks preserve existing values.',
  'Next: move CDP benchmark refresh to a scheduled/cache-backed path so full benchmark updates do not block user-triggered latest refresh.',
  0.5
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '統一地方選 最新取得CDPベンチマーク任意化'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '統一地方選 最新取得CDPベンチマーク任意化',
  'Codex made CDP local-authority benchmark scraping optional for local-election dashboard refreshes and preserved existing benchmark KPIs when fast snapshots omit optional CDP data.',
  '2026-04-23'
)
ON CONFLICT DO NOTHING;
