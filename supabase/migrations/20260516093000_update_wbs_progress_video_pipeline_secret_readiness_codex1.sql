-- Codex #1: Issue #1724 video-pipeline secret readiness slice.
--
-- This records the deterministic preflight/report that turns missing video
-- pipeline secrets into an explicit readiness artifact without exposing values
-- or triggering NotebookLM/ElevenLabs/YouTube side effects.

UPDATE public.wbs_tasks
SET status = 'in_progress',
    progress = GREATEST(progress, 35),
    recovery_plan = COALESCE(
      NULLIF(trim(recovery_plan), ''),
      'Codex #1 added a video-pipeline secret readiness gate. Remaining work: user registers the five required secrets, runs the strict readiness workflow, dispatches notebooklm-video-pipeline.yml, and then replaces the temporary MP4 embed after YouTube upload succeeds.'
    ),
    recovery_planned_at = COALESCE(recovery_planned_at, NOW()),
    description = COALESCE(description, '') ||
      E'\n\n[Codex #1 / 2026-05-16] Issue #1724 advanced: NotebookLM video pipeline now has a boolean-only secret readiness workflow/report and an early required-secret preflight before any download, transcription, upload, or quota-consuming work.'
WHERE github_issue_number = 1724;

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'Codex #1: video pipeline secret readiness gate (#1724)',
  'Added a deterministic GitHub Actions readiness report and early NotebookLM video-pipeline preflight for the five required secrets without printing values or running external video side effects.',
  '2026-05-16'
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'Codex #1: video pipeline secret readiness gate (#1724)'
);
