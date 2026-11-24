-- Batch 75 (#2659): RLHF bad/problematic AI output feedback -> GitHub Issue (AI-Feedback) webhook table & guards.

create extension if not exists pg_net with schema extensions;
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.ai_rlhf_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  action_name text not null check (char_length(trim(action_name)) between 1 and 120),
  model_id text not null default '' check (char_length(model_id) <= 120),
  prompt_text text not null check (char_length(trim(prompt_text)) between 1 and 8000),
  ai_output text not null check (char_length(trim(ai_output)) between 1 and 16000),
  rating_status text not null default 'bad'
    check (rating_status in ('good', 'bad', 'problematic')),
  user_comment text not null default '' check (char_length(user_comment) <= 4000),
  dispatch_status text not null default 'pending'
    check (dispatch_status in ('not_needed', 'pending', 'processing', 'dispatched', 'skipped', 'failed')),
  github_issue_number integer check (github_issue_number is null or github_issue_number > 0),
  github_issue_url text check (
    github_issue_url is null
    or (char_length(github_issue_url) <= 500 and github_issue_url like 'https://%')
  ),
  webhook_dispatched_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_ai_rlhf_feedback_user_created
  on public.ai_rlhf_feedback (user_id, created_at desc);

create index if not exists idx_ai_rlhf_feedback_rating_dispatch
  on public.ai_rlhf_feedback (rating_status, dispatch_status, created_at desc);

alter table public.ai_rlhf_feedback enable row level security;

revoke all on table public.ai_rlhf_feedback from public, anon;
grant select, insert, update on table public.ai_rlhf_feedback to authenticated;
grant all on table public.ai_rlhf_feedback to service_role;

drop policy if exists "ai_rlhf_feedback_select_own_or_admin"
  on public.ai_rlhf_feedback;
create policy "ai_rlhf_feedback_select_own_or_admin"
  on public.ai_rlhf_feedback
  for select
  to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1
      from public.user_profiles as up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  );

drop policy if exists "ai_rlhf_feedback_insert_own"
  on public.ai_rlhf_feedback;
create policy "ai_rlhf_feedback_insert_own"
  on public.ai_rlhf_feedback
  for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists "ai_rlhf_feedback_update_own_or_admin"
  on public.ai_rlhf_feedback;
create policy "ai_rlhf_feedback_update_own_or_admin"
  on public.ai_rlhf_feedback
  for update
  to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1
      from public.user_profiles as up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  )
  with check (
    user_id = auth.uid()
    or exists (
      select 1
      from public.user_profiles as up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  );

create or replace function public.guard_ai_rlhf_feedback_fields()
returns trigger
language plpgsql
security invoker
set search_path = public, auth, extensions, pg_catalog, pg_temp
as $guard$
declare
  v_jwt_role text;
  v_claims_raw text;
  v_claims_json jsonb;
  v_is_service boolean;
  v_is_admin boolean;
begin
  v_jwt_role := coalesce(
    nullif(auth.jwt() ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );
  if v_jwt_role = '' then
    v_claims_raw := nullif(current_setting('request.jwt.claims', true), '');
    if v_claims_raw is not null then
      begin
        v_claims_json := v_claims_raw::jsonb;
        v_jwt_role := coalesce(nullif(v_claims_json ->> 'role', ''), '');
      exception when others then
        v_jwt_role := '';
      end;
    end if;
  end if;
  v_is_service := (v_jwt_role = 'service_role')
    or (
      session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
      and v_jwt_role = ''
    );
  v_is_admin := exists (
    select 1
    from public.user_profiles as up
    where up.user_id = auth.uid()
      and up.is_admin = true
  );

  if v_is_service or v_is_admin then
    if tg_op = 'INSERT' then
      new.id := coalesce(new.id, gen_random_uuid());
      new.created_at := coalesce(new.created_at, timezone('utc', now()));
    end if;
    new.updated_at := timezone('utc', now());
    return new;
  end if;

  if tg_op = 'INSERT' then
    if auth.uid() is null or new.user_id is distinct from auth.uid() then
      raise exception 'Authenticated owner user_id is required on RLHF feedback insert'
        using errcode = '42501';
    end if;
    if new.github_issue_number is not null
       or new.github_issue_url is not null
       or new.webhook_dispatched_at is not null
       or new.dispatch_status not in ('not_needed', 'pending') then
      raise exception 'Non-admin users cannot set RLHF GitHub dispatch metadata on insert'
        using errcode = '42501';
    end if;
    new.id := coalesce(new.id, gen_random_uuid());
    new.dispatch_status := case
      when new.rating_status in ('bad', 'problematic') then 'pending'
      else 'not_needed'
    end;
    new.created_at := timezone('utc', now());
    new.updated_at := timezone('utc', now());
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if new.id is distinct from old.id
       or new.user_id is distinct from old.user_id
       or new.created_at is distinct from old.created_at then
      raise exception 'RLHF feedback identity and ownership cannot be modified'
        using errcode = '42501';
    end if;
    if new.dispatch_status is distinct from old.dispatch_status
       or new.github_issue_number is distinct from old.github_issue_number
       or new.github_issue_url is distinct from old.github_issue_url
       or new.webhook_dispatched_at is distinct from old.webhook_dispatched_at then
      raise exception 'Non-admin users cannot modify RLHF GitHub dispatch metadata'
        using errcode = '42501';
    end if;
    if old.github_issue_number is null
       and old.rating_status = 'good'
       and new.rating_status in ('bad', 'problematic') then
      new.dispatch_status := 'pending';
    elsif old.github_issue_number is null
       and new.rating_status = 'good'
       and old.dispatch_status = 'pending' then
      new.dispatch_status := 'not_needed';
    end if;
    new.updated_at := timezone('utc', now());
    return new;
  end if;

  return new;
end;
$guard$;

revoke all on function public.guard_ai_rlhf_feedback_fields() from public, anon, authenticated;

drop trigger if exists guard_ai_rlhf_feedback_fields
  on public.ai_rlhf_feedback;
drop trigger if exists trg_10_guard_ai_rlhf_feedback_fields
  on public.ai_rlhf_feedback;
create trigger trg_10_guard_ai_rlhf_feedback_fields
  before insert or update on public.ai_rlhf_feedback
  for each row
  execute function public.guard_ai_rlhf_feedback_fields();

create or replace function public.notify_ai_rlhf_bad_feedback_webhook()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog, extensions, net, vault, pg_temp
as $webhook$
declare
  v_hmac_cred text;
  v_webhook_url text;
  v_payload jsonb;
  v_payload_text text;
  v_signature text;
  v_headers jsonb;
  v_should_dispatch boolean := true;
begin
  new.id := coalesce(new.id, gen_random_uuid());

  if tg_op = 'UPDATE' and new.rating_status is not distinct from old.rating_status then
    return new;
  end if;

  if new.rating_status not in ('bad', 'problematic')
     or new.github_issue_number is not null
     or new.dispatch_status <> 'pending' then
    return new;
  end if;

  begin
    select decrypted_secret
      into v_hmac_cred
      from vault.decrypted_secrets
      where name = 'rlhf_webhook_secret'
      limit 1;
  exception when others then
    raise notice 'vault.decrypted_secrets not accessible — RLHF webhook trigger skipped';
    v_should_dispatch := false;
  end;

  if v_should_dispatch and (v_hmac_cred is null or v_hmac_cred = '') then
    raise notice 'rlhf_webhook_secret not in vault — RLHF webhook trigger skipped';
    v_should_dispatch := false;
  end if;

  if v_should_dispatch then
    begin
      select decrypted_secret
        into v_webhook_url
        from vault.decrypted_secrets
        where name = 'rlhf_webhook_url'
        limit 1;
    exception when others then
      raise notice 'rlhf_webhook_url lookup failed — RLHF webhook trigger skipped';
      v_should_dispatch := false;
      v_webhook_url := null;
    end;
  end if;

  if v_should_dispatch and (
    v_webhook_url is null
    or v_webhook_url = ''
    or v_webhook_url !~ '^https://[A-Za-z0-9.-]+(?::[0-9]+)?/'
    or v_webhook_url ~* '^https://(localhost|127\.|0\.0\.0\.0|\[::1\]|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|169\.254\.)'
  ) then
    raise notice 'rlhf_webhook_url missing or invalid in vault — RLHF webhook trigger skipped';
    v_should_dispatch := false;
  end if;

  if v_should_dispatch then
    begin
      v_payload := jsonb_build_object(
        'type', tg_op,
        'table', 'ai_rlhf_feedback',
        'schema', 'public',
        'record', jsonb_build_object(
          'id', new.id,
          'user_id', new.user_id,
          'action_name', new.action_name,
          'model_id', new.model_id,
          'prompt_text', new.prompt_text,
          'ai_output', new.ai_output,
          'rating_status', new.rating_status,
          'user_comment', new.user_comment,
          'dispatch_status', new.dispatch_status,
          'created_at', new.created_at
        )
      );
      v_payload_text := v_payload::text;
      v_signature := 'sha256=' || encode(
        extensions.hmac(convert_to(v_payload_text, 'utf8'), convert_to(v_hmac_cred, 'utf8'), 'sha256'),
        'hex'
      );
      v_headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'X-Webhook-Signature', v_signature
      );

      perform net.http_post(
        url := v_webhook_url,
        headers := v_headers,
        body := v_payload
      );
      return new;
    exception when others then
      raise notice 'RLHF webhook trigger skipped: %', sqlerrm;
      v_should_dispatch := false;
    end;
  end if;

  -- Keep dispatch_status as 'pending' when webhook dispatch is skipped or
  -- fails so scheduled/manual dispatchers can retry it.
  return null;
end;
$webhook$;

revoke all on function public.notify_ai_rlhf_bad_feedback_webhook() from public, anon, authenticated;

drop trigger if exists trg_notify_ai_rlhf_bad_feedback_webhook
  on public.ai_rlhf_feedback;
drop trigger if exists trg_20_notify_ai_rlhf_bad_feedback_webhook
  on public.ai_rlhf_feedback;
create trigger trg_20_notify_ai_rlhf_bad_feedback_webhook
  after insert or update of rating_status, dispatch_status on public.ai_rlhf_feedback
  for each row
  execute function public.notify_ai_rlhf_bad_feedback_webhook();

comment on table public.ai_rlhf_feedback is
  'User RLHF ratings on AI outputs with Database Webhook dispatch tracking for bad/problematic items (#2659).';
