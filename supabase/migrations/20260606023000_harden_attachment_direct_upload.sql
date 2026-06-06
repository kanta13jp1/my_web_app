-- Issue #2602: keep note attachments on a frontend direct-upload path.
-- Uploads go directly to Supabase Storage under auth.uid()/... and metadata
-- is recorded in public.attachments by the authenticated client.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'attachments',
  'attachments',
  false,
  5242880,
  array['image/jpeg','image/jpg','image/png','image/gif','image/webp','application/pdf']::text[]
)
on conflict (id) do update
set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

alter table public.attachments enable row level security;

drop policy if exists "Users can view their own attachments" on public.attachments;
drop policy if exists "Users can insert their own attachments" on public.attachments;
drop policy if exists "Users can update their own attachments" on public.attachments;
drop policy if exists "Users can delete their own attachments" on public.attachments;

create policy "Users can view their own attachments"
  on public.attachments for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can insert their own attachments"
  on public.attachments for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can update their own attachments"
  on public.attachments for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete their own attachments"
  on public.attachments for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can upload their own files" on storage.objects;
drop policy if exists "Users can view their own files" on storage.objects;
drop policy if exists "Users can update their own files" on storage.objects;
drop policy if exists "Users can delete their own files" on storage.objects;

create policy "Users can upload their own files"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can view their own files"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can update their own files"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can delete their own files"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

comment on table public.attachments is
  'Owner-scoped metadata for files uploaded directly to Supabase Storage.';
