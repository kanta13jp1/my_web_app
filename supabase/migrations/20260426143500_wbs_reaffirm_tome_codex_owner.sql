-- Reaffirm actual Codex ownership for completed Tome additional requests.
--
-- These tasks were implemented by Codex in this session. Some external syncs can
-- rewrite instance from closed GitHub state; keep the WBS owner accurate.

-- Production may already have Codex-owned rows with the same title from earlier
-- WBS syncs. Collapse those duplicates before reaffirming Codex ownership so
-- the (title, instance) unique index does not fail during migration repair.
drop table if exists pg_temp.wbs_tome_completed_titles;
create temp table wbs_tome_completed_titles on commit drop as
select distinct title
from public.wbs_tasks
where github_issue_number in (756, 757, 758);

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
    join wbs_tome_completed_titles target
      on target.title = candidate.title
    where candidate.github_issue_number in (756, 757, 758)
       or candidate.instance = 'codex'
  ) ranked
  where keep_rank > 1
) duplicate
where t.id = duplicate.id;

update public.wbs_tasks as task
set
  instance = 'codex',
  owner_instance = 'codex',
  updated_at = now()
from wbs_tome_completed_titles target
where task.title = target.title
  and (
    task.github_issue_number in (756, 757, 758)
    or task.instance = 'codex'
  );
