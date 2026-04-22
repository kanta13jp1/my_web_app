-- WBS Codex takeover: local election AI auto KPI sync.
-- 2026-04-22
--
-- This is a scoped Codex task for the work actually started in this session:
-- connecting local-election-intelligence reality data to saved prefecture KPIs.

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
  '統一地方選 AI自動KPI更新',
  'local-election-intelligence の取得結果から、各県連の現職人数・目標擁立数・予定選挙数・公認期限を自動反映する',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-22',
  '2026-04-22',
  'alpha',
  'high',
  'Done 2026-04-22: Codex added automatic prefecture KPI sync from local-election-intelligence snapshots and regression coverage for the merge logic.',
  'Completed in this slice. Next risk: validate production Edge Function data freshness and source coverage for all 47 prefectures.',
  4
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '統一地方選 AI自動KPI更新'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '統一地方選 AI自動KPI更新',
  'Codex が統一地方選700必達管理室のAI連携を強化。local-election-intelligence の実態データを保存済み県連KPIへ自動反映し、現職人数・目標擁立数・予定選挙数・公認期限・AI自動更新メモをユーザー入力なしで更新できるようにした。',
  '2026-04-22'
)
ON CONFLICT DO NOTHING;
