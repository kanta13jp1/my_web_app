-- Progress the Krisp additional-request queue.
--
-- Implementation on 2026-04-26:
-- - Added /krisp-audio-quality.
-- - Added a shared Krisp audio quality service covering remote meetings,
--   podcast recording, investor/client calls, and future AI coach SDK readiness.
-- - Added Home catalog entry and direct route.
--
-- Verification:
-- - flutter test test/services/krisp_audio_quality_service_test.dart
--   => 3 tests passed.
-- - dart analyze lib/services/krisp_audio_quality_service.dart
--   lib/pages/krisp_audio_quality_page.dart
--   test/services/krisp_audio_quality_service_test.dart
--   => no issues.
-- - dart analyze lib/main.dart lib/data/home_tool_catalog.dart
--   => no issues.

update public.wbs_tasks
set
  instance = 'codex',
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-26'),
  end_date = date '2026-04-26',
  ai_review_status = 'approved',
  github_issue_state = 'CLOSED',
  remaining_work = 'Completed by Codex. Krisp audio quality cockpit was added at /krisp-audio-quality with KGI/CSF/KPI, scenario checklists, and shareable quality plans.',
  description = case
    when coalesce(description, '') like '%Done 2026-04-26: Codex added Krisp audio quality cockpit.%'
      then description
    else coalesce(description, '') ||
      E'\n\nDone 2026-04-26: Codex added Krisp audio quality cockpit. The route /krisp-audio-quality and Home entry now cover remote meetings, podcast/Tech Talk recording, and investor/client call quality with KGI/CSF/KPI, checklists, risks, and official Krisp reference links.'
  end,
  updated_at = now()
where github_issue_number in (752, 753, 754);

update public.wbs_tasks
set
  instance = 'codex',
  owner_instance = 'codex',
  status = 'in_progress',
  progress = greatest(progress, 60),
  start_date = coalesce(start_date, date '2026-04-26'),
  ai_review_status = 'pending',
  github_issue_state = 'OPEN',
  remaining_work = 'Krisp SDK readiness plan is visible in /krisp-audio-quality. Remaining work: confirm Krisp SDK contract/API key/model distribution, then implement the WebRTC/Web Audio noise filter in the future AI coach voice pipeline.',
  description = case
    when coalesce(description, '') like '%Progress 2026-04-26: Codex added Krisp SDK readiness planning.%'
      then description
    else coalesce(description, '') ||
      E'\n\nProgress 2026-04-26: Codex added Krisp SDK readiness planning to /krisp-audio-quality. Actual SDK embedding remains open until Krisp SDK credentials, model delivery, and WebRTC/Web Audio integration constraints are confirmed.'
  end,
  updated_at = now()
where github_issue_number = 755;
