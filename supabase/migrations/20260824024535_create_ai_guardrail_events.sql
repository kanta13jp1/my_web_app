-- Issue #1254: privacy-preserving input/output guardrail observability.
-- Raw prompts and model output must never be stored in this table.

create table if not exists public.ai_guardrail_events (
  id bigint generated always as identity primary key,
  trace_id text not null,
  user_id uuid references auth.users(id) on delete set null,
  provider text not null,
  action text not null,
  stage text not null,
  decision text not null,
  categories text[] not null default '{}'::text[],
  redaction_count integer not null default 0,
  latency_ms integer not null default 0,
  content_chars integer not null default 0,
  policy_version text not null,
  created_at timestamptz not null default now(),
  constraint ai_guardrail_events_trace_id_length_check
    check (char_length(trace_id) between 1 and 128),
  constraint ai_guardrail_events_provider_length_check
    check (char_length(provider) between 1 and 64),
  constraint ai_guardrail_events_action_length_check
    check (char_length(action) between 1 and 96),
  constraint ai_guardrail_events_stage_check
    check (stage in ('input', 'output', 'provider')),
  constraint ai_guardrail_events_decision_check
    check (decision in ('allow', 'block', 'redact')),
  constraint ai_guardrail_events_category_count_check
    check (cardinality(categories) <= 16),
  constraint ai_guardrail_events_redaction_count_check
    check (redaction_count between 0 and 1000),
  constraint ai_guardrail_events_latency_ms_check
    check (latency_ms between 0 and 300000),
  constraint ai_guardrail_events_content_chars_check
    check (content_chars between 0 and 50000),
  constraint ai_guardrail_events_policy_version_length_check
    check (char_length(policy_version) between 1 and 64)
);

alter table public.ai_guardrail_events enable row level security;
alter table public.ai_guardrail_events force row level security;

revoke all on table public.ai_guardrail_events from anon, authenticated;
revoke all on sequence public.ai_guardrail_events_id_seq from anon, authenticated;
grant select, insert on table public.ai_guardrail_events to service_role;
grant usage, select on sequence public.ai_guardrail_events_id_seq to service_role;

create index if not exists ai_guardrail_events_created_at_idx
  on public.ai_guardrail_events (created_at desc);
create index if not exists ai_guardrail_events_provider_created_at_idx
  on public.ai_guardrail_events (provider, created_at desc);
create index if not exists ai_guardrail_events_user_id_idx
  on public.ai_guardrail_events (user_id)
  where user_id is not null;
create index if not exists ai_guardrail_events_incident_idx
  on public.ai_guardrail_events (decision, created_at desc)
  where decision <> 'allow';

comment on table public.ai_guardrail_events is
  'PII-free Writer input/output guardrail decisions for Issue #1254. Never stores prompt or response text.';
comment on column public.ai_guardrail_events.categories is
  'Bounded category identifiers only; no matched values or raw content.';
comment on column public.ai_guardrail_events.user_id is
  'Optional authenticated actor reference. Not returned by the admin overview endpoint.';
