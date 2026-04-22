-- WBS Codex takeover: life waste-zero command center and AI abstraction.
-- 2026-04-22
--
-- Scoped to the actual Codex work in this session: consolidate duplicated
-- ai-hub provider.chat calls, then add the home command center that monitors
-- time, money, health, stamina, intelligence, and focus as one life-capital KGI.

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
  'ライフ浪費ゼロ司令塔 + AI抽象化',
  '類似していた ai-hub provider.chat 呼び出しを共通の AiHubChatService に抽象化し、ホームに時間・お金・健康・体力・知能・集中力の浪費を同じKGI/CSF/KPIで監視する司令塔を追加する。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-22',
  '2026-04-22',
  'beta',
  'high',
  'Done 2026-04-22: Codex added AiHubChatService, migrated feature and asset AI reviews to the shared gateway, added LifeWasteEliminationService, added the home life waste-zero command center, and covered the new services with tests.',
  'Completed in this slice. Next: persist daily life-capital snapshots and add alerts when any of the six waste dimensions stays below 80% for multiple days.',
  3
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = 'ライフ浪費ゼロ司令塔 + AI抽象化'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'ライフ浪費ゼロ司令塔 + AI抽象化',
  'Codex consolidated duplicated provider.chat integrations into AiHubChatService and added a home command center that treats time, money, health, stamina, intelligence, and focus as life-capital resources. The feature quantifies KGI/CSF/KPI, calls ai-hub for current-state review and next action, and falls back to a local KPI engine.',
  '2026-04-22'
)
ON CONFLICT DO NOTHING;
