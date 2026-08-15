-- Keep Hedra-generated share videos available after Hedra signed URLs expire.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'viral-ad-videos',
  'viral-ad-videos',
  true,
  104857600,
  array['video/mp4', 'video/webm', 'video/quicktime', 'application/octet-stream']
)
on conflict (id) do update
set
  public = true,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

alter table public.viral_ad_generations
  add column if not exists video_audio_provider text,
  add column if not exists video_audio_reason text,
  add column if not exists video_audio_asset_id text,
  add column if not exists hedra_generation_id text,
  add column if not exists hedra_progress double precision,
  add column if not exists hedra_eta_sec double precision,
  add column if not exists stored_video_url text,
  add column if not exists stored_video_path text,
  add column if not exists stored_video_mime_type text,
  add column if not exists stored_video_size_bytes bigint,
  add column if not exists video_storage_error text;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Public can view viral ad videos'
  ) then
    create policy "Public can view viral ad videos"
      on storage.objects
      for select
      using (bucket_id = 'viral-ad-videos');
  end if;
end $$;
