-- Failed/cancelled authorized attempts are refunded and may consume another
-- bounded attempt. Keep exactly one active-or-successful child per review,
-- while allowing a later queued retry after a terminal failure.
drop index if exists public.video_generation_jobs_applied_review_uidx;

create unique index video_generation_jobs_applied_review_uidx
  on public.video_generation_jobs (user_id, applied_review_id)
  where applied_review_id is not null
    and authorization_id is not null
    and status in ('queued', 'in_progress', 'succeeded');
