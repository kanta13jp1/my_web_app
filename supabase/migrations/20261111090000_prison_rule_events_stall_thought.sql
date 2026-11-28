-- Optional "thought that stalls the start" label for debt-payoff guard events.
--
-- When the user cannot start a required action, the guard lets them name the
-- sentence in their head that is holding them back ("it won't work anyway",
-- "what's the point"). The client shows which thought most often ends in not
-- starting. Nullable: labelling is always optional and existing rows are
-- untouched.
alter table public.prison_rule_events
  add column if not exists stall_thought text;

alter table public.prison_rule_events
  drop constraint if exists prison_rule_events_stall_thought_check;

alter table public.prison_rule_events
  add constraint prison_rule_events_stall_thought_check
    check (stall_thought is null or stall_thought in (
      'futile',
      'pointless',
      'embarrassed',
      'perfectionism',
      'later',
      'too_small'
    ));

-- The label describes an attempt to start something: it either started or it
-- did not. Check-ins and resisted urges are not attempts to start.
alter table public.prison_rule_events
  drop constraint if exists prison_rule_events_stall_thought_event_type_check;

alter table public.prison_rule_events
  add constraint prison_rule_events_stall_thought_event_type_check
    check (
      stall_thought is null
      or event_type in ('required_action_started', 'violation')
    );

-- The trend query reads labelled rows for one user over a date window.
create index if not exists prison_rule_events_user_stall_thought_date_idx
  on public.prison_rule_events (user_id, event_date desc, id desc)
  where stall_thought is not null;

comment on column public.prison_rule_events.stall_thought is
  'Optional self-reported thought that was holding the user back from starting a required action. Null when the user skipped labelling.';
