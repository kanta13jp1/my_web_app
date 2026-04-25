-- Defense in depth: an open GitHub Issue must not become completed/100%
-- just because a WBS sync, old migration, or auxiliary workflow touches it.
-- Completion is allowed only after explicit AI/human approval.

create or replace function public.wbs_guard_open_github_issue_completion()
returns trigger
language plpgsql
as $$
begin
  if new.github_issue_number is not null
     and upper(coalesce(new.github_issue_state, 'OPEN')) = 'OPEN'
     and lower(coalesce(new.ai_review_status, 'pending')) not in
       ('approved', 'verified', 'passed', 'manual_override') then
    if coalesce(new.progress, 0) >= 100 then
      new.progress := 99;
    end if;

    if new.status = 'completed' then
      new.status := 'in_progress';
    end if;

    if new.ai_review_status = 'requested' then
      new.ai_review_status := 'pending';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists wbs_open_github_issue_completion_guard on public.wbs_tasks;

create trigger wbs_open_github_issue_completion_guard
before insert or update on public.wbs_tasks
for each row
execute function public.wbs_guard_open_github_issue_completion();

update public.wbs_tasks
set status = case when status = 'completed' then 'in_progress' else status end,
    progress = least(coalesce(progress, 0), 99),
    ai_review_status = case
      when lower(coalesce(ai_review_status, 'pending')) in
        ('approved', 'verified', 'passed', 'manual_override')
        then ai_review_status
      else 'pending'
    end,
    github_issue_state = 'OPEN',
    updated_at = now()
where github_issue_number is not null
  and upper(coalesce(github_issue_state, 'OPEN')) = 'OPEN'
  and (
    coalesce(progress, 0) >= 100
    or status = 'completed'
    or ai_review_status = 'requested'
  );
