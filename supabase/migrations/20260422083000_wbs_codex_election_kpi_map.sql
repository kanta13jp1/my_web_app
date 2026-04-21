-- WBS Codex takeover: local election KPI map frontend progress.
-- 2026-04-22
--
-- Only tasks actually touched in this session are kept on the Codex owner:
-- DESIGN.md compliance and mobile responsiveness for the local election page.

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 66),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done 2026-04-22: Codex added a responsive 全国KPIマップ to the 2027統一地方選700必達管理室 and fixed chart widget regression coverage.'
  ),
  recovery_plan = CASE
    WHEN COALESCE(recovery_plan, '') = '' THEN
      'Next: continue DESIGN.md horizontal rollout on the remaining high-traffic dashboards and capture desktop/mobile visual evidence.'
    ELSE recovery_plan
  END,
  updated_at = now()
WHERE title = 'DESIGN.md全ページ準拠 60%達成'
  AND status <> 'completed';

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 71),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done 2026-04-22: Codex made the local election KPI map switch between stacked mobile and split desktop layouts without widening the page.'
  ),
  recovery_plan = CASE
    WHEN COALESCE(recovery_plan, '') = '' THEN
      'Next: run Playwright mobile checks for the remaining priority pages and fix any overflow found.'
    ELSE recovery_plan
  END,
  updated_at = now()
WHERE title = 'モバイルレスポンシブ完全対応'
  AND status <> 'completed';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '統一地方選KPIマップ Codex引き継ぎ実装',
  'Claude quota 制限中の実作業として、Codex が DESIGN.md準拠/モバイル対応タスクを引き継ぎ、統一地方選700必達管理室へ全国KPIマップを追加。WBS owner を Codex に維持し、進捗を DESIGN 66% / モバイル 71% に更新した。',
  '2026-04-22'
)
ON CONFLICT DO NOTHING;
