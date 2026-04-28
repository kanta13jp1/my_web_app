---
title: "Supabase Storage Guide: File Uploads, CDN, and Image Transforms"
tags: supabase,flutter,indiedev,ai
published: true
---

# Supabase Storage Guide: File Uploads, CDN, and Image Transforms

Managing images, videos, and PDFs with Supabase Storage — S3-compatible, RLS-integrated, CDN-delivered.

## How Supabase Storage Works

```
Supabase Storage structure:
  Bucket
    ├── public  → anyone can read
    └── private → RLS-controlled (auth required)

  Objects = files, managed by path
  Examples:
    avatars/<user_id>/profile.jpg
    posts/<post_id>/cover.webp
    documents/<user_id>/report.pdf
```

## Setup: Create Buckets via Migration

```sql
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('documents', 'documents', false)
ON CONFLICT DO NOTHING;

-- RLS: users can only access their own documents
CREATE POLICY "users can manage own documents"
ON storage.objects FOR ALL
TO authenticated
USING (
  bucket_id = 'documents'
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

## Upload from Flutter

```dart
import 'package:image_picker/image_picker.dart';

Future<String?> uploadAvatar(String userId) async {
  final picker = ImagePicker();
  final image = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 800,
    maxHeight: 800,
    imageQuality: 85,
  );
  if (image == null) return null;

  final bytes = await image.readAsBytes();
  final ext = image.path.split('.').last;
  final path = '$userId/profile.$ext';

  await supabase.storage
    .from('avatars')
    .uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: 'image/$ext',
        upsert: true,
      ),
    );

  return supabase.storage.from('avatars').getPublicUrl(path);
}
```

## CDN URLs and Image Transforms

```dart
// Public URL (served via CDN edge cache)
final publicUrl = supabase.storage
  .from('avatars')
  .getPublicUrl('user123/profile.jpg');

// Transform URL (resize + format convert)
final thumbnailUrl = supabase.storage
  .from('avatars')
  .getPublicUrl(
    'user123/profile.jpg',
    transform: TransformOptions(
      width: 100,
      height: 100,
      resize: ResizeOption.cover,
      format: FormatOption.webp,
      quality: 80,
    ),
  );
```

**Request the right size for each widget**:

```dart
Widget buildAvatar(String userId, double size) {
  final px = (size * MediaQuery.of(context).devicePixelRatio).round();
  final url = supabase.storage
    .from('avatars')
    .getPublicUrl(
      '$userId/profile.jpg',
      transform: TransformOptions(width: px, height: px),
    );
  return CachedNetworkImage(imageUrl: url);
}
```

## Signed URLs for Private Files

```dart
// Temporary URL valid for 60 seconds
Future<String> getSignedUrl(String path) async {
  return supabase.storage.from('documents').createSignedUrl(path, 60);
}

// Download as bytes
Future<Uint8List> downloadFile(String path) async {
  return supabase.storage.from('documents').download(path);
}
```

## List and Delete Files

```dart
// List files in a folder
Future<List<FileObject>> listFiles(String userId) async {
  return supabase.storage.from('documents').list(path: userId);
}

// Delete
Future<void> deleteFile(String path) async {
  await supabase.storage.from('documents').remove([path]);
}
```

## Summary

```
Public bucket  → anyone can read (avatars, OGP images)
Private bucket → RLS + signed URLs (contracts, reports)
Transform API  → resize, WebP conversion via URL params
CDN            → automatic edge caching by Supabase
```

Supabase Storage's key advantage: auth and RLS integrate seamlessly, so you don't need separate access control logic for file operations.

