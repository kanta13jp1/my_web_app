-- WBS Codex takeover: all-feature life-capital focus gate.
-- 2026-04-23
--
-- Scoped to the actual Codex work in this session: make the all-feature
-- AI/KGI/CSF/KPI monitor choose one low-hurdle action first, so continuous
-- life-management work does not collapse under too many simultaneous tasks.

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
  '全機能生命資本フォーカスゲート',
  '全機能AI戦略モニターに、時間・お金・健康・体力・知能・集中力のうち最も弱い生命資本から今日の低ハードル1手を自動選定し、他の資本や機能は観察に回す導線を追加する。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-23',
  '2026-04-23',
  'beta',
  'high',
  'Done 2026-04-23: Codex added a focus recommendation model, low-hurdle action selection, AI review context, UI focus card, and regression tests for the all-feature life-capital monitor.',
  'Next: tune the low-hurdle scoring from real usage logs and let users explicitly complete or defer the chosen action.',
  2
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '全機能生命資本フォーカスゲート'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '全機能生命資本フォーカスゲート',
  'Codex extended the all-feature AI strategy monitor with a one-action focus gate. The monitor now finds the weakest life-capital resource, picks a low-hurdle feature action for today, parks the rest as observation-only, includes that context in ai-hub review prompts, and renders a focus card on Home.',
  '2026-04-23'
)
ON CONFLICT DO NOTHING;
