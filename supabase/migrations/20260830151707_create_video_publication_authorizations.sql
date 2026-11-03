-- Machine-checkable publication packets for first-party GPU video artifacts.
-- The packet fixes the exact artifact/review, price, territory, licence and
-- rights assertions before Stripe or the public shop can be mutated.

create table public.video_publication_authorizations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  environment text not null default 'production' check (
    environment = 'production'
  ),
  status text not null default 'active' check (
    status in (
      'active', 'publishing', 'published', 'rolled_back', 'revoked', 'expired'
    )
  ),
  valid_from timestamptz not null default now(),
  valid_until timestamptz not null,
  artifact_id uuid not null references public.video_artifacts(id),
  review_id uuid not null references public.video_artifact_reviews(id),
  product_id text not null unique check (
    product_id ~ '^[a-z0-9][a-z0-9-]{2,79}$'
  ),
  title text not null check (char_length(btrim(title)) between 1 and 140),
  summary text not null check (char_length(btrim(summary)) between 1 and 500),
  description text not null check (
    char_length(btrim(description)) between 1 and 20000
  ),
  price_jpy integer not null check (price_jpy between 50 and 1000000),
  currency text not null default 'jpy' check (currency = 'jpy'),
  territory text not null default 'worldwide' check (
    territory = 'worldwide'
  ),
  license_summary text not null check (
    char_length(btrim(license_summary)) between 1 and 1000
  ),
  publication_channel text not null default '/shop' check (
    publication_channel = '/shop'
  ),
  rollback_action text not null default 'deactivate_listing' check (
    rollback_action = 'deactivate_listing'
  ),
  rights_confirmed boolean not null check (rights_confirmed),
  privacy_confirmed boolean not null check (privacy_confirmed),
  fictional_person_confirmed boolean not null check (
    fictional_person_confirmed
  ),
  no_third_party_logos_confirmed boolean not null check (
    no_third_party_logos_confirmed
  ),
  no_unlicensed_material_confirmed boolean not null check (
    no_unlicensed_material_confirmed
  ),
  stripe_product_id text,
  stripe_price_id text,
  delivery_storage_bucket text check (
    delivery_storage_bucket is null or delivery_storage_bucket = 'product-downloads'
  ),
  delivery_storage_path text,
  delivery_file_size_bytes bigint check (
    delivery_file_size_bytes is null or
    delivery_file_size_bytes between 1 and 52428800
  ),
  delivery_sha256 text check (
    delivery_sha256 is null or delivery_sha256 ~ '^[0-9a-f]{64}$'
  ),
  attempt_count integer not null default 0 check (attempt_count between 0 and 100),
  lease_expires_at timestamptz,
  last_error_code text check (
    last_error_code is null or last_error_code ~ '^[a-z0-9_]{1,120}$'
  ),
  published_at timestamptz,
  rolled_back_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (valid_until > valid_from),
  check (
    (status = 'publishing' and lease_expires_at is not null) or
    (status <> 'publishing' and lease_expires_at is null)
  ),
  check (
    (status = 'published' and published_at is not null) or
    (status <> 'published' and published_at is null)
  ),
  check (
    (status = 'rolled_back' and rolled_back_at is not null) or
    (status <> 'rolled_back' and rolled_back_at is null)
  ),
  check (
    (status = 'revoked' and revoked_at is not null) or
    (status <> 'revoked' and revoked_at is null)
  )
);

create index video_publication_authorizations_user_created_idx
  on public.video_publication_authorizations (user_id, created_at desc);
create index video_publication_authorizations_queue_idx
  on public.video_publication_authorizations (status, valid_until, created_at)
  where status in ('active', 'publishing');
create unique index video_publication_authorizations_artifact_active_uidx
  on public.video_publication_authorizations (artifact_id)
  where status in ('active', 'publishing', 'published');

alter table public.video_publication_authorizations enable row level security;

create policy "video publication authorizations select own"
  on public.video_publication_authorizations
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

revoke all on table public.video_publication_authorizations
  from anon, authenticated;
grant select on table public.video_publication_authorizations
  to authenticated;
grant all on table public.video_publication_authorizations
  to service_role;

create or replace function public.video_publication_touch_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger video_publication_authorizations_touch_updated_at
  before update on public.video_publication_authorizations
  for each row execute function public.video_publication_touch_updated_at();

create or replace function public.video_publication_keep_packet_immutable()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.user_id is distinct from old.user_id
    or new.environment is distinct from old.environment
    or new.valid_from is distinct from old.valid_from
    or new.valid_until is distinct from old.valid_until
    or new.artifact_id is distinct from old.artifact_id
    or new.review_id is distinct from old.review_id
    or new.product_id is distinct from old.product_id
    or new.title is distinct from old.title
    or new.summary is distinct from old.summary
    or new.description is distinct from old.description
    or new.price_jpy is distinct from old.price_jpy
    or new.currency is distinct from old.currency
    or new.territory is distinct from old.territory
    or new.license_summary is distinct from old.license_summary
    or new.publication_channel is distinct from old.publication_channel
    or new.rollback_action is distinct from old.rollback_action
    or new.rights_confirmed is distinct from old.rights_confirmed
    or new.privacy_confirmed is distinct from old.privacy_confirmed
    or new.fictional_person_confirmed is distinct from old.fictional_person_confirmed
    or new.no_third_party_logos_confirmed is distinct from old.no_third_party_logos_confirmed
    or new.no_unlicensed_material_confirmed is distinct from old.no_unlicensed_material_confirmed
    or new.created_at is distinct from old.created_at
  then
    raise exception 'video_publication_packet_is_immutable'
      using errcode = '22023';
  end if;
  return new;
end;
$$;

create trigger video_publication_authorizations_keep_packet_immutable
  before update on public.video_publication_authorizations
  for each row execute function public.video_publication_keep_packet_immutable();

alter table public.video_artifact_events
  drop constraint if exists video_artifact_events_event_type_check;
alter table public.video_artifact_events
  add constraint video_artifact_events_event_type_check check (
    event_type in (
      'captured',
      'reviewed',
      'improvement_applied',
      'product_draft_linked',
      'publication_authorized',
      'publication_started',
      'published',
      'publication_rolled_back',
      'retired'
    )
  );

create or replace function public.video_register_publication_authorization(
  p_user_id uuid,
  p_artifact_id uuid,
  p_review_id uuid,
  p_valid_until timestamptz,
  p_product_id text,
  p_title text,
  p_summary text,
  p_description text,
  p_price_jpy integer,
  p_license_summary text,
  p_rights_confirmed boolean,
  p_privacy_confirmed boolean,
  p_fictional_person_confirmed boolean,
  p_no_third_party_logos_confirmed boolean,
  p_no_unlicensed_material_confirmed boolean
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_artifact public.video_artifacts%rowtype;
  v_review public.video_artifact_reviews%rowtype;
  v_existing public.video_publication_authorizations%rowtype;
  v_authorization public.video_publication_authorizations%rowtype;
begin
  if p_user_id is null then
    raise exception 'user_id_required' using errcode = '22023';
  end if;
  if p_valid_until < now() + interval '10 minutes'
    or p_valid_until > now() + interval '30 days' then
    raise exception 'invalid_publication_authorization_expiry'
      using errcode = '22023';
  end if;
  if trim(coalesce(p_product_id, '')) !~ '^[a-z0-9][a-z0-9-]{2,79}$'
    or char_length(trim(coalesce(p_title, ''))) not between 1 and 140
    or char_length(trim(coalesce(p_summary, ''))) not between 1 and 500
    or char_length(trim(coalesce(p_description, ''))) not between 1 and 20000
    or p_price_jpy not between 50 and 1000000
    or char_length(trim(coalesce(p_license_summary, ''))) not between 1 and 1000
  then
    raise exception 'invalid_video_publication_packet' using errcode = '22023';
  end if;
  if not coalesce(p_rights_confirmed, false)
    or not coalesce(p_privacy_confirmed, false)
    or not coalesce(p_fictional_person_confirmed, false)
    or not coalesce(p_no_third_party_logos_confirmed, false)
    or not coalesce(p_no_unlicensed_material_confirmed, false)
  then
    raise exception 'publication_confirmations_required'
      using errcode = '22023';
  end if;

  select * into v_artifact
  from public.video_artifacts
  where id = p_artifact_id and user_id = p_user_id
  for update;
  if not found then
    raise exception 'video_artifact_not_found' using errcode = 'P0002';
  end if;
  if v_artifact.latest_review_id is distinct from p_review_id then
    raise exception 'publication_review_is_not_latest' using errcode = 'P0001';
  end if;
  if v_artifact.rights_status <> 'allowed'
    or v_artifact.privacy_status <> 'cleared'
    or not v_artifact.intended_for_sale
    or v_artifact.commerce_status in ('not_for_sale', 'blocked') then
    raise exception 'artifact_not_cleared_for_publication'
      using errcode = 'P0001';
  end if;

  select * into v_review
  from public.video_artifact_reviews
  where id = p_review_id
    and artifact_id = p_artifact_id
    and user_id = p_user_id;
  if not found then
    raise exception 'video_artifact_review_not_found' using errcode = 'P0002';
  end if;
  if v_review.decision <> 'keep' then
    raise exception 'publication_review_must_be_keep' using errcode = 'P0001';
  end if;

  select * into v_existing
  from public.video_publication_authorizations
  where product_id = trim(p_product_id);
  if found then
    if v_existing.user_id = p_user_id
      and v_existing.artifact_id = p_artifact_id
      and v_existing.review_id = p_review_id
      and v_existing.title = trim(p_title)
      and v_existing.summary = trim(p_summary)
      and v_existing.description = trim(p_description)
      and v_existing.price_jpy = p_price_jpy
      and v_existing.license_summary = trim(p_license_summary) then
      return jsonb_build_object(
        'authorization', to_jsonb(v_existing),
        'idempotent_replay', true
      );
    end if;
    raise exception 'publication_product_id_conflict' using errcode = '23505';
  end if;

  insert into public.video_publication_authorizations (
    user_id,
    valid_until,
    artifact_id,
    review_id,
    product_id,
    title,
    summary,
    description,
    price_jpy,
    license_summary,
    rights_confirmed,
    privacy_confirmed,
    fictional_person_confirmed,
    no_third_party_logos_confirmed,
    no_unlicensed_material_confirmed
  ) values (
    p_user_id,
    p_valid_until,
    p_artifact_id,
    p_review_id,
    trim(p_product_id),
    trim(p_title),
    trim(p_summary),
    trim(p_description),
    p_price_jpy,
    trim(p_license_summary),
    p_rights_confirmed,
    p_privacy_confirmed,
    p_fictional_person_confirmed,
    p_no_third_party_logos_confirmed,
    p_no_unlicensed_material_confirmed
  ) returning * into v_authorization;

  insert into public.video_artifact_events (
    user_id, artifact_id, review_id, event_type, metadata
  ) values (
    p_user_id,
    p_artifact_id,
    p_review_id,
    'publication_authorized',
    jsonb_build_object(
      'authorization_id', v_authorization.id,
      'product_id', v_authorization.product_id,
      'price_jpy', v_authorization.price_jpy
    )
  );

  return jsonb_build_object(
    'authorization', to_jsonb(v_authorization),
    'idempotent_replay', false
  );
end;
$$;

create or replace function public.video_claim_publication_authorization(
  p_user_id uuid,
  p_authorization_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_authorization public.video_publication_authorizations%rowtype;
begin
  select * into v_authorization
  from public.video_publication_authorizations
  where id = p_authorization_id and user_id = p_user_id
  for update;
  if not found then
    raise exception 'video_publication_authorization_not_found'
      using errcode = 'P0002';
  end if;
  if v_authorization.status = 'published' then
    return jsonb_build_object(
      'authorization', to_jsonb(v_authorization),
      'idempotent_replay', true
    );
  end if;
  if v_authorization.valid_until <= now() then
    update public.video_publication_authorizations
    set status = 'expired', lease_expires_at = null
    where id = v_authorization.id
    returning * into v_authorization;
    return jsonb_build_object(
      'authorization', to_jsonb(v_authorization),
      'idempotent_replay', false
    );
  end if;
  if v_authorization.status = 'publishing'
    and v_authorization.lease_expires_at > now() then
    raise exception 'video_publication_already_in_progress'
      using errcode = 'P0001';
  end if;
  if v_authorization.status not in ('active', 'publishing') then
    raise exception 'video_publication_authorization_inactive'
      using errcode = 'P0001';
  end if;

  update public.video_publication_authorizations
  set status = 'publishing',
      lease_expires_at = now() + interval '10 minutes',
      attempt_count = attempt_count + 1,
      last_error_code = null
  where id = v_authorization.id
  returning * into v_authorization;

  insert into public.video_artifact_events (
    user_id, artifact_id, review_id, event_type, metadata
  ) values (
    p_user_id,
    v_authorization.artifact_id,
    v_authorization.review_id,
    'publication_started',
    jsonb_build_object(
      'authorization_id', v_authorization.id,
      'attempt', v_authorization.attempt_count
    )
  );

  return jsonb_build_object(
    'authorization', to_jsonb(v_authorization),
    'idempotent_replay', false
  );
end;
$$;

create or replace function public.video_stage_publication_product(
  p_user_id uuid,
  p_authorization_id uuid,
  p_stripe_product_id text,
  p_stripe_price_id text,
  p_storage_path text,
  p_file_size_bytes bigint,
  p_sha256 text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_authorization public.video_publication_authorizations%rowtype;
  v_product public.shop_products%rowtype;
begin
  select * into v_authorization
  from public.video_publication_authorizations
  where id = p_authorization_id and user_id = p_user_id
  for update;
  if not found then
    raise exception 'video_publication_authorization_not_found'
      using errcode = 'P0002';
  end if;
  if v_authorization.status = 'published' then
    return to_jsonb(v_authorization);
  end if;
  if v_authorization.status <> 'publishing'
    or v_authorization.lease_expires_at <= now() then
    raise exception 'video_publication_lease_required' using errcode = 'P0001';
  end if;
  if trim(coalesce(p_stripe_product_id, '')) !~ '^prod_[A-Za-z0-9]+$'
    or trim(coalesce(p_stripe_price_id, '')) !~ '^price_[A-Za-z0-9]+$'
    or trim(coalesce(p_storage_path, '')) = ''
    or p_file_size_bytes not between 1 and 52428800
    or trim(coalesce(p_sha256, '')) !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid_video_publication_external_state'
      using errcode = '22023';
  end if;
  if (v_authorization.stripe_product_id is not null
      and v_authorization.stripe_product_id <> trim(p_stripe_product_id))
    or (v_authorization.stripe_price_id is not null
      and v_authorization.stripe_price_id <> trim(p_stripe_price_id))
    or (v_authorization.delivery_storage_path is not null
      and v_authorization.delivery_storage_path <> trim(p_storage_path))
    or (v_authorization.delivery_file_size_bytes is not null
      and v_authorization.delivery_file_size_bytes <> p_file_size_bytes)
    or (v_authorization.delivery_sha256 is not null
      and v_authorization.delivery_sha256 <> trim(p_sha256)) then
    raise exception 'video_publication_external_state_conflict'
      using errcode = '23505';
  end if;

  select * into v_product
  from public.shop_products
  where id = v_authorization.product_id
  for update;
  if found and (
    v_product.is_active
    or v_product.price_jpy is distinct from v_authorization.price_jpy
    or v_product.storage_bucket is distinct from 'product-downloads'
    or v_product.storage_path is distinct from trim(p_storage_path)
    or v_product.stripe_price_id is distinct from trim(p_stripe_price_id)
  ) then
    raise exception 'publication_product_conflict' using errcode = '23505';
  end if;

  insert into public.shop_products (
    id,
    name_ja,
    summary_ja,
    description_ja,
    price_jpy,
    stripe_price_id,
    storage_bucket,
    storage_path,
    version,
    file_size_bytes,
    sha256,
    is_active,
    product_type,
    format_label,
    requirements_ja,
    license_summary_ja,
    download_file_name,
    sort_order
  ) values (
    v_authorization.product_id,
    v_authorization.title,
    v_authorization.summary,
    v_authorization.description,
    v_authorization.price_jpy,
    trim(p_stripe_price_id),
    'product-downloads',
    trim(p_storage_path),
    '1.0',
    p_file_size_bytes,
    trim(p_sha256),
    false,
    'video',
    'MP4 / 720p',
    'MP4動画を再生・編集できる環境',
    v_authorization.license_summary,
    v_authorization.product_id || '.mp4',
    100
  )
  on conflict (id) do update set
    name_ja = excluded.name_ja,
    summary_ja = excluded.summary_ja,
    description_ja = excluded.description_ja,
    stripe_price_id = excluded.stripe_price_id,
    file_size_bytes = excluded.file_size_bytes,
    sha256 = excluded.sha256,
    license_summary_ja = excluded.license_summary_ja,
    download_file_name = excluded.download_file_name,
    is_active = false;

  update public.video_publication_authorizations
  set stripe_product_id = trim(p_stripe_product_id),
      stripe_price_id = trim(p_stripe_price_id),
      delivery_storage_bucket = 'product-downloads',
      delivery_storage_path = trim(p_storage_path),
      delivery_file_size_bytes = p_file_size_bytes,
      delivery_sha256 = trim(p_sha256)
  where id = v_authorization.id
  returning * into v_authorization;

  return to_jsonb(v_authorization);
end;
$$;

create or replace function public.video_finalize_publication(
  p_user_id uuid,
  p_authorization_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_authorization public.video_publication_authorizations%rowtype;
  v_product public.shop_products%rowtype;
begin
  select * into v_authorization
  from public.video_publication_authorizations
  where id = p_authorization_id and user_id = p_user_id
  for update;
  if not found then
    raise exception 'video_publication_authorization_not_found'
      using errcode = 'P0002';
  end if;
  if v_authorization.status = 'published' then
    return to_jsonb(v_authorization);
  end if;
  if v_authorization.status <> 'publishing'
    or v_authorization.lease_expires_at <= now()
    or v_authorization.stripe_product_id is null
    or v_authorization.stripe_price_id is null
    or v_authorization.delivery_storage_path is null
    or v_authorization.delivery_file_size_bytes is null
    or v_authorization.delivery_sha256 is null then
    raise exception 'video_publication_not_ready' using errcode = 'P0001';
  end if;

  select * into v_product
  from public.shop_products
  where id = v_authorization.product_id
  for update;
  if not found
    or v_product.is_active
    or v_product.price_jpy <> v_authorization.price_jpy
    or v_product.stripe_price_id <> v_authorization.stripe_price_id
    or v_product.storage_bucket <> v_authorization.delivery_storage_bucket
    or v_product.storage_path <> v_authorization.delivery_storage_path
    or v_product.file_size_bytes <> v_authorization.delivery_file_size_bytes
    or v_product.sha256 <> v_authorization.delivery_sha256 then
    raise exception 'video_publication_product_not_verified'
      using errcode = 'P0001';
  end if;

  update public.shop_products
  set is_active = true,
      published_at = coalesce(published_at, now())
  where id = v_authorization.product_id;

  update public.video_artifacts
  set lifecycle_stage = 'release_candidate',
      commerce_status = 'listed',
      shop_product_id = v_authorization.product_id
  where id = v_authorization.artifact_id
    and user_id = p_user_id;

  update public.video_publication_authorizations
  set status = 'published',
      lease_expires_at = null,
      published_at = now(),
      last_error_code = null
  where id = v_authorization.id
  returning * into v_authorization;

  insert into public.video_artifact_events (
    user_id, artifact_id, review_id, event_type, metadata
  ) values (
    p_user_id,
    v_authorization.artifact_id,
    v_authorization.review_id,
    'published',
    jsonb_build_object(
      'authorization_id', v_authorization.id,
      'product_id', v_authorization.product_id,
      'stripe_price_id', v_authorization.stripe_price_id
    )
  );
  return to_jsonb(v_authorization);
end;
$$;

create or replace function public.video_release_publication_authorization(
  p_user_id uuid,
  p_authorization_id uuid,
  p_error_code text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_authorization public.video_publication_authorizations%rowtype;
begin
  if trim(coalesce(p_error_code, '')) !~ '^[a-z0-9_]{1,120}$' then
    raise exception 'invalid_publication_error_code' using errcode = '22023';
  end if;
  update public.video_publication_authorizations
  set status = case when valid_until <= now() then 'expired' else 'active' end,
      lease_expires_at = null,
      last_error_code = trim(p_error_code)
  where id = p_authorization_id
    and user_id = p_user_id
    and status = 'publishing'
  returning * into v_authorization;
  if not found then
    raise exception 'video_publication_authorization_not_releasable'
      using errcode = 'P0001';
  end if;
  return to_jsonb(v_authorization);
end;
$$;

create or replace function public.video_rollback_publication(
  p_user_id uuid,
  p_authorization_id uuid,
  p_error_code text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_authorization public.video_publication_authorizations%rowtype;
begin
  if trim(coalesce(p_error_code, '')) !~ '^[a-z0-9_]{1,120}$' then
    raise exception 'invalid_publication_error_code' using errcode = '22023';
  end if;
  select * into v_authorization
  from public.video_publication_authorizations
  where id = p_authorization_id and user_id = p_user_id
  for update;
  if not found then
    raise exception 'video_publication_authorization_not_found'
      using errcode = 'P0002';
  end if;
  if v_authorization.status = 'rolled_back' then
    return to_jsonb(v_authorization);
  end if;

  update public.shop_products
  set is_active = false
  where id = v_authorization.product_id;
  update public.video_artifacts
  set lifecycle_stage = 'productizing',
      commerce_status = 'draft_product',
      shop_product_id = v_authorization.product_id
  where id = v_authorization.artifact_id and user_id = p_user_id;
  update public.video_publication_authorizations
  set status = 'rolled_back',
      lease_expires_at = null,
      published_at = null,
      rolled_back_at = now(),
      last_error_code = trim(p_error_code)
  where id = v_authorization.id
  returning * into v_authorization;

  insert into public.video_artifact_events (
    user_id, artifact_id, review_id, event_type, metadata
  ) values (
    p_user_id,
    v_authorization.artifact_id,
    v_authorization.review_id,
    'publication_rolled_back',
    jsonb_build_object(
      'authorization_id', v_authorization.id,
      'product_id', v_authorization.product_id,
      'error_code', trim(p_error_code)
    )
  );
  return to_jsonb(v_authorization);
end;
$$;

revoke all on function public.video_publication_touch_updated_at()
  from public, anon, authenticated;
revoke all on function public.video_publication_keep_packet_immutable()
  from public, anon, authenticated;
revoke all on function public.video_register_publication_authorization(
  uuid, uuid, uuid, timestamptz, text, text, text, text, integer, text,
  boolean, boolean, boolean, boolean, boolean
) from public, anon, authenticated;
revoke all on function public.video_claim_publication_authorization(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.video_stage_publication_product(
  uuid, uuid, text, text, text, bigint, text
) from public, anon, authenticated;
revoke all on function public.video_finalize_publication(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.video_release_publication_authorization(
  uuid, uuid, text
) from public, anon, authenticated;
revoke all on function public.video_rollback_publication(uuid, uuid, text)
  from public, anon, authenticated;

grant execute on function public.video_register_publication_authorization(
  uuid, uuid, uuid, timestamptz, text, text, text, text, integer, text,
  boolean, boolean, boolean, boolean, boolean
) to service_role;
grant execute on function public.video_claim_publication_authorization(uuid, uuid)
  to service_role;
grant execute on function public.video_stage_publication_product(
  uuid, uuid, text, text, text, bigint, text
) to service_role;
grant execute on function public.video_finalize_publication(uuid, uuid)
  to service_role;
grant execute on function public.video_release_publication_authorization(
  uuid, uuid, text
) to service_role;
grant execute on function public.video_rollback_publication(uuid, uuid, text)
  to service_role;

comment on table public.video_publication_authorizations is
  'Immutable owner-approved packets and operational state for first-party video shop publication.';
