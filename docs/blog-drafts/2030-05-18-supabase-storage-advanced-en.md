---
title: "Supabase Storage Deep Dive — Bucket Design, Signed URLs, Image Transforms, and RLS"
tags: supabase,flutter,webdev,indiedev
published: true
---

# Supabase Storage Deep Dive — Bucket Design, Signed URLs, Image Transforms, and RLS

Supabase Storage is S3-compatible object storage that integrates directly with PostgreSQL Row Level Security. It's not just a file bucket — it handles access control, on-the-fly image transformations, and CDN delivery all in one place.

## Bucket Design

```sql
-- Public bucket: anyone can read via URL, no signature needed
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true);

-- Private bucket: requires a signed URL to read
INSERT INTO storage.buckets (id, name, public)
VALUES ('user-documents', 'user-documents', false);
```

**Rule of thumb**:
- Avatars, OG images → Public (maximize CDN cache efficiency)
- User uploads, invoices → Private (time-limited signed URLs)
- Admin-only data → Private + RLS that excludes all users

## RLS for Storage Objects

```sql
-- avatars: users upload/delete only their own; anyone reads (public bucket)
CREATE POLICY "User can upload own avatar"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'avatars'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "User can delete own avatar"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'avatars'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- user-documents: only the owner can do anything
CREATE POLICY "Users access own documents"
ON storage.objects
USING (
  bucket_id = 'user-documents'
  AND auth.uid()::text = (storage.foldername(name))[1]
)
WITH CHECK (
  bucket_id = 'user-documents'
  AND auth.uid()::text = (storage.foldername(name))[1]
);
```

`storage.foldername(name)[1]` extracts the first path segment from `{uid}/filename.pdf`.

## Uploading from Flutter

```dart
Future<String> uploadAvatar(Uint8List bytes, String userId) async {
  const path = '$userId/avatar.jpg';

  await Supabase.instance.client.storage
      .from('avatars')
      .uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );

  return Supabase.instance.client.storage
      .from('avatars')
      .getPublicUrl(path);
}
```

## Signed URLs for Private Buckets

```dart
// Single file — 1-hour expiry
Future<String> getSignedUrl(String userId, String filename) async {
  return Supabase.instance.client.storage
      .from('user-documents')
      .createSignedUrl('$userId/$filename', 3600);
}

// Batch signed URLs
Future<List<SignedUrl>> getBatchSignedUrls(
    String userId, List<String> filenames) async {
  final paths = filenames.map((f) => '$userId/$f').toList();
  return Supabase.instance.client.storage
      .from('user-documents')
      .createSignedUrls(paths, 3600);
}
```

Generate signed URLs server-side (Edge Function) so you never expose `service_role` to the client.

## Image Transformations

```dart
// Resize + convert to WebP on the CDN edge
String getAvatarUrl(String userId, {int size = 64}) {
  return Supabase.instance.client.storage
      .from('avatars')
      .getPublicUrl(
        '$userId/avatar.jpg',
        transform: TransformOptions(
          width: size,
          height: size,
          resize: ResizeMode.cover,
          format: RequestImageFormat.webp,
          quality: 80,
        ),
      );
}
```

Transformed images are cached at the CDN edge. Identical parameter combinations bypass the origin on subsequent requests.

## Atomic Upload + DB Insert via Edge Function

```typescript
Deno.serve(async (req) => {
  const { userId, filename, base64Data } = await req.json();
  const bytes = Uint8Array.from(atob(base64Data), c => c.charCodeAt(0));

  const { error: storageError } = await supabaseAdmin.storage
    .from('user-documents')
    .upload(`${userId}/${filename}`, bytes, {
      contentType: 'application/pdf',
      upsert: false,
    });

  if (storageError) {
    return new Response(JSON.stringify({ error: storageError.message }), {
      status: 400,
    });
  }

  const { error: dbError } = await supabaseAdmin
    .from('documents')
    .insert({ user_id: userId, filename, uploaded_at: new Date() });

  if (dbError) {
    // Rollback: remove the orphaned file
    await supabaseAdmin.storage
      .from('user-documents')
      .remove([`${userId}/${filename}`]);
    return new Response(JSON.stringify({ error: dbError.message }), {
      status: 500,
    });
  }

  return new Response(JSON.stringify({ success: true }));
});
```

## Validation

```dart
const maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

Future<void> validateAndUpload(XFile file) async {
  final bytes = await file.readAsBytes();

  if (bytes.length > maxFileSizeBytes) {
    throw Exception('File must be under 10 MB');
  }

  const allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];
  if (!allowedTypes.contains(file.mimeType)) {
    throw Exception('File type not allowed');
  }

  await uploadToStorage(bytes, file.name);
}
```

Client-side validation improves UX. **Server-side RLS + Edge Function validation is the trust boundary.**

## Usage Monitoring

```sql
SELECT
  bucket_id,
  count(*) AS file_count,
  pg_size_pretty(sum((metadata->>'size')::bigint)) AS total_size
FROM storage.objects
GROUP BY bucket_id
ORDER BY sum((metadata->>'size')::bigint) DESC;
```

## Summary

| Use Case | Bucket Type | URL Type | Transforms |
|----------|-------------|----------|------------|
| Avatars, public images | Public | Public URL | ✅ |
| User documents | Private | Signed URL (1h) | ❌ |
| Admin files | Private | Edge Function only | ❌ |

Supabase Storage shares the same RLS philosophy as the database — access control lives in SQL, not scattered across application code. That consistency is its biggest advantage over raw S3.
