-- WBS Codex takeover: all-feature habit unlock gate.
-- 2026-04-23
--
-- Scoped to the actual Codex work in this session: keep the selected
-- low-hurdle life-capital action fixed until the habit unlock condition is met.

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
  '全機能生命資本習慣化解放ゲート',
  '今日の低ハードル1手を完了3日分または3日継続まで固定し、解放条件を満たすまで新しい継続タスクを増やさないよう、全機能AI戦略モニターとAIレビューへ判定を追加する。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-23',
  '2026-04-23',
  'beta',
  'high',
  'Done 2026-04-23: Codex added habit unlock stats, focus selection lock for active unstable actions, unlock KPI metrics, UI status, AI review context, and regression tests.',
  'Next: persist unlock decisions to Supabase analytics after the user-level focus action table is finalized.',
  1.5
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '全機能生命資本習慣化解放ゲート'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '全機能生命資本習慣化解放ゲート',
  'Codex prevented continuous-task sprawl by locking the all-feature low-hurdle life-capital action until three completion evidence days are reached, then exposing the unlock state in KGI/CSF/KPI and AI review context.',
  '2026-04-23'
)
ON CONFLICT DO NOTHING;
