-- WBS Codex takeover: local election prefecture KPI X sharing.
-- 2026-04-22
--
-- Scoped to the actual Codex work in this session: add per-prefecture KPI
-- share/copy actions and prefecture-aware public dashboard links.

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
  '統一地方選 県連KPI X共有',
  '統一地方選700必達管理室の各県連カードから、現職人数・目標擁立数・予定選挙数・公認期限・立憲参考値を含むKPIをXで共有できるようにする',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-22',
  '2026-04-22',
  'alpha',
  'high',
  'Done 2026-04-22: Codex added per-prefecture KPI copy/share actions, X intent generation, and prefecture-aware public dashboard URLs.',
  'Completed in this slice. Next risk: decide whether X投稿を完全自動化する場合は daily-report 側の権限設計と投稿頻度制御を別タスク化する。',
  2
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '統一地方選 県連KPI X共有'
);

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 70),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done 2026-04-22: Codex added compact icon actions for prefecture-level KPI sharing in the local election dashboard.'
  ),
  updated_at = now()
WHERE title = 'DESIGN.md全ページ準拠 60%達成 (Codex引継ぎ)'
  AND status <> 'completed';

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 75),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done 2026-04-22: Codex kept prefecture KPI sharing mobile-friendly with icon buttons and region-filtered public links.'
  ),
  updated_at = now()
WHERE title = 'モバイルレスポンシブ完全対応 (Codex引継ぎ)'
  AND status <> 'completed';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '統一地方選 県連KPI X共有',
  'Codex が統一地方選700必達管理室を改善。各県連カードにKPI投稿文コピーとX共有を追加し、現職人数・純増目標・新人目標・予定選挙数・公認期限・立憲参考値を含む投稿文と、県名付き公開URLから該当地域へ絞り込める導線を実装した。',
  '2026-04-22'
)
ON CONFLICT DO NOTHING;
