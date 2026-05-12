-- Codex #3 / 2026-05-02: repair Notion mirror sync for slug-prefixed IDs.
--
-- Notion Mirror Sync failed when NOTION_ROADMAP_PAGE_ID was configured as a
-- user-visible slug plus 32 hex chars, e.g. ROADMAP-<notion-id>. schedule-hub
-- now normalizes Notion page/database IDs before calling the Notion API.

UPDATE public.wbs_tasks
SET status = CASE
      WHEN status = 'completed' THEN status
      ELSE 'in_progress'
    END,
    progress = CASE
      WHEN status = 'completed' THEN progress
      ELSE GREATEST(COALESCE(progress, 0), 95)
    END,
    remaining_work = CASE
      WHEN status = 'completed' THEN remaining_work
      ELSE 'After this fix deploys, rerun or wait for Notion Mirror Sync and confirm notion.sync_roadmap no longer fails with path.block_id validation_error.'
    END,
    recovery_plan = 'Normalize NOTION_* page/database IDs in schedule-hub so Notion URLs or slug-prefixed IDs are converted to UUIDs before blocks/databases/pages API calls.',
    recovery_planned_at = COALESCE(recovery_planned_at, NOW()),
    description = COALESCE(description, '') ||
      E'\n\n[Codex #3 / 2026-05-02] Repaired Notion Mirror Sync failure caused by slug-prefixed Notion IDs such as ROADMAP-<32hex>. schedule-hub now normalizes Notion IDs before list children, append blocks, database query, and page create/update calls.'
WHERE github_issue_number IN (1036, 1037, 1553)
   OR title ILIKE '%notion.sync_roadmap%'
   OR title ILIKE '%notion.sync_memory_index%'
   OR title ILIKE '%Notion Mirror Sync%';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Codex #3: Notion mirror ID normalization',
  'Fixed schedule-hub Notion page/database ID handling so ROADMAP and memory mirror syncs accept Notion URLs, UUIDs, 32-character IDs, and slug-prefixed IDs without block_id validation failures.',
  '2026-05-02'
)
ON CONFLICT DO NOTHING;
