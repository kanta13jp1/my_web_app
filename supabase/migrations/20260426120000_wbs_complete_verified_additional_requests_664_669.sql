-- Complete the verified high-priority "additional request" tasks after
-- restoring the issues that were previously closed by an unsafe sync.
--
-- Verification on 2026-04-26:
-- - flutter test test/services/manus_like_task_service_test.dart
--   test/services/heygen_blog_video_service_test.dart
--   test/services/ai_university_video_lesson_service_test.dart
--   test/services/heygen_multilingual_sns_service_test.dart
--   => 11 tests passed.
-- - deno lint supabase/functions/ai-hub/index.ts
--   supabase/functions/enterprise-hub/index.ts
--   => checked 2 files.

update public.wbs_tasks
set
  instance = case
    -- Issue #668 already has a codex duplicate row from the previous repair.
    -- Keep the existing instance value there to avoid violating the
    -- (title, instance) uniqueness guard while still completing both rows.
    when github_issue_number = 668 and instance <> 'codex' then instance
    else 'codex'
  end,
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-24'),
  end_date = date '2026-04-26',
  priority = 'high',
  ai_review_status = 'approved',
  github_issue_state = 'CLOSED',
  remaining_work = 'Completed by Codex after verification on 2026-04-26. Targeted Flutter service tests passed for Manus-like and HeyGen services, and Deno lint passed for ai-hub and enterprise-hub Edge Functions.',
  description = case
    when coalesce(description, '') like '%Verified close 2026-04-26: Codex confirmed implementation and tests/lint passed.%'
      then description
    else coalesce(description, '') ||
      E'\n\nVerified close 2026-04-26: Codex confirmed implementation and tests/lint passed. GitHub Issues #664-#669 were closed with evidence comments, avoiding the previous unsafe auto-close path.'
  end,
  updated_at = now()
where github_issue_number in (664, 665, 666, 667, 668, 669);
