-- The focused video contract uses a minimal shop_products fixture. Add the
-- production columns consumed by the publication migration without pulling in
-- unrelated historical commerce seed data.
alter table public.shop_products
  add column if not exists name_ja text,
  add column if not exists summary_ja text,
  add column if not exists price_jpy integer,
  add column if not exists stripe_price_id text,
  add column if not exists storage_bucket text not null default 'product-downloads',
  add column if not exists storage_path text,
  add column if not exists version text,
  add column if not exists file_size_bytes bigint,
  add column if not exists sha256 text,
  add column if not exists is_active boolean not null default false,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists product_type text not null default 'video',
  add column if not exists description_ja text,
  add column if not exists format_label text not null default 'MP4',
  add column if not exists requirements_ja text not null default 'MP4 playback required',
  add column if not exists license_summary_ja text not null default 'No redistribution',
  add column if not exists download_file_name text not null default 'video.mp4',
  add column if not exists preview_image_url text,
  add column if not exists sort_order integer not null default 100,
  add column if not exists published_at timestamptz;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'product-downloads',
  'product-downloads',
  false,
  524288000,
  array['video/mp4']
)
on conflict (id) do nothing;
