-- Complete verified Scale/RLHF additional-request tasks after the safe
-- GitHub/WBS sync repair.
--
-- Verification on 2026-04-26:
-- - flutter test test/services/ai_university_rlhf_service_test.dart
--   test/services/daily_judgment_quality_service_test.dart
--   test/services/user_data_finetune_readiness_service_test.dart
--   => 8 tests passed.
-- - deno lint supabase/functions/ai-hub/index.ts
--   => checked 1 file.

update public.wbs_tasks
set
  instance = 'codex',
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-24'),
  end_date = date '2026-04-26',
  priority = 'medium',
  ai_review_status = 'approved',
  github_issue_state = 'CLOSED',
  remaining_work = 'Completed by Codex after verification on 2026-04-26. AI University RLHF, daily judgment Scale evaluation, and first-party fine-tune readiness service tests passed; ai-hub Deno lint passed.',
  description = case
    when coalesce(description, '') like '%Verified close 2026-04-26: Codex confirmed the Scale/RLHF implementation and tests/lint passed.%'
      then description
    else coalesce(description, '') ||
      E'\n\nVerified close 2026-04-26: Codex confirmed the Scale/RLHF implementation and tests/lint passed. GitHub Issues #658-#660 were closed with evidence comments, avoiding the previous unsafe auto-close path.'
  end,
  updated_at = now()
where github_issue_number in (658, 659, 660);
