-- WBS Codex takeover: all-feature next focus queue.
-- 2026-04-23
--
-- Scoped to the actual Codex work in this session: show the next life-capital
-- candidate after the current low-hurdle action unlocks.

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
  3,
  '全機能生命資本次候補キュー',
  '現在の低ハードル1手が定着した後に進む次の生命資本・代表機能をキュー表示し、AIレビューとKGI/CSF/KPIで移行順を案内する。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-23',
  '2026-04-23',
  'beta',
  'high',
  'Done 2026-04-23: Codex added a queued next-focus recommendation, rendered it in the strategy monitor, included it in AI review context, and added regression tests.',
  'Next: convert the queued candidate into a one-click launcher once home feature routing is fully stabilized.',
  1.0
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '全機能生命資本次候補キュー'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '全機能生命資本次候補キュー',
  'Codex added a queued next-focus recommendation so the all-feature AI strategy monitor can show which life-capital resource and feature should open after the current low-hurdle habit unlocks.',
  '2026-04-23'
)
ON CONFLICT DO NOTHING;
