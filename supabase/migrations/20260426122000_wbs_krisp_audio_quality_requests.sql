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

-- Some environments already have Codex-owned rows for these GitHub issues from
-- earlier WBS syncs. Keep one row per title before setting instance='codex' so
-- the unique index on (title, instance) stays satisfied during repair re-runs.
drop table if exists pg_temp.wbs_krisp_completed_titles;
create temp table wbs_krisp_completed_titles on commit drop as
select distinct title
from public.wbs_tasks
where github_issue_number in (752, 753, 754);

delete from public.wbs_tasks t
using (
  select id
  from (
    select
      candidate.id,
      row_number() over (
        partition by candidate.title
        order by
          case when candidate.instance = 'codex' then 0 else 1 end,
          candidate.created_at asc,
          candidate.id
      ) as keep_rank
    from public.wbs_tasks candidate
    join wbs_krisp_completed_titles target
      on target.title = candidate.title
    where candidate.github_issue_number in (752, 753, 754)
       or candidate.instance = 'codex'
  ) ranked
  where keep_rank > 1
) duplicate
where t.id = duplicate.id;

update public.wbs_tasks as task
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
from wbs_krisp_completed_titles target
where task.title = target.title
  and (
    task.github_issue_number in (752, 753, 754)
    or task.instance = 'codex'
  );

drop table if exists pg_temp.wbs_krisp_sdk_titles;
create temp table wbs_krisp_sdk_titles on commit drop as
select distinct title
from public.wbs_tasks
where github_issue_number = 755;

delete from public.wbs_tasks t
using (
  select id
  from (
    select
      candidate.id,
      row_number() over (
        partition by candidate.title
        order by
          case when candidate.instance = 'codex' then 0 else 1 end,
          candidate.created_at asc,
          candidate.id
      ) as keep_rank
    from public.wbs_tasks candidate
    join wbs_krisp_sdk_titles target
      on target.title = candidate.title
    where candidate.github_issue_number = 755
       or candidate.instance = 'codex'
  ) ranked
  where keep_rank > 1
) duplicate
where t.id = duplicate.id;

update public.wbs_tasks as task
set
  instance = 'codex',
  owner_instance = 'codex',
  status = 'in_progress',
  progress = greatest(progress, 60),
  start_date = coalesce(start_date, date '2026-04-26'),
  recovery_plan = CASE WHEN COALESCE(recovery_plan, '') = '' THEN 'Krisp SDK integration pending until SDK credentials/contract confirmed. Implementation plan documented in /krisp-audio-quality.' ELSE recovery_plan END,
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
from wbs_krisp_sdk_titles target
where task.title = target.title
  and (
    task.github_issue_number = 755
    or task.instance = 'codex'
  );
