-- Allow WBS drag-and-drop owner removal to persist as an explicit state.

DO $$
DECLARE
  invalid_owner_instances text[];
BEGIN
  SELECT array_agg(DISTINCT owner_instance ORDER BY owner_instance)
    INTO invalid_owner_instances
  FROM public.wbs_tasks
  WHERE owner_instance IS NOT NULL
    AND owner_instance <> ''
    AND owner_instance NOT IN (
      'claude', 'codex', 'codex1', 'codex2', 'cx', 'automation', 'auto',
      'user', 'usr', 'human',
      'gemini', 'co-pilot', 'copilot',
      'vscode', 'win', 'windows',
      'ps', 'ps1', 'ps2', 'ps3', 'ps4', 'ps5', 'ps6',
      'web', 'mobile', 'schedule', 'scheduled', 'gha', 'github-actions',
      'github-copilot', 'all', 'unassigned'
    );

  IF invalid_owner_instances IS NOT NULL THEN
    RAISE EXCEPTION 'wbs_tasks.owner_instance has unsupported values: %',
      invalid_owner_instances;
  END IF;
END $$;

ALTER TABLE public.wbs_tasks DROP CONSTRAINT IF EXISTS wbs_tasks_owner_instance_check;

ALTER TABLE public.wbs_tasks ADD CONSTRAINT wbs_tasks_owner_instance_check
  CHECK (
    owner_instance IS NULL
    OR owner_instance = ''
    OR owner_instance IN (
      'claude', 'codex', 'codex1', 'codex2', 'cx', 'automation', 'auto',
      'user', 'usr', 'human',
      'gemini', 'co-pilot', 'copilot',
      'vscode', 'win', 'windows',
      'ps', 'ps1', 'ps2', 'ps3', 'ps4', 'ps5', 'ps6',
      'web', 'mobile', 'schedule', 'scheduled', 'gha', 'github-actions',
      'github-copilot', 'all', 'unassigned'
    )
  );

COMMENT ON COLUMN public.wbs_tasks.owner_instance IS
  'Primary WBS owner. Empty legacy values are shown as unassigned; drag assignment UI writes unassigned when a task is removed from an owner lane.';
