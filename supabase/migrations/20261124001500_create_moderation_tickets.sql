-- Migration for Issue #2619: Content moderation standards and ticket workflow

create table if not exists public.moderation_tickets (
  id uuid primary key default gen_random_uuid(),
  reporter_user_id uuid not null references auth.users(id) on delete cascade,
  target_entity_type text not null
    check (char_length(trim(target_entity_type)) between 1 and 60),
  target_entity_id text not null
    check (char_length(trim(target_entity_id)) between 1 and 120),
  violation_category text not null
    check (
      violation_category in (
        'spam',
        'harassment',
        'privacy_violation',
        'misinformation',
        'illegal_content'
      )
    ),
  severity text not null
    check (severity in ('low', 'medium', 'high', 'urgent')),
  report_reason text not null
    check (char_length(trim(report_reason)) between 1 and 2000),
  evidence_reference text not null default '',
  ticket_status text not null default 'open'
    check (ticket_status in ('open', 'in_review', 'resolved', 'dismissed')),
  assigned_moderator_id uuid references auth.users(id) on delete set null,
  resolution_note text,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_moderation_tickets_reporter_created
  on public.moderation_tickets (reporter_user_id, created_at desc);

create index if not exists idx_moderation_tickets_status_severity
  on public.moderation_tickets (ticket_status, severity, created_at desc);

alter table public.moderation_tickets enable row level security;

drop policy if exists "moderation_tickets_select_own"
  on public.moderation_tickets;
create policy "moderation_tickets_select_own"
  on public.moderation_tickets
  for select
  using ((select auth.uid()) = reporter_user_id);

drop policy if exists "moderation_tickets_admin_select"
  on public.moderation_tickets;
create policy "moderation_tickets_admin_select"
  on public.moderation_tickets
  for select
  using (
    exists (
      select 1
      from public.user_profiles as up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  );

drop policy if exists "moderation_tickets_owner_insert"
  on public.moderation_tickets;
create policy "moderation_tickets_owner_insert"
  on public.moderation_tickets
  for insert
  with check (
    (select auth.uid()) = reporter_user_id
    and ticket_status = 'open'
    and assigned_moderator_id is null
    and resolution_note is null
    and resolved_at is null
  );

drop policy if exists "moderation_tickets_admin_update"
  on public.moderation_tickets;
create policy "moderation_tickets_admin_update"
  on public.moderation_tickets
  for update
  using (
    exists (
      select 1
      from public.user_profiles as up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  )
  with check (
    exists (
      select 1
      from public.user_profiles as up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  );

create or replace function public.guard_moderation_ticket_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $guard$
declare
  jwt_role text;
  caller_is_admin boolean;
begin
  jwt_role := coalesce(
    nullif(auth.jwt() ->> 'role', ''),
    nullif(auth.role(), ''),
    ''
  );

  if jwt_role = 'service_role'
     or (
       session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
       and jwt_role = ''
     ) then
    return new;
  end if;

  caller_is_admin := exists (
    select 1
    from public.user_profiles as up
    where up.user_id = auth.uid()
      and up.is_admin = true
  );

  if tg_op = 'INSERT' then
    if not caller_is_admin then
      if new.ticket_status is distinct from 'open'
         or new.assigned_moderator_id is not null
         or new.resolution_note is not null
         or new.resolved_at is not null then
        raise exception 'Non-admin reporters cannot pre-assign or self-resolve moderation tickets'
          using errcode = '42501';
      end if;
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if not caller_is_admin then
      raise exception 'Only authorized moderators may update moderation tickets'
        using errcode = '42501';
    end if;
    if new.id is distinct from old.id
       or new.reporter_user_id is distinct from old.reporter_user_id
       or new.target_entity_type is distinct from old.target_entity_type
       or new.target_entity_id is distinct from old.target_entity_id
       or new.violation_category is distinct from old.violation_category
       or new.report_reason is distinct from old.report_reason
       or new.evidence_reference is distinct from old.evidence_reference
       or new.created_at is distinct from old.created_at then
      raise exception 'Reporter submission fields are immutable during moderation review'
        using errcode = '42501';
    end if;
  end if;

  return new;
end;
$guard$;

drop trigger if exists guard_moderation_ticket_fields
  on public.moderation_tickets;
create trigger guard_moderation_ticket_fields
  before insert or update on public.moderation_tickets
  for each row
  execute function public.guard_moderation_ticket_fields();

comment on function public.guard_moderation_ticket_fields() is
  'Prevents non-admin self-resolution on insert and preserves immutable reporter fields on moderator updates.';
