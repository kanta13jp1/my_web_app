-- Migration for Issue #2665: 5-Element Structured Prompt Template Knowledge Management
-- Stores reusable structured prompts across 5 independent elements:
--   1) role_setting (役割設定)
--   2) context_info (コンテキスト情報)
--   3) deliverable_definition (成果物の定義)
--   4) constraints_text (制約条件)
--   5) thinking_process (思考プロセス)

create table if not exists public.prompt_templates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 120),
  role_setting text not null check (char_length(trim(role_setting)) between 1 and 2000),
  context_info text not null check (char_length(trim(context_info)) between 1 and 4000),
  deliverable_definition text not null check (char_length(trim(deliverable_definition)) between 1 and 4000),
  constraints_text text not null check (char_length(trim(constraints_text)) between 1 and 4000),
  thinking_process text not null check (char_length(trim(thinking_process)) between 1 and 4000),
  is_shared boolean not null default false,
  usage_count integer not null default 0 check (usage_count >= 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_prompt_templates_user_updated
  on public.prompt_templates (user_id, updated_at desc);

create index if not exists idx_prompt_templates_shared_usage
  on public.prompt_templates (is_shared, usage_count desc, updated_at desc);

alter table public.prompt_templates enable row level security;

revoke all on table public.prompt_templates from public, anon, authenticated;
grant select, insert, update, delete on table public.prompt_templates to authenticated;
grant all on table public.prompt_templates to service_role;

drop policy if exists "prompt_templates_select_own_or_shared"
  on public.prompt_templates;
create policy "prompt_templates_select_own_or_shared"
  on public.prompt_templates
  for select
  to authenticated
  using (auth.uid() = user_id or is_shared = true);

drop policy if exists "prompt_templates_insert_own"
  on public.prompt_templates;
create policy "prompt_templates_insert_own"
  on public.prompt_templates
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "prompt_templates_update_own"
  on public.prompt_templates;
create policy "prompt_templates_update_own"
  on public.prompt_templates
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "prompt_templates_delete_own"
  on public.prompt_templates;
create policy "prompt_templates_delete_own"
  on public.prompt_templates
  for delete
  to authenticated
  using (auth.uid() = user_id);

create or replace function public.guard_prompt_template_fields()
returns trigger
language plpgsql
security invoker
set search_path = public, auth, pg_catalog, pg_temp
as $guard$
declare
  v_raw_claims text := nullif(current_setting('request.jwt.claims', true), '');
  v_claims jsonb;
  v_jwt_role text;
  v_is_service boolean;
  v_rpc_active boolean :=
    coalesce(current_setting('app.prompt_template_usage_rpc', true), '') = 'on';
begin
  if v_raw_claims is not null then
    begin
      v_claims := v_raw_claims::jsonb;
    exception
      when others then
        v_claims := null;
    end;
  end if;

  v_jwt_role := coalesce(
    nullif(auth.jwt() ->> 'role', ''),
    nullif(v_claims ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );
  v_is_service := (v_jwt_role = 'service_role')
    or (
      v_jwt_role = ''
      and session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
    );

  if TG_OP = 'INSERT' then
    if not v_is_service then
      if auth.uid() is null then
        raise exception 'Authentication required to create prompt template'
          using errcode = '42501';
      end if;
      if new.user_id is null then
        new.user_id := auth.uid();
      elsif new.user_id is distinct from auth.uid() then
        raise exception 'user_id must match authenticated user'
          using errcode = '42501';
      end if;
      new.usage_count := 0;
    elsif new.user_id is null then
      raise exception 'user_id must not be null'
        using errcode = '42501';
    end if;

    new.title := trim(coalesce(new.title, ''));
    new.role_setting := trim(coalesce(new.role_setting, ''));
    new.context_info := trim(coalesce(new.context_info, ''));
    new.deliverable_definition := trim(coalesce(new.deliverable_definition, ''));
    new.constraints_text := trim(coalesce(new.constraints_text, ''));
    new.thinking_process := trim(coalesce(new.thinking_process, ''));
    new.created_at := timezone('utc', now());
    new.updated_at := timezone('utc', now());
    return new;
  end if;

  if new.id is distinct from old.id
    or new.user_id is distinct from old.user_id
    or new.created_at is distinct from old.created_at then
    raise exception 'id, user_id, and created_at are immutable'
      using errcode = '42501';
  end if;

  if not v_is_service then
    if v_rpc_active then
      if new.title is distinct from old.title
        or new.role_setting is distinct from old.role_setting
        or new.context_info is distinct from old.context_info
        or new.deliverable_definition is distinct from old.deliverable_definition
        or new.constraints_text is distinct from old.constraints_text
        or new.thinking_process is distinct from old.thinking_process
        or new.is_shared is distinct from old.is_shared
        or new.usage_count is distinct from (old.usage_count + 1) then
        raise exception 'Usage counter update cannot alter template content or set arbitrary counts'
          using errcode = '42501';
      end if;
    else
      if auth.uid() is null or auth.uid() is distinct from old.user_id then
        raise exception 'Only the template owner can modify this prompt template'
          using errcode = '42501';
      end if;
      if new.usage_count is distinct from old.usage_count then
        raise exception 'usage_count can only be updated via increment_prompt_template_usage or service_role'
          using errcode = '42501';
      end if;
    end if;
  end if;

  new.title := trim(coalesce(new.title, ''));
  new.role_setting := trim(coalesce(new.role_setting, ''));
  new.context_info := trim(coalesce(new.context_info, ''));
  new.deliverable_definition := trim(coalesce(new.deliverable_definition, ''));
  new.constraints_text := trim(coalesce(new.constraints_text, ''));
  new.thinking_process := trim(coalesce(new.thinking_process, ''));
  new.updated_at := timezone('utc', now());
  return new;
end;
$guard$;

revoke all on function public.guard_prompt_template_fields() from public, anon, authenticated;

drop trigger if exists guard_prompt_template_fields
  on public.prompt_templates;
create trigger guard_prompt_template_fields
  before insert or update on public.prompt_templates
  for each row
  execute function public.guard_prompt_template_fields();

create or replace function public.increment_prompt_template_usage(
  p_template_id uuid
)
returns public.prompt_templates
language plpgsql
security definer
set search_path = public, auth, pg_catalog, pg_temp
as $fn$
declare
  v_raw_claims text := nullif(current_setting('request.jwt.claims', true), '');
  v_claims jsonb;
  v_jwt_role text;
  v_is_service boolean;
  v_uid uuid := auth.uid();
  v_updated public.prompt_templates;
begin
  if v_raw_claims is not null then
    begin
      v_claims := v_raw_claims::jsonb;
    exception
      when others then
        v_claims := null;
    end;
  end if;

  v_jwt_role := coalesce(
    nullif(auth.jwt() ->> 'role', ''),
    nullif(v_claims ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );
  v_is_service := (v_jwt_role = 'service_role')
    or (
      v_jwt_role = ''
      and session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
    );

  if not v_is_service and v_uid is null then
    raise exception 'Authentication required to record prompt template usage'
      using errcode = '42501';
  end if;

  if p_template_id is null then
    raise exception 'Template id is required'
      using errcode = '22023';
  end if;

  begin
    perform set_config('app.prompt_template_usage_rpc', 'on', true);
    update public.prompt_templates
      set usage_count = usage_count + 1,
          updated_at = timezone('utc', now())
      where id = p_template_id
        and (v_is_service or user_id = v_uid or is_shared = true)
      returning * into v_updated;
    perform set_config('app.prompt_template_usage_rpc', '', true);
  exception
    when others then
      perform set_config('app.prompt_template_usage_rpc', '', true);
      raise;
  end;

  if not found then
    raise exception 'Prompt template not found or not accessible'
      using errcode = '42501';
  end if;

  return v_updated;
end;
$fn$;

revoke all on function public.increment_prompt_template_usage(uuid) from public, anon;
grant execute on function public.increment_prompt_template_usage(uuid) to authenticated, service_role;

comment on table public.prompt_templates is
  'Reusable 5-element structured prompt templates (role, context, deliverable, constraints, thinking) with team sharing (#2665).';
