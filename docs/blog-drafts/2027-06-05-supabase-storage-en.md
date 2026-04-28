---
title: "Supabase Storage: File and Image Management Integrated with Flutter and RLS"
tags: supabase,flutter,postgresql,indiedev
published: true
---

# Supabase Storage: File and Image Management Integrated with Flutter and RLS

Supabase Storage is S3-compatible file storage with RLS integration. "Users can only access their own files" is enforced in SQL — no custom middleware. Here's the complete Flutter implementation.

## Bucket Design

```sql
-- Create buckets (Supabase Dashboard or SQL)
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true),    -- public bucket (avatars)
       ('documents', 'documents', false); -- private bucket (user files)
```

**Public bucket**: Anyone with the URL can view. Use for avatars, OG images.
**Private bucket**: Authenticated users only. Fine-grained control via RLS.

## Storage RLS Policies

```sql
-- Users can only operate on their own files
CREATE POLICY "Users can upload their own files"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'documents' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can view their own files"
ON storage.objects FOR SELECT
USING (bucket_id = 'documents' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete their own files"
ON storage.objects FOR DELETE
USING (bucket_id = 'documents' AND auth.uid()::text = (storage.foldername(name))[1]);
```

`storage.foldername(name)` extracts the first directory from the path. Structure paths as `{user_id}/filename.pdf` and user isolation is automatic.

## Upload from Flutter

```dart
import 'dart:io';
import 'package:image_picker/image_picker.dart';

Future<String?> uploadAvatar(File imageFile) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return null;

  final fileExt = imageFile.path.split('.').last;
  final fileName = '$userId/avatar.$fileExt';

  try {
    await supabase.storage.from('avatars').upload(
      fileName,
      imageFile,
      fileOptions: const FileOptions(upsert: true), // allow overwrite
    );

    final url = supabase.storage.from('avatars').getPublicUrl(fileName);
    return url;
  } catch (e) {
    debugPrint('Upload error: $e');
    return null;
  }
}
```

## Image Picker Integration

```dart
Future<void> pickAndUploadAvatar() async {
  final picker = ImagePicker();
  final XFile? image = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 80,
  );

  if (image == null) return;

  final url = await uploadAvatar(File(image.path));
  if (url != null) {
    await supabase.from('profiles').update({'avatar_url': url})
        .eq('id', supabase.auth.currentUser!.id);
  }
}
```

`imageQuality: 80` compresses before upload. `maxWidth/maxHeight` resizes on device.

## Signed URLs for Private Files

```dart
// Generate a time-limited URL (1 hour)
Future<String?> getSignedUrl(String filePath) async {
  try {
    final url = await supabase.storage.from('documents').createSignedUrl(
      filePath,
      3600, // seconds
    );
    return url;
  } catch (e) {
    return null;
  }
}
```

Private bucket files can't be accessed via direct URL. Generate signed URLs per request.

## List User Files

```dart
Future<List<FileObject>> listUserFiles() async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];

  final files = await supabase.storage.from('documents').list(
    path: userId,
    searchOptions: const SearchOptions(
      limit: 100,
      offset: 0,
      sortBy: SortBy(column: 'created_at', order: 'desc'),
    ),
  );
  return files;
}
```

## Delete

```dart
Future<void> deleteFile(String filePath) async {
  await supabase.storage.from('documents').remove([filePath]);
}
```

## Image Transformations

Supabase Storage transforms images via URL parameters:

```dart
String getResizedUrl(String path, {int width = 300, int height = 300}) {
  return supabase.storage.from('avatars').getPublicUrl(
    path,
    transform: TransformOptions(
      width: width,
      height: height,
      resize: ResizeMode.cover,
    ),
  );
}
```

No server-side thumbnail generation needed. Resize and crop via URL parameters.

## Summary

Key points for Supabase Storage:
1. Bucket design (public/private) based on use case
2. RLS for user isolation — `{user_id}/filename` path structure is the standard
3. Private files served via signed URLs
4. Image Transformations for server-side resize — eliminates frontend complexity
