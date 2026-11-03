-- Privacy-bounded aggregate journey counters for Tiger remediation #4958.
-- There are deliberately no user/session/IP/URL/provider/free-text columns.
alter table public.ai_university_content_events
  drop constraint if exists ai_university_content_events_event_name_check;

alter table public.ai_university_content_events
  add constraint ai_university_content_events_event_name_check check (
    event_name in (
      'content_fetch_failed',
      'fallback_shown',
      'retry_requested',
      'retry_succeeded',
      'retry_failed',
      'provider_search',
      'provider_selected',
      'content_opened',
      'quiz_completed',
      'review_returned'
    )
  );

comment on table public.ai_university_content_events is
  'Privacy-minimal anonymous AI University reliability and learning-journey counters.';

drop policy if exists "anonymous clients insert allowlisted content events"
  on public.ai_university_content_events;
create policy "anonymous clients insert allowlisted content events"
  on public.ai_university_content_events
  for insert
  to anon, authenticated
  with check (
    event_name in (
      'content_fetch_failed',
      'fallback_shown',
      'retry_requested',
      'retry_succeeded',
      'retry_failed',
      'provider_search',
      'provider_selected',
      'content_opened',
      'quiz_completed',
      'review_returned'
    )
    and surface = 'ai_university_content'
  );