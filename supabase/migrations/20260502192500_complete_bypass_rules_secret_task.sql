-- Codex #1 closeout for the top overdue WBS item:
-- BYPASS_RULES secret exists and a workflow smoke test completed without GH006.

UPDATE public.wbs_tasks
SET
  status = 'completed',
  progress = 100,
  updated_at = now(),
  remaining_work = 'Completed: BYPASS_RULES exists in GitHub Actions secrets and AI Tool Changelog Watch run 25249810490 completed successfully on 2026-05-02 with no GH006 protected-branch error observed.',
  recovery_plan = 'Closed by Codex #1 after secret existence verification, readable setup documentation repair, and workflow_dispatch smoke test. Rotate BYPASS_RULES only if future workflow runs show GH006, expired token, or permission errors.',
  notebooklm_note = concat_ws(
    E'\n\n',
    nullif(notebooklm_note, ''),
    '[Codex #1 / 2026-05-02] Completed BYPASS_RULES closeout. Verified secret exists with gh secret list, repaired docs/BYPASS_RULES_SECRET_SETUP.md, and smoke-tested ai-tool-watch.yml run 25249810490 successfully.'
  ),
  notebooklm_synced_at = now()
WHERE title ILIKE 'BYPASS_RULES secret%'
  AND COALESCE(status, '') <> 'completed';
