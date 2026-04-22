-- WBS Codex takeover: life-capital habit gate.
-- 2026-04-22
--
-- Scoped to the actual Codex work in this session: prevent continuation
-- overload by selecting one low-hurdle life-capital habit, keeping all other
-- improvements in observation mode until the focus habit stabilizes.

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
  '🧩',
  4,
  'ライフ資本習慣化ゲート',
  '継続系タスクを同時多発させず、時間・お金・健康・体力・知能・集中力のうち低ハードルの1件だけを7日継続するまで固定する。他の改善は観察のみとし、通知もフォーカス資本を優先する。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-22',
  '2026-04-22',
  'beta',
  'high',
  'Done 2026-04-22: Codex added a persistent habit gate to LifeWasteEliminationService, low-hurdle micro-habit selection, 7-day stabilization tracking, parked-resource UI, and focused alert routing tests.',
  'Next: add explicit user confirmation only if automatic score-based habit completion is too implicit in real use.',
  2
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = 'ライフ資本習慣化ゲート'
);

UPDATE wbs_tasks
SET
  remaining_work = 'Done 2026-04-22: Codex followed up alert routing by adding the life-capital habit gate and focus-only continuation flow.',
  recovery_plan = 'Completed by task: ライフ資本習慣化ゲート.'
WHERE title = 'ライフ資本アラート通知導線';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'ライフ資本習慣化ゲート',
  'Codex added a one-habit-at-a-time gate for continuation tasks. The home life waste-zero command center now locks onto the lowest-hurdle micro habit, tracks a 7-day stabilization streak, parks other resources as observation-only, and routes repeated alerts primarily for the active focus resource.',
  '2026-04-22'
)
ON CONFLICT DO NOTHING;
