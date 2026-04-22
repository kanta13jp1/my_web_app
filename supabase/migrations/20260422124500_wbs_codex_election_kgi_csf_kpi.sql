-- WBS Codex takeover: local election KGI/CSF/KPI planning.
-- 2026-04-22
--
-- Scoped to the actual Codex work in this session: define prefecture-level
-- KGI targets, CSF drivers, and numeric KPI progress derived from the
-- automated local election intelligence data.

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
  '統一地方選 KGI/CSF/KPI設計',
  '各県連のKGIを統一地方選後の地方議員到達数として設定し、KGI達成のためのCSFごとに数値KPI・進捗・残数を自動算出して画面と一括共有ノートに反映する',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-22',
  '2026-04-22',
  'alpha',
  'high',
  'Done 2026-04-22: Codex added prefecture-level KGI, CSF, and KPI calculations driven by AI-updated election data.',
  'Completed in this slice. Next risk: if official candidate statuses need stricter validation, add source confidence and manual audit flags as a separate task.',
  2
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '統一地方選 KGI/CSF/KPI設計'
);

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 72),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done 2026-04-22: Codex added a collapsible KGI/CSF/KPI panel to each local election prefecture card.'
  ),
  updated_at = now()
WHERE title = 'DESIGN.md全ページ準拠 60%達成 (Codex引継ぎ)'
  AND status <> 'completed';

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 77),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done 2026-04-22: Codex kept the new CSF/KPI detail collapsed by default so the prefecture list remains scan-friendly on mobile.'
  ),
  updated_at = now()
WHERE title = 'モバイルレスポンシブ完全対応 (Codex引継ぎ)'
  AND status <> 'completed';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '統一地方選 KGI/CSF/KPI設計',
  'Codex が統一地方選700必達管理室を改善。各県連のKGIを統一地方選後の地方議員到達数として設定し、現職基盤、候補者パイプライン、重点自治体、公認前倒し、接戦区支援をCSFとして数値KPI化し、UIと一括共有ノートへ反映した。',
  '2026-04-22'
)
ON CONFLICT DO NOTHING;
