-- Allow WBS drag-and-drop owner removal to persist as an explicit state.

ALTER TABLE public.wbs_tasks DROP CONSTRAINT IF EXISTS wbs_tasks_owner_instance_check;

ALTER TABLE public.wbs_tasks ADD CONSTRAINT wbs_tasks_owner_instance_check
  CHECK (owner_instance IN (
    'claude', 'codex', 'codex1', 'codex2', 'cx', 'automation', 'auto',
    'user', 'usr', 'human',
    'gemini', 'co-pilot', 'copilot',
    'vscode', 'win', 'windows',
    'ps', 'ps1', 'ps2', 'ps3', 'ps4', 'ps5', 'ps6',
    'web', 'mobile', 'schedule', 'scheduled', 'gha', 'github-actions',
    'github-copilot', 'all', 'unassigned'
  ));

COMMENT ON COLUMN public.wbs_tasks.owner_instance IS
  'Primary WBS owner. Drag assignment UI may set unassigned when a task is removed from an owner lane.';
