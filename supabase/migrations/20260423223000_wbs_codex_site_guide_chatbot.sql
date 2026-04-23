-- WBS Codex takeover: site guide AI chatbot.
-- 2026-04-23
--
-- Scoped to the actual Codex work in this session: add a site-wide guidance
-- chatbot so users can ask how to use the app and jump to the right feature.

ALTER TABLE wbs_tasks
  ADD COLUMN IF NOT EXISTS owner_instance text NOT NULL DEFAULT 'vscode',
  ADD COLUMN IF NOT EXISTS remaining_work text,
  ADD COLUMN IF NOT EXISTS recovery_plan text,
  ADD COLUMN IF NOT EXISTS estimated_hours numeric(6,2);

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
  'サイト案内AIチャット',
  'サイトが複雑で使い方が分かりにくい状態を改善するため、Home から直接開ける案内AIチャットを追加。サイト内機能の入口、使い方、最初の一手を ai-hub provider.chat とローカル候補ランキングで案内し、そのまま関連機能を開けるようにする。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-23',
  '2026-04-23',
  'beta',
  'high',
  'Done 2026-04-23: Codex added a Home entry point, a dedicated site-guide chat page, feature suggestion chips, ai-hub-backed answering, local fallback guidance, and regression tests.',
  'Next: feed manual/FAQ page content and route metadata into the same prompt context for deeper answers and richer citations.',
  1.5
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = 'サイト案内AIチャット'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'サイト案内AIチャット',
  'Codex added a site-guide AI chatbot that answers how to use the app, suggests the best matching feature, and opens the right destination directly from the Home screen.',
  '2026-04-23'
)
ON CONFLICT DO NOTHING;
