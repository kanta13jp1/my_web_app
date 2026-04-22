-- WBS Codex takeover: system-wide KGI/CSF/KPI display foundation.
-- 2026-04-22
--
-- Scoped to the actual Codex work in this session: add a shared KGI/CSF/KPI
-- display model and panel, apply it to major KPI display surfaces, and keep
-- the original Kokumin local legislator aggregation output protected.

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
  '全体KGI/CSF/KPI表示基盤',
  'KPI表示を共通のKGI/CSF/KPIパネルに寄せ、KGI、KGI達成のCSF、CSFに基づく数値KPIを主要画面へ併記する。国民民主党地方議員集計機能は既存出力を残す。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-22',
  '2026-04-22',
  'alpha',
  'high',
  'Done 2026-04-22: Codex added a shared KGI/CSF/KPI model and UI panel, then applied it to home, personal dashboard, budget, CMO, viral metrics, and local election charts.',
  'Completed in this slice. Next risk: long-tail KPI cards in legacy/admin pages should be migrated opportunistically when those pages are touched.',
  3
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '全体KGI/CSF/KPI表示基盤'
);

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 73),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done 2026-04-22: Codex introduced a reusable KGI/CSF/KPI panel and applied it across major KPI display surfaces.'
  ),
  updated_at = now()
WHERE title = 'DESIGN.md全ページ準拠 60%達成 (Codex引継ぎ)'
  AND status <> 'completed';

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 78),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done 2026-04-22: Codex used a collapsible KGI/CSF/KPI panel so added strategy context stays mobile-friendly.'
  ),
  updated_at = now()
WHERE title = 'モバイルレスポンシブ完全対応 (Codex引継ぎ)'
  AND status <> 'completed';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '全体KGI/CSF/KPI表示基盤',
  'Codex がKPI表示の共通基盤を追加。KGI、KGI達成のためのCSF、CSFに基づく数値KPIを共通パネルで表示できるようにし、ホーム、個人ダッシュボード、財務、CMO、バイラル指標、統一地方選チャートへ適用した。国民民主党地方議員集計の既存出力は残し、回帰テストで保護した。',
  '2026-04-22'
)
ON CONFLICT DO NOTHING;
