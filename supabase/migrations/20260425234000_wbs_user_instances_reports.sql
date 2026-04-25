-- WBS instance normalization: retire all, add codex/gemini/co-pilot/user,
-- and support user task status reporting from the site.

ALTER TABLE public.wbs_tasks DROP CONSTRAINT IF EXISTS wbs_tasks_instance_check;
ALTER TABLE public.wbs_tasks DROP CONSTRAINT IF EXISTS wbs_tasks_owner_instance_check;

ALTER TABLE public.wbs_tasks
  ADD COLUMN IF NOT EXISTS user_report_status text NOT NULL DEFAULT 'not_reported',
  ADD COLUMN IF NOT EXISTS user_report_note text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS user_reported_at timestamptz;

UPDATE public.wbs_tasks
SET
  instance = CASE
    WHEN instance = 'windows' THEN 'win'
    WHEN instance = 'ps' THEN 'ps1'
    WHEN instance = 'copilot' THEN 'co-pilot'
    WHEN instance = 'all' THEN
      CASE
        WHEN category ILIKE '%marketing%' OR category ILIKE '%sales%' THEN 'ps2'
        WHEN category ILIKE '%ui%' OR category ILIKE '%frontend%' THEN 'vscode'
        WHEN category ILIKE '%gha%' OR category ILIKE '%workflow%' THEN 'gha'
        WHEN category ILIKE '%schedule%' OR category ILIKE '%batch%' THEN 'schedule'
        ELSE 'codex'
      END
    ELSE instance
  END,
  owner_instance = CASE
    WHEN owner_instance IS NULL THEN
      CASE
        WHEN instance = 'windows' THEN 'win'
        WHEN instance = 'ps' THEN 'ps1'
        WHEN instance = 'copilot' THEN 'co-pilot'
        WHEN instance = 'all' THEN 'codex'
        ELSE instance
      END
    WHEN owner_instance = 'windows' THEN 'win'
    WHEN owner_instance = 'ps' THEN 'ps1'
    WHEN owner_instance = 'copilot' THEN 'co-pilot'
    WHEN owner_instance = 'all' THEN 'codex'
    ELSE owner_instance
  END,
  updated_at = now()
WHERE instance IN ('all', 'windows', 'ps', 'copilot')
   OR owner_instance IS NULL
   OR owner_instance IN ('all', 'windows', 'ps', 'copilot');

UPDATE public.wbs_tasks AS task
SET
  instance = 'user',
  owner_instance = 'user',
  user_report_status = CASE
    WHEN user_report_status = 'not_reported' THEN 'waiting'
    ELSE user_report_status
  END,
  updated_at = now()
WHERE task.status != 'completed'
  AND (
    task.title ILIKE '%手動%'
    OR task.title ILIKE '%ユーザー操作%'
    OR task.title ILIKE '%Slack Webhook%'
    OR task.title ILIKE '%Notion%'
    OR task.title ILIKE '%GitHub Issue%'
    OR task.title ILIKE '%外部連携設定%'
    OR task.title ILIKE '%登録%'
    OR task.title ILIKE '%登記%'
    OR task.title ILIKE '%口座%'
    OR task.title ILIKE '%届出%'
    OR task.title ILIKE '%申請%'
    OR task.title ILIKE '%契約%'
    OR task.title ILIKE '%署名%'
    OR task.title ILIKE '%捺印%'
    OR task.title ILIKE '%本人確認%'
    OR task.title ILIKE '%面談%'
    OR task.title ILIKE '%面接%'
    OR task.title ILIKE '%選定%'
    OR task.title ILIKE '%承認%'
    OR task.title ILIKE '%公証%'
    OR task.title ILIKE '%司法書士%'
    OR task.title ILIKE '%税理士%'
    OR task.title ILIKE '%監査法人%'
    OR task.title ILIKE '%銀行%'
    OR task.title ILIKE '%freee%'
    OR task.title ILIKE '%マネフォ%'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.wbs_tasks existing
    WHERE existing.title = task.title
      AND existing.instance = 'user'
      AND existing.id <> task.id
  );

ALTER TABLE public.wbs_tasks ADD CONSTRAINT wbs_tasks_instance_check
  CHECK (instance IN (
    'codex', 'gemini', 'co-pilot', 'vscode', 'win',
    'ps1', 'ps2', 'ps3', 'ps4', 'ps5', 'ps6',
    'web', 'mobile', 'schedule', 'gha', 'user'
  ));

ALTER TABLE public.wbs_tasks ADD CONSTRAINT wbs_tasks_owner_instance_check
  CHECK (owner_instance IN (
    'codex', 'gemini', 'co-pilot', 'vscode', 'win',
    'ps1', 'ps2', 'ps3', 'ps4', 'ps5', 'ps6',
    'web', 'mobile', 'schedule', 'gha', 'user'
  ));

ALTER TABLE public.wbs_tasks DROP CONSTRAINT IF EXISTS wbs_tasks_user_report_status_check;
ALTER TABLE public.wbs_tasks ADD CONSTRAINT wbs_tasks_user_report_status_check
  CHECK (user_report_status IN (
    'not_reported', 'in_progress', 'waiting', 'completed', 'blocked'
  ));

CREATE INDEX IF NOT EXISTS idx_wbs_tasks_user_active
  ON public.wbs_tasks (status, priority, end_date)
  WHERE instance = 'user' OR owner_instance = 'user';

COMMENT ON COLUMN public.wbs_tasks.instance IS
  'Execution instance. all is retired. Valid values: codex/gemini/co-pilot/vscode/win/ps1-ps6/web/mobile/schedule/gha/user.';
COMMENT ON COLUMN public.wbs_tasks.owner_instance IS
  'Primary owner instance. Use user for tasks that require manual human operation.';
COMMENT ON COLUMN public.wbs_tasks.user_report_status IS
  'User-side report status for manual WBS tasks: not_reported/in_progress/waiting/completed/blocked.';
COMMENT ON COLUMN public.wbs_tasks.user_report_note IS
  'Latest user-side progress note for manual WBS tasks.';
COMMENT ON COLUMN public.wbs_tasks.user_reported_at IS
  'Timestamp of the latest user-side task report.';

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'WBS instance normalization and user task reporting',
  'Retired all as an assignable WBS instance, normalized co-pilot, added gemini/co-pilot/user lanes, routed manual-operation work to user, and added user report status fields for the site UI and Slack notification flow.',
  '2026-04-25'
)
ON CONFLICT DO NOTHING;
