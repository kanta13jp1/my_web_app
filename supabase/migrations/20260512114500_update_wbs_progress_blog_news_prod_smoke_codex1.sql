-- Codex #1: Issue #1950 blog/news production smoke slice.
--
-- This records the deterministic production E2E guard for blog/news routes,
-- RSS Edge Function behavior, and read-only blog_posts queue visibility.

UPDATE public.wbs_tasks
SET status = 'in_progress',
    progress = GREATEST(progress, 45),
    recovery_plan = COALESCE(
      NULLIF(trim(recovery_plan), ''),
      'Codex #1 added blog/news production smoke automation. Remaining work: run external posting with real Qiita/dev.to credentials when user-approved, keep ready queue healthy, and close #1950 after live side-effect checks are accepted.'
    ),
    recovery_planned_at = COALESCE(recovery_planned_at, NOW()),
    description = COALESCE(description, '') ||
      E'\n\n[Codex #1 / 2026-05-12] Issue #1950 advanced: production smoke now checks /blog, /blog/compose, /news-rss, optional /blog/post?id=<postId>, tools-hub rss.fetch_latest, and read-only blog_posts queue state after deploy.'
WHERE github_issue_number = 1950;

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'Codex #1: blog/news production smoke (#1950)',
  'Added a deterministic GitHub Actions production smoke for blog/news routes, RSS Edge Function behavior, and read-only blog_posts queue visibility while keeping external publish side effects behind existing manual/user-approved gates.',
  '2026-05-12'
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'Codex #1: blog/news production smoke (#1950)'
);
