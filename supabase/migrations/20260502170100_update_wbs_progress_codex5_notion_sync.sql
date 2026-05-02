-- Codex #5 / 2026-05-02: complete WBS N3/N4 Notion sync actions.
--
-- This marks the due 2026-05-02 backlog items as completed after adding:
-- - schedule-hub:notion.sync_roadmap
-- - schedule-hub:notion.sync_memory_index
-- - notion-sync.yml calls for WBS + ROADMAP + memory index.

UPDATE public.wbs_tasks
SET status = 'completed',
    progress = 100,
    recovery_plan = COALESCE(
      NULLIF(trim(recovery_plan), ''),
      'Codex #5 implemented schedule-hub Notion roadmap and memory-index sync actions, plus hourly GitHub Actions wiring.'
    ),
    recovery_planned_at = COALESCE(recovery_planned_at, NOW()),
    description = COALESCE(description, '') ||
      E'\n\n[Codex #5 / 2026-05-02] Implemented schedule-hub notion.sync_roadmap and notion.sync_memory_index, and wired .github/workflows/notion-sync.yml to call WBS + ROADMAP + memory mirror syncs.'
WHERE github_issue_number IN (1036, 1037);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Codex #5: Notion ROADMAP + memory index mirror sync automation',
  'Completed WBS #1036/#1037 by adding schedule-hub notion.sync_roadmap and notion.sync_memory_index actions, plus hourly notion-sync.yml calls for WBS, ROADMAP, and memory index mirrors. This advances the NotebookLM harness rule that external-memory insights must land in docs/workflow/Issue/WBS automation.',
  '2026-05-02'
)
ON CONFLICT DO NOTHING;
