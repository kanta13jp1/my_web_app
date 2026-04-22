-- WBS Codex takeover: Home feature request form.
-- 2026-04-22
--
-- Scoped to the actual Codex work in this session: add a Home screen request
-- form that registers each request as a GitHub Issue and a WBS backlog task.

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
  'Core SaaS Features',
  'REQ',
  4,
  'Home feature request form with GitHub Issue and WBS sync',
  'Add a request form to the Home screen. Submissions are sent to core-hub, saved as feature request data, issued to GitHub Issues when GitHub credentials are configured, and registered as WBS user-request tasks.',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-22',
  '2026-04-22',
  'beta',
  'high',
  'Done 2026-04-22: Codex added the Home request form, core-hub feature_request.submit action, GitHub Issue creation, app_feedback/feature_requests recording, and WBS task creation.',
  'Next: configure GITHUB_PAT or GITHUB_TOKEN plus GITHUB_REPO in Supabase Edge Function secrets if production Issue creation is not already configured.',
  3
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = 'Home feature request form with GitHub Issue and WBS sync'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Home feature request form with Issue/WBS sync',
  'Codex added a Home screen request form that submits to core-hub. Requests are stored, GitHub Issues are created when credentials are configured, and WBS user-request tasks are registered automatically.',
  '2026-04-22'
)
ON CONFLICT DO NOTHING;
