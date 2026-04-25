-- Restore GitHub Issues that were reopened after the pre-fix WBS sync
-- incorrectly closed them as completed.

update public.wbs_tasks
set instance = 'ps5',
    owner_instance = 'ps5',
    status = 'pending',
    progress = 0,
    ai_review_status = 'pending',
    github_issue_state = 'OPEN',
    remaining_work = 'GitHub Issue #' || github_issue_number ||
      ' is open; keep WBS open until actual implementation and AI review approval.',
    updated_at = now()
where github_issue_number in (658, 659, 660, 664, 665, 666, 667, 668, 669)
  and id <> 'e224b3c7-b79f-4403-92fb-431bac67d5ea';

update public.wbs_tasks
set status = 'in_progress',
    progress = least(coalesce(progress, 0), 99),
    ai_review_status = 'pending',
    github_issue_state = 'OPEN',
    remaining_work =
      'Duplicate of WBS task d0465d8b-9bca-4d71-b0e3-d12d7f126ba1; ' ||
      'GitHub Issue #668 is kept on one canonical WBS row and remains open.',
    updated_at = now()
where id = 'e224b3c7-b79f-4403-92fb-431bac67d5ea';
