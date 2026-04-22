-- WBS Codex takeover: asset waste-control AI training.
-- 2026-04-22
--
-- Scoped to the actual Codex work in this session: upgrade asset management
-- so waste control is treated as capability training, with automated
-- KGI/CSF/KPI scoring, ai-hub review, monitoring, and local fallback.

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
  'コアSaaS機能',
  '💼',
  4,
  '資産管理 浪費抑制AIトレーニング',
  '資産管理画面に、浪費しないことを能力開発トレーニングとして扱うKGI/CSF/KPIパネルを追加。支出・浪費カテゴリ・借金ロックダウン日課からKPIを自動算出し、ai-hub provider.chatで現状分析と次アクションを生成する。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-22',
  '2026-04-22',
  'beta',
  'high',
  'Done 2026-04-22: Codex added AssetWasteTrainingAiService, wired the asset management page to automated waste-control KGI/CSF/KPI scoring, added ai-hub provider.chat review with fallback, and covered the service with tests.',
  'Completed in this slice. Next: persist monthly training snapshots for trend charts and add notification nudges when waste ratio or daily rule completion worsens.',
  2
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '資産管理 浪費抑制AIトレーニング'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '資産管理 浪費抑制AIトレーニング',
  'Codex added automated KGI/CSF/KPI scoring to asset management so waste control is framed as capability training. The page now derives current-state metrics from expense flows, waste categories, and debt-lockdown habits, then asks ai-hub provider.chat for a concise review and next action with a local KPI fallback.',
  '2026-04-22'
)
ON CONFLICT DO NOTHING;
