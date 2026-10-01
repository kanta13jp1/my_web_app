begin;

create table public.palm_readings (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  hand_side text not null,
  image_path text not null,
  image_mime_type text not null,
  analysis jsonb not null,
  comparison jsonb not null default '{}'::jsonb,
  provider text not null,
  model text not null,
  schema_version smallint not null default 1,
  quality_score smallint not null,
  created_at timestamptz not null default now(),
  constraint palm_readings_user_request_unique unique (user_id, request_id),
  constraint palm_readings_hand_side_valid
    check (hand_side in ('left', 'right')),
  constraint palm_readings_image_path_length
    check (length(btrim(image_path)) between 3 and 512),
  constraint palm_readings_image_path_owned
    check (image_path like user_id::text || '/%'),
  constraint palm_readings_image_mime_type_valid
    check (image_mime_type in ('image/jpeg', 'image/png', 'image/webp')),
  constraint palm_readings_analysis_object
    check (jsonb_typeof(analysis) = 'object'),
  constraint palm_readings_comparison_object
    check (jsonb_typeof(comparison) = 'object'),
  constraint palm_readings_provider_length
    check (length(btrim(provider)) between 1 and 80),
  constraint palm_readings_model_length
    check (length(btrim(model)) between 1 and 120),
  constraint palm_readings_schema_version_supported
    check (schema_version = 1),
  constraint palm_readings_quality_score_range
    check (quality_score between 0 and 100)
);

create index palm_readings_user_created_idx
  on public.palm_readings (user_id, created_at desc, id desc);

create index palm_readings_user_hand_created_idx
  on public.palm_readings (user_id, hand_side, created_at desc, id desc);

comment on table public.palm_readings is
  'Owner-scoped AI palmistry readings and structured comparisons. Entertainment use only.';
comment on column public.palm_readings.request_id is
  'Client-generated idempotency key that prevents duplicate AI readings on retry.';
comment on column public.palm_readings.image_path is
  'Private palm-readings Storage object path, always prefixed by the owner user id.';
comment on column public.palm_readings.analysis is
  'Versioned, normalized palmistry output. It must not contain medical or lifespan claims.';
comment on column public.palm_readings.comparison is
  'Comparison with the immediately preceding reading for the same hand, when available.';

alter table public.palm_readings enable row level security;

revoke all privileges on table public.palm_readings
from public, anon, authenticated;

grant all privileges on table public.palm_readings to service_role;
grant select on table public.palm_readings to authenticated;

create policy palm_readings_select_own
  on public.palm_readings
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'palm-readings',
  'palm-readings',
  false,
  4194304,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists palm_reading_images_select_own on storage.objects;
create policy palm_reading_images_select_own
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'palm-readings'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

insert into public.feature_releases (
  feature_route,
  feature_label,
  description,
  released_at,
  category
)
select
  '/palm-reading',
  '手相AI占い',
  '左右の手のひらをAIで鑑定し、履歴と同じ手の変化を振り返る',
  now(),
  'ai'
where not exists (
  select 1
  from public.feature_releases
  where feature_route = '/palm-reading'
);

commit;
