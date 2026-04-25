-- Reaffirm actual Codex ownership for completed Tome additional requests.
--
-- These tasks were implemented by Codex in this session. Some external syncs can
-- rewrite instance from closed GitHub state; keep the WBS owner accurate.

update public.wbs_tasks
set
  instance = 'codex',
  owner_instance = 'codex',
  updated_at = now()
where github_issue_number in (756, 757, 758);
