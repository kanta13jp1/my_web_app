-- Issue #1255: private, temporary inputs for Writer PDF analysis.
-- The client can only access objects below its own auth.uid() folder. The
-- ai-hub service-role path removes each object after processing; the client
-- also performs best-effort cleanup for network/interruption recovery.

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'pdf-analysis-inputs',
  'pdf-analysis-inputs',
  false,
  20971520,
  array['application/pdf']::text[]
)
on conflict (id) do update
set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Users can upload their own PDF analysis inputs"
  on storage.objects;
drop policy if exists "Users can read their own PDF analysis inputs"
  on storage.objects;
drop policy if exists "Users can delete their own PDF analysis inputs"
  on storage.objects;

create policy "Users can upload their own PDF analysis inputs"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'pdf-analysis-inputs'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Users can read their own PDF analysis inputs"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'pdf-analysis-inputs'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Users can delete their own PDF analysis inputs"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'pdf-analysis-inputs'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
