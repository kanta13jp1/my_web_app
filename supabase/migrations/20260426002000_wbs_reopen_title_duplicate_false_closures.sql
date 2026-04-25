-- Reopen GitHub-origin WBS tasks that were incorrectly completed by
-- cross-issue title deduplication. Different GitHub issue numbers are not
-- duplicates just because their normalized titles look similar.

update public.wbs_tasks
set status = 'in_progress',
    progress = least(coalesce(progress, 0), 99),
    ai_review_status = case
      when lower(coalesce(ai_review_status, '')) in ('approved', 'verified', 'passed')
        then ai_review_status
      else 'pending'
    end,
    remaining_work = 'GitHub Issue is open; title-based duplicate cleanup was reverted. Keep open until actual implementation and AI review approval.',
    updated_at = now()
where github_issue_number is not null
  and upper(coalesce(github_issue_state, 'OPEN')) = 'OPEN'
  and coalesce(remaining_work, '') like 'Duplicate GitHub-origin WBS title%';
