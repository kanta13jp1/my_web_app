-- Codex #3 / 2026-05-03: complete Issue #1682 Home release notes intake.
--
-- Home now starts from the curated navigation categories requested in #1682,
-- and the global version badge plus fixed Home tools route to /release-notes.

UPDATE public.wbs_tasks
SET status = 'completed',
    progress = 100,
    ai_review_status = 'approved',
    remaining_work = 'Implemented /release-notes, connected the global version badge and Home fixed tools, and changed the default Home surface to the requested curated navigation categories.',
    recovery_plan = 'Keep Release Notes JSON current from GitHub/deploy history via #1683. If legacy operations cards are needed during QA, instantiate HomePage(showLegacyOperations: true).',
    recovery_planned_at = COALESCE(recovery_planned_at, NOW()),
    description = COALESCE(description, '') ||
      E'\n\n[Codex #3 / 2026-05-03] Added Release Notes page, Home fixed Release Notes entry, global version badge routing, and curated Home default sections for Issue #1682.'
WHERE github_issue_number = 1682
   OR title ILIKE '%Home%Release Notes%';

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'Codex #3: Home release notes navigation',
  'Added /release-notes with searchable version history and made the Home default surface focus on site guide, recent, popular, fixed, pinned, new, and AI recommended feature categories.',
  '2026-05-03'
)
ON CONFLICT DO NOTHING;
