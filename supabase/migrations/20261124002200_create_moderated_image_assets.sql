-- Migration for Issue #2644: ViT-assisted image moderation, auto-tagging, and tag search

create table if not exists public.moderated_image_assets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  storage_bucket text not null
    check (char_length(trim(storage_bucket)) between 1 and 80),
  storage_path text not null
    check (char_length(trim(storage_path)) between 1 and 300),
  tags text[] not null default '{}'::text[],
  safety_score numeric(5,4) not null default 1.0000
    check (safety_score >= 0 and safety_score <= 1),
  moderation_status text not null default 'pending'
    check (moderation_status in ('pending', 'approved', 'flagged', 'hidden')),
  is_hidden boolean not null default false,
  external_transfer_consented boolean not null default false,
  reviewed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_moderated_image_assets_user_created
  on public.moderated_image_assets (user_id, created_at desc);

create index if not exists idx_moderated_image_assets_status_hidden
  on public.moderated_image_assets (moderation_status, is_hidden, created_at desc);

create index if not exists idx_moderated_image_assets_tags_gin
  on public.moderated_image_assets using gin (tags);

alter table public.moderated_image_assets enable row level security;

revoke all on table public.moderated_image_assets from public, anon;
grant select, insert, update, delete on table public.moderated_image_assets to authenticated;
grant all on table public.moderated_image_assets to service_role;

drop policy if exists "moderated_image_assets_select_own_or_admin"
  on public.moderated_image_assets;
create policy "moderated_image_assets_select_own_or_admin"
  on public.moderated_image_assets
  for select
  to authenticated
  using (
    auth.uid() = user_id
    or exists (
      select 1
      from public.user_profiles as up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  );

drop policy if exists "moderated_image_assets_insert_own"
  on public.moderated_image_assets;
create policy "moderated_image_assets_insert_own"
  on public.moderated_image_assets
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "moderated_image_assets_update_own_or_admin"
  on public.moderated_image_assets;
create policy "moderated_image_assets_update_own_or_admin"
  on public.moderated_image_assets
  for update
  to authenticated
  using (
    auth.uid() = user_id
    or exists (
      select 1
      from public.user_profiles as up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  )
  with check (
    auth.uid() = user_id
    or exists (
      select 1
      from public.user_profiles as up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  );

drop policy if exists "moderated_image_assets_delete_own_or_admin"
  on public.moderated_image_assets;
create policy "moderated_image_assets_delete_own_or_admin"
  on public.moderated_image_assets
  for delete
  to authenticated
  using (
    auth.uid() = user_id
    or exists (
      select 1
      from public.user_profiles as up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  );

create or replace function public.guard_moderated_image_asset_fields()
returns trigger
language plpgsql
security invoker
set search_path = public
as $guard$
declare
  jwt_role text;
  caller_is_admin boolean;
begin
  jwt_role := coalesce(
    nullif(auth.jwt() ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );

  if jwt_role = 'service_role'
     or (
       session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
       and jwt_role = ''
     ) then
    if new.safety_score < 0.5000 then
      new.is_hidden := true;
      if new.moderation_status not in ('flagged', 'hidden') then
        new.moderation_status := 'hidden';
      end if;
    end if;
    if tg_op = 'INSERT' then
      new.created_at := coalesce(new.created_at, timezone('utc', now()));
    end if;
    new.updated_at := timezone('utc', now());
    return new;
  end if;

  caller_is_admin := exists (
    select 1
    from public.user_profiles as up
    where up.user_id = auth.uid()
      and up.is_admin = true
  );

  if tg_op = 'INSERT' then
    if auth.uid() is null or new.user_id is distinct from auth.uid() then
      raise exception 'Authenticated owner user_id is required on insert'
        using errcode = '42501';
    end if;
    if new.moderation_status is distinct from 'pending'
       or new.is_hidden is distinct from false
       or new.reviewed_by is not null then
      raise exception 'New uploaded image assets must start pending with reviewed_by null and is_hidden false'
        using errcode = '42501';
    end if;
    if new.safety_score < 0.5000 then
      new.is_hidden := true;
      new.moderation_status := 'hidden';
    end if;
    new.created_at := timezone('utc', now());
    new.updated_at := timezone('utc', now());
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if new.id is distinct from old.id
       or new.user_id is distinct from old.user_id
       or new.created_at is distinct from old.created_at then
      raise exception 'Immutable identity and timestamp fields cannot be modified'
        using errcode = '42501';
    end if;
    if not caller_is_admin then
      if old.user_id is distinct from auth.uid() then
        raise exception 'Only owner or admin may update image asset'
          using errcode = '42501';
      end if;
      if new.reviewed_by is distinct from old.reviewed_by then
        raise exception 'Only admins may set or change reviewed_by'
          using errcode = '42501';
      end if;
      if (
        old.moderation_status in ('flagged', 'hidden')
        or old.is_hidden = true
      ) and (
        new.moderation_status is distinct from old.moderation_status
        or new.is_hidden is distinct from old.is_hidden
        or new.safety_score is distinct from old.safety_score
      ) then
        raise exception 'Flagged or hidden image moderation fields cannot be reset by non-admins'
          using errcode = '42501';
      end if;
      if new.moderation_status = 'approved'
         and old.moderation_status is distinct from 'approved' then
        raise exception 'Non-admins cannot self-approve uploaded images'
          using errcode = '42501';
      end if;
    end if;
    if new.safety_score < 0.5000 then
      new.is_hidden := true;
      if new.moderation_status not in ('flagged', 'hidden') then
        new.moderation_status := 'hidden';
      end if;
    end if;
    new.updated_at := timezone('utc', now());
  end if;

  return new;
end;
$guard$;

drop trigger if exists guard_moderated_image_asset_fields
  on public.moderated_image_assets;
create trigger guard_moderated_image_asset_fields
  before insert or update on public.moderated_image_assets
  for each row
  execute function public.guard_moderated_image_asset_fields();

comment on table public.moderated_image_assets is
  'Stores ViT-assisted moderation results, auto-tags, explicit external transfer consent, and auto-hide flags for uploaded images (#2644).';
