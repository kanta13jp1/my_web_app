-- Issue #2484: persistence for the asset-management AI chat assistant.
-- This migration adds storage and owner-only access. Provider calls and UI
-- wiring remain disabled until their separately scoped follow-up issues.

begin;

create table if not exists public.asset_chat_threads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  created_at timestamptz not null default now(),
  last_message_at timestamptz not null default now(),
  constraint asset_chat_threads_title_length
    check (length(btrim(title)) between 1 and 200),
  constraint asset_chat_threads_last_message_not_before_created
    check (last_message_at >= created_at)
);

create table if not exists public.asset_chat_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null
    references public.asset_chat_threads(id) on delete cascade,
  role text not null,
  content text not null,
  tokens_in integer not null default 0,
  tokens_out integer not null default 0,
  model text,
  created_at timestamptz not null default now(),
  constraint asset_chat_messages_role_valid
    check (role in ('user', 'assistant')),
  constraint asset_chat_messages_content_length
    check (length(btrim(content)) between 1 and 50000),
  constraint asset_chat_messages_tokens_in_non_negative
    check (tokens_in >= 0),
  constraint asset_chat_messages_tokens_out_non_negative
    check (tokens_out >= 0),
  constraint asset_chat_messages_model_length
    check (model is null or length(btrim(model)) between 1 and 200)
);

create index if not exists asset_chat_threads_user_activity_idx
  on public.asset_chat_threads (
    user_id,
    last_message_at desc,
    id
  );

create index if not exists asset_chat_messages_thread_created_idx
  on public.asset_chat_messages (thread_id, created_at, id);

comment on table public.asset_chat_threads is
  'Per-user conversation threads for the asset-management AI assistant. Issue #2484.';
comment on column public.asset_chat_threads.last_message_at is
  'Stable thread-list ordering key. The trusted writer updates it when a message is persisted.';
comment on table public.asset_chat_messages is
  'Ordered user and assistant messages for an asset-management chat thread.';
comment on column public.asset_chat_messages.content is
  'Conversation text only. Financial calculations remain deterministic outside the LLM.';
comment on column public.asset_chat_messages.tokens_in is
  'Provider-reported input token count. Zero when unavailable or not applicable.';
comment on column public.asset_chat_messages.tokens_out is
  'Provider-reported output token count. Zero when unavailable or not applicable.';

alter table public.asset_chat_threads enable row level security;
alter table public.asset_chat_messages enable row level security;

-- RLS does not cover TRUNCATE, REFERENCES, or TRIGGER. Remove inherited
-- privileges and expose only policy-backed CRUD to authenticated clients.
revoke all privileges on table
  public.asset_chat_threads,
  public.asset_chat_messages
from public, anon, authenticated;

grant all privileges on table
  public.asset_chat_threads,
  public.asset_chat_messages
to service_role;

grant select, insert, update, delete on table
  public.asset_chat_threads,
  public.asset_chat_messages
to authenticated;

drop policy if exists asset_chat_threads_select_own
  on public.asset_chat_threads;
create policy asset_chat_threads_select_own
  on public.asset_chat_threads
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists asset_chat_threads_insert_own
  on public.asset_chat_threads;
create policy asset_chat_threads_insert_own
  on public.asset_chat_threads
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists asset_chat_threads_update_own
  on public.asset_chat_threads;
create policy asset_chat_threads_update_own
  on public.asset_chat_threads
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists asset_chat_threads_delete_own
  on public.asset_chat_threads;
create policy asset_chat_threads_delete_own
  on public.asset_chat_threads
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists asset_chat_messages_select_own
  on public.asset_chat_messages;
create policy asset_chat_messages_select_own
  on public.asset_chat_messages
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.asset_chat_threads as thread_row
      where thread_row.id = asset_chat_messages.thread_id
        and thread_row.user_id = (select auth.uid())
    )
  );

drop policy if exists asset_chat_messages_insert_own
  on public.asset_chat_messages;
create policy asset_chat_messages_insert_own
  on public.asset_chat_messages
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.asset_chat_threads as thread_row
      where thread_row.id = asset_chat_messages.thread_id
        and thread_row.user_id = (select auth.uid())
    )
  );

drop policy if exists asset_chat_messages_update_own
  on public.asset_chat_messages;
create policy asset_chat_messages_update_own
  on public.asset_chat_messages
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.asset_chat_threads as thread_row
      where thread_row.id = asset_chat_messages.thread_id
        and thread_row.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1
      from public.asset_chat_threads as thread_row
      where thread_row.id = asset_chat_messages.thread_id
        and thread_row.user_id = (select auth.uid())
    )
  );

drop policy if exists asset_chat_messages_delete_own
  on public.asset_chat_messages;
create policy asset_chat_messages_delete_own
  on public.asset_chat_messages
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.asset_chat_threads as thread_row
      where thread_row.id = asset_chat_messages.thread_id
        and thread_row.user_id = (select auth.uid())
    )
  );

commit;
