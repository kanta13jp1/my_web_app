-- Enforce the same avatar restrictions as the Flutter upload client.
-- The existing public/private access mode and RLS policies are preserved.
update storage.buckets
set file_size_limit = 5242880,
    allowed_mime_types = array[
      'image/png',
      'image/jpeg',
      'image/webp',
      'image/gif'
    ]::text[]
where id = 'avatars';
