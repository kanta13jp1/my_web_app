-- Reopen the WBS mirror row for Issue #669.
--
-- A previous sync treated progress=100/status=completed as enough evidence to
-- close the GitHub Issue. The linked Issue was reopened by the owner because it
-- is still an additional request, so keep the WBS task open until the real
-- implementation is completed and AI review is approved.

update public.wbs_tasks
set
  title = U&'[Issue #669] [\8FFD\52A0\8981\671B] \3010HeyGen\3011\591A\8A00\8A9ESNS\5C55\958B',
  instance = 'ps5',
  owner_instance = 'ps5',
  status = 'pending',
  progress = 0,
  ai_review_status = 'pending',
  remaining_work = 'GitHub Issue #669 is open; keep WBS open until actual implementation and AI review approval.',
  github_issue_state = 'OPEN',
  github_issue_synced_at = now(),
  updated_at = now()
where github_issue_number = 669;
