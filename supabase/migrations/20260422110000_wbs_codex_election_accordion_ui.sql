-- WBS Codex takeover: local election accordion UI.
-- 2026-04-22
--
-- Scoped to the actual Codex work in this session: reduce vertical page length
-- by grouping long local election lists into expandable sections.

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
  'デザインシステム',
  '🎨',
  2,
  '統一地方選 アコーディオンUI改善',
  '統一地方選700必達管理室の長い県連一覧・議員名簿・公式ソースを折り畳み可能にし、閉じた状態でも集計KPIを確認できるようにする',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-22',
  '2026-04-22',
  'alpha',
  'medium',
  'Done 2026-04-22: Codex grouped prefecture cards by region, member roster cards by prefecture, and official source cards into ExpansionTile accordions with compact KPI summary chips.',
  'Completed in this slice. Next risk: capture mobile screenshots after deploy and tune initially-expanded groups if usage data shows frequent deep scrolling.',
  2
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '統一地方選 アコーディオンUI改善'
);

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 68),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done 2026-04-22: Codex improved the 統一地方選700 dashboard with accordion groups for long prefecture/member/source lists and compact KPI summaries.'
  ),
  updated_at = now()
WHERE title = 'DESIGN.md全ページ準拠 60%達成'
  AND status <> 'completed';

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 73),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done 2026-04-22: Codex reduced mobile scroll length on the 統一地方選700 dashboard by collapsing long lists into expandable sections.'
  ),
  updated_at = now()
WHERE title = 'モバイルレスポンシブ完全対応'
  AND status <> 'completed';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '統一地方選 アコーディオンUI改善',
  'Codex が統一地方選700必達管理室の長いリストUIを改善。県連一覧を地域別、議員名簿を県別、公式ソースを折り畳み可能にし、閉じた状態でも現職・純増・新人・予定選挙・期限超過を確認できる集計チップを追加した。',
  '2026-04-22'
)
ON CONFLICT DO NOTHING;
