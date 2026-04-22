-- WBS Codex takeover: local election CDP benchmark and UX polish.
-- 2026-04-22
--
-- Scoped to the actual Codex work in this session: ingest CDP official local
-- legislator counts by prefecture and surface them as a benchmark in the
-- local election 700 dashboard.

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
  '統一地方選 立憲比較/UX改善',
  'local-election-intelligence が立憲民主党公式「自治体議員」情報を県別に自動集計し、統一地方選700必達管理室のベンチマーク、県別カード、地図詳細へ反映する',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-22',
  '2026-04-22',
  'alpha',
  'high',
  'Done 2026-04-22: Codex added CDP local legislator counts from the official CDP local-authorities directory, stored them in snapshots/KPIs, and exposed comparison UX in the dashboard and Japan map.',
  'Completed in this slice. Next risk: monitor Edge Function latency after deploy because the CDP benchmark adds official prefecture-page fetches.',
  3
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '統一地方選 立憲比較/UX改善'
);

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 69),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done 2026-04-22: Codex added the CDP local-legislator benchmark and comparison UX to the local election dashboard.'
  ),
  updated_at = now()
WHERE title = 'DESIGN.md全ページ準拠 60%達成 (Codex引継ぎ)'
  AND status <> 'completed';

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 74),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done 2026-04-22: Codex kept the new CDP comparison compact with an expandable benchmark section and map detail rows.'
  ),
  updated_at = now()
WHERE title = 'モバイルレスポンシブ完全対応 (Codex引継ぎ)'
  AND status <> 'completed';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '統一地方選 立憲比較/UX改善',
  'Codex が統一地方選700必達管理室を改善。local-election-intelligence に立憲民主党公式「自治体議員」情報の県別自動集計を追加し、保存済み県連KPI、立憲ベンチマーク、県別カード、地図詳細、共有メタデータへ反映した。',
  '2026-04-22'
)
ON CONFLICT DO NOTHING;
