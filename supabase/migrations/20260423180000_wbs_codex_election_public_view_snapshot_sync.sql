-- Codex takeover: public local-election dashboard snapshot sync.
-- 2026-04-23
--
-- Scoped to the actual Codex work in this session: the public dashboard kept
-- showing stale prefecture KPI values (Kyoto stayed at 0) even though the live
-- snapshot already returned the correct current-member count.

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
  '統一地方選 公開ビューKPI同期修正',
  '公開ダッシュボードでも最新スナップショット受信時に県連KPIプランをメモリ同期する。private view は保存を継続しつつ、public view は保存なしで表示だけ更新し、京都府などの現職人数が古い0のまま残る不整合を解消する。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-23',
  '2026-04-23',
  'alpha',
  'high',
  'Done 2026-04-23: Codex confirmed Kyoto already returned 11 incumbents from the live snapshot, then fixed ElectionVictoryPage so public view merges snapshot reality into the in-memory KPI plan on initial load, plan reload, and refresh.',
  'Next: add a dedicated regression test for public-view snapshot-plan sync so stale localStorage plans cannot mask fresh reality data again.',
  0.5
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '統一地方選 公開ビューKPI同期修正'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '統一地方選 公開ビューKPI同期修正',
  'Codex fixed the public local-election dashboard so fresh snapshots update the in-memory prefecture KPI plan without requiring a private save, resolving stale Kyoto=0 displays while the live snapshot already had Kyoto=11.',
  '2026-04-23'
)
ON CONFLICT DO NOTHING;
