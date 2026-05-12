---
title: "Supabase Storage Guide — File Uploads, CDN Delivery, and Storage RLS"
tags: supabase,webdev,indiedev,flutter
published: true
---

# Supabase Storage Guide — File Uploads, CDN Delivery, and Storage RLS

Supabase Storage gives you S3-compatible object storage, a global CDN, and Row Level Security (RLS) policies — all managed through the same Supabase client your Flutter app already uses. In this guide we'll cover bucket setup, Flutter upload code, RLS policy design, signed URLs, image transforms, and CDN cache tuning.

## Creating Buckets

Create buckets via the Supabase dashboard or SQL:

```sql
-- Public bucket — files accessible by URL without auth
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true);

-- Private bucket — requires signed URLs or auth
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'documents',
  'documents',
  false,
  52428800,            -- 50 MB max file size
  ARRAY['application/pdf', 'image/jpeg', 'image/png', 'image/webp']
);
```

Use `public = true` for assets you want cached on the CDN without auth (avatars, OG images). Use `public = false` for anything user-private (documents, invoices, drafts).

## Uploading Files from Flutter

```dart
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final _client = Supabase.instance.client;

  /// Pick an image and upload as the current user's avatar
  Future<String?> uploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (picked == null) return null;

    final userId = _client.auth.currentUser!.id;
    final ext = picked.path.split('.').last.toLowerCase();
    final storagePath = 'public/$userId/avatar.$ext';

    await _client.storage.from('avatars').upload(
      storagePath,
      File(picked.path),
      fileOptions: const FileOptions(
        cacheControl: '3600',
        upsert: true,           // overwrite existing avatar
        contentType: 'image/jpeg',
      ),
    );

    // Return the CDN URL for immediate display
    return _client.storage.from('avatars').getPublicUrl(storagePath);
  }

  /// Upload raw bytes — works on Flutter Web too
  Future<String> uploadBytes({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    await _client.storage.from(bucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mimeType, upsert: true),
    );
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  /// Batch-upload multiple files and return their paths
  Future<List<String>> uploadMultiple(List<XFile> files) async {
    final userId = _client.auth.currentUser!.id;
    final paths = <String>[];

    await Future.wait(files.map((file) async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = '$userId/${ts}_${file.name}';
      final bytes = await file.readAsBytes();

      await _client.storage.from('documents').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: file.mimeType ?? 'application/octet-stream',
        ),
      );
      paths.add(path);
    }));

    return paths;
  }
}
```

## Designing Storage RLS Policies

Storage RLS operates on the `storage.objects` table. The helper function `storage.foldername(name)` returns an array of path segments, letting you match against user IDs baked into the path.

```sql
-- Policy 1: Authenticated users manage their own avatar folder
CREATE POLICY "Users manage own avatars"
ON storage.objects
FOR ALL
TO authenticated
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = 'public'
  AND (storage.foldername(name))[2] = (auth.uid())::text
)
WITH CHECK (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = 'public'
  AND (storage.foldername(name))[2] = (auth.uid())::text
);

-- Policy 2: Anyone can read from the public avatars bucket
CREATE POLICY "Avatars are publicly readable"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'avatars');

-- Policy 3: Private documents accessible by owner only
CREATE POLICY "Documents owner only"
ON storage.objects
FOR ALL
TO authenticated
USING (
  bucket_id = 'documents'
  AND (storage.foldername(name))[1] = (auth.uid())::text
)
WITH CHECK (
  bucket_id = 'documents'
  AND (storage.foldername(name))[1] = (auth.uid())::text
);

-- Policy 4: Allow team members to access shared folders
CREATE POLICY "Team shared folder access"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'documents'
  AND EXISTS (
    SELECT 1 FROM public.team_members tm
    WHERE tm.user_id = auth.uid()
      AND tm.team_id = (storage.foldername(name))[1]::uuid
  )
);
```

## Signed URLs for Private Files

Generate time-limited URLs for private bucket objects without exposing the bucket:

```dart
class SignedUrlService {
  final _client = Supabase.instance.client;

  /// One-hour download link
  Future<String> getSignedUrl(String path, {int ttlSeconds = 3600}) {
    return _client.storage
        .from('documents')
        .createSignedUrl(path, ttlSeconds);
  }

  /// Batch-generate signed URLs efficiently
  Future<List<SignedUrl>> getSignedUrls(List<String> paths) {
    return _client.storage
        .from('documents')
        .createSignedUrls(paths, 3600);
  }

  /// Generate an upload URL — let clients upload directly to Storage
  /// without routing the bytes through your server
  Future<String> getSignedUploadUrl(String path) async {
    final result = await _client.storage
        .from('documents')
        .createSignedUploadUrl(path);
    return result.signedUrl;
  }
}
```

Using signed URLs in your Flutter UI:

```dart
class PrivateFileViewer extends StatelessWidget {
  const PrivateFileViewer({required this.filePath, super.key});
  final String filePath;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: SignedUrlService().getSignedUrl(filePath),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        return Image.network(snapshot.data!);
      },
    );
  }
}
```

## Image Transforms (Pro Plan)

Supabase Storage Pro supports on-the-fly image resizing and format conversion at the CDN edge — no extra infrastructure needed.

```dart
class ImageTransformService {
  final _client = Supabase.instance.client;

  /// 200×200 WebP thumbnail
  String thumbnail(String path) {
    return _client.storage.from('avatars').getPublicUrl(
      path,
      transform: const TransformOptions(
        width: 200,
        height: 200,
        resize: ResizeOption.cover,
        format: TransformFormat.webp,
        quality: 80,
      ),
    );
  }

  /// Responsive srcset map
  Map<String, String> responsiveSet(String path) {
    return {
      for (final entry in {'xs': 320, 'sm': 640, 'md': 960, 'lg': 1280}.entries)
        entry.key: _client.storage.from('images').getPublicUrl(
          path,
          transform: TransformOptions(
            width: entry.value,
            format: TransformFormat.webp,
            quality: 85,
          ),
        )
    };
  }
}

// Widget usage
class ResponsiveImage extends StatelessWidget {
  const ResponsiveImage({required this.path, super.key});
  final String path;

  @override
  Widget build(BuildContext context) {
    final ts = ImageTransformService();
    final width = MediaQuery.of(context).size.width;
    final url = width < 640 ? ts.thumbnail(path) : ts.responsiveSet(path)['md']!;

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
    );
  }
}
```

## CDN Cache Tuning

Set `Cache-Control` at upload time to control how long CDN edge nodes cache the file:

```dart
// Long-lived static assets (1 year)
await _client.storage.from('images').upload(
  path,
  file,
  fileOptions: const FileOptions(
    cacheControl: '31536000, immutable',
    upsert: false,
  ),
);

// User-generated content that might change (1 hour)
await _client.storage.from('avatars').upload(
  path,
  file,
  fileOptions: const FileOptions(
    cacheControl: '3600',
    upsert: true,
  ),
);

// Always-fresh (disable CDN cache)
await _client.storage.from('reports').upload(
  path,
  file,
  fileOptions: const FileOptions(
    cacheControl: 'no-cache, no-store',
    upsert: true,
  ),
);
```

## File Management Utilities

```dart
class FileManager {
  final _client = Supabase.instance.client;

  Future<List<FileObject>> listUserFiles() async {
    final userId = _client.auth.currentUser!.id;
    return _client.storage.from('documents').list(
      path: userId,
      searchOptions: const SearchOptions(
        limit: 100,
        sortBy: SortBy(column: 'created_at', order: 'desc'),
      ),
    );
  }

  Future<void> deleteFiles(List<String> paths) async {
    await _client.storage.from('documents').remove(paths);
  }

  Future<void> moveFile(String from, String to) async {
    await _client.storage.from('documents').move(from, to);
  }
}
```

## Summary

| Use Case | Solution |
|----------|----------|
| Public CDN assets | `public = true` bucket + `getPublicUrl` |
| Private user files | RLS policy + `createSignedUrl` |
| Image resizing | `TransformOptions` (Pro) |
| CDN cache control | `cacheControl` in `FileOptions` |
| Direct client uploads | `createSignedUploadUrl` |
| Folder-level access | `storage.foldername()` in RLS |

Supabase Storage hits a sweet spot for indie developers: it removes the operational overhead of S3 + CloudFront while giving you the same primitives. The RLS integration means your access rules live in one place alongside your database policies.

---

Have you hit any tricky RLS edge cases with Supabase Storage, or found a clever use for image transforms? Share your approach in the comments!
