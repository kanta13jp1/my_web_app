-- WBS Codex takeover: all-feature focus feedback KPI loop.
-- 2026-04-23
--
-- Scoped to the actual Codex work in this session: feed completion/defer
-- outcomes from the low-hurdle life-capital action back into AI/KGI/CSF/KPI.

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
  '全機能生命資本フィードバックKPI',
  '今日の低ハードル1手の完了・観察履歴を7日間のKPIとして集計し、全機能AI戦略モニターとAIレビューに戻して、習慣化するまで次へ広げない改善判断に使う。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-23',
  '2026-04-23',
  'beta',
  'high',
  'Done 2026-04-23: Codex added seven-day focus-action stats, fed them into feature strategy signals, portfolio KGI/CSF/KPI metrics, Home report generation, and AI review prompts.',
  'Next: sync focus action outcomes to Supabase once user analytics tables are finalized.',
  1.5
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '全機能生命資本フィードバックKPI'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '全機能生命資本フィードバックKPI',
  'Codex connected the low-hurdle life-capital action loop back into all-feature AI strategy monitoring by aggregating seven-day completion/defer/streak stats and including them in KGI/CSF/KPI metrics plus AI review context.',
  '2026-04-23'
)
ON CONFLICT DO NOTHING;
