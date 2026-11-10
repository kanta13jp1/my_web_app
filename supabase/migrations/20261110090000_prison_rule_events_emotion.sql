-- Optional emotion label for debt-payoff guard events.
--
-- The guard already records *what* was resisted or violated. This column
-- records the feeling behind the urge so the client can show which emotions
-- precede violations. It stays nullable: labelling is always optional and
-- existing rows are untouched.
alter table public.prison_rule_events
  add column if not exists emotion text;

alter table public.prison_rule_events
  drop constraint if exists prison_rule_events_emotion_check;

alter table public.prison_rule_events
  add constraint prison_rule_events_emotion_check
    check (emotion is null or emotion in (
      'irritation',
      'anxiety',
      'boredom',
      'loneliness',
      'fatigue',
      'sadness',
      'hunger',
      'elation'
    ));

-- A routine check-in is not an urge, so it never carries an emotion label.
alter table public.prison_rule_events
  drop constraint if exists prison_rule_events_emotion_event_type_check;

alter table public.prison_rule_events
  add constraint prison_rule_events_emotion_event_type_check
    check (emotion is null or event_type <> 'check_in');

-- The trend query reads only labelled rows for one user over a date window.
create index if not exists prison_rule_events_user_emotion_date_idx
  on public.prison_rule_events (user_id, event_date desc, id desc)
  where emotion is not null;

comment on column public.prison_rule_events.emotion is
  'Optional self-reported feeling behind an urge or violation. Null when the user skipped labelling.';
