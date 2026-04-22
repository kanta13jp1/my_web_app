-- WBS Codex takeover: local election read-only AI sync UI.
-- 2026-04-22
--
-- Scoped to the actual Codex work in this session: remove manual KPI input
-- paths from the local election 700 dashboard and keep AI sync automatic.

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
  '統一地方選 AI自動更新専用UI',
  '統一地方選700必達管理室から県連KPIの手入力・編集導線を撤去し、local-election-intelligence による自動更新だけで運用する',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-22',
  '2026-04-22',
  'alpha',
  'high',
  'Done 2026-04-22: Codex removed manual prefecture KPI editing, template reset, monthly KPI edit dialog entry points, and in-page X post editor access. Cached AI snapshots now auto-sync on initial load.',
  'Completed in this slice. Next risk: monitor production data freshness and add source-level confidence badges if official pages change structure.',
  2
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '統一地方選 AI自動更新専用UI'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '統一地方選 AI自動更新専用UI',
  'Codex が統一地方選700必達管理室の手入力KPI編集導線を撤去。県連KPI編集、テンプレート再適用、月次表からの編集ダイアログ、投稿本文編集導線を外し、AI取得データを初期表示時にも自動同期する読み取り中心UIへ変更した。',
  '2026-04-22'
)
ON CONFLICT DO NOTHING;
