-- Daily commitment and impulse events for the debt-payoff guard.
--
-- Events are append-only for authenticated clients. A later check-in cannot
-- erase a violation from the same day; the application derives that rule from
-- the complete event stream.
create table if not exists public.prison_rule_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  rule_id text not null,
  event_type text not null,
  note text,
  event_date date not null,
  created_at timestamptz not null default now(),
  constraint prison_rule_events_rule_id_length
    check (char_length(rule_id) between 1 and 80),
  constraint prison_rule_events_event_type_check
    check (event_type in (
      'check_in',
      'urge_resisted',
      'required_action_started',
      'violation'
    )),
  constraint prison_rule_events_note_length
    check (note is null or char_length(note) <= 500)
);

create index if not exists prison_rule_events_user_date_created_idx
  on public.prison_rule_events (user_id, event_date, created_at desc);

create index if not exists prison_rule_events_user_rule_date_idx
  on public.prison_rule_events (user_id, rule_id, event_date);

alter table public.prison_rule_events enable row level security;

revoke all on table public.prison_rule_events from anon;
revoke all on sequence public.prison_rule_events_id_seq from anon;
revoke all on table public.prison_rule_events from authenticated;
revoke all on sequence public.prison_rule_events_id_seq from authenticated;

grant select, insert on table public.prison_rule_events to authenticated;
grant usage, select on sequence public.prison_rule_events_id_seq
  to authenticated;

drop policy if exists "Users can view own prison rule events"
  on public.prison_rule_events;
create policy "Users can view own prison rule events"
  on public.prison_rule_events
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can append own prison rule events"
  on public.prison_rule_events;
create policy "Users can append own prison rule events"
  on public.prison_rule_events
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

comment on table public.prison_rule_events is
  'Append-only daily check-ins, resisted urges, required-action starts, and violations while debt payoff guard is active.';
