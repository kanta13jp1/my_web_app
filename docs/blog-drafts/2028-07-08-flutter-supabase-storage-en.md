---
title: "Flutter × Supabase Storage — Complete File Upload Guide"
tags: flutter,supabase,ai,indiedev
published: true
---

# Flutter × Supabase Storage — Complete File Upload Guide

Manage images, PDFs, and videos in one place with Supabase Storage.

## Basic Upload

```dart
Future<String> uploadFile(File file, String userId) async {
  final ext = file.path.split('.').last;
  final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';

  await supabase.storage
      .from('uploads')
      .upload(path, file, fileOptions: const FileOptions(upsert: false));

  // Get the public URL
  final url = supabase.storage.from('uploads').getPublicUrl(path);
  return url;
}
```

## Compress + Upload Images

```dart
import 'package:image/image.dart' as img;

Future<String> uploadCompressedImage(XFile picked, String userId) async {
  final bytes = await picked.readAsBytes();
  final original = img.decodeImage(bytes)!;

  // Resize to max 1200px wide
  final resized = img.copyResize(
    original,
    width: original.width > 1200 ? 1200 : original.width,
  );

  // JPEG at quality 85
  final compressed = img.encodeJpg(resized, quality: 85);

  final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
  await supabase.storage
      .from('avatars')
      .uploadBinary(path, Uint8List.fromList(compressed));

  return supabase.storage.from('avatars').getPublicUrl(path);
}
```

## Upload Progress Indicator

```dart
// The Supabase Flutter SDK doesn't expose a native progress callback yet.
// Use dio to track progress:
import 'package:dio/dio.dart';

Future<void> uploadWithProgress(
  File file,
  String path,
  ValueNotifier<double> progress,
) async {
  final dio = Dio();
  final formData = FormData.fromMap({
    'file': await MultipartFile.fromFile(file.path),
  });

  // POST directly to the Supabase Storage REST endpoint
  await dio.post(
    '${supabase.storageUrl}/object/uploads/$path',
    data: formData,
    options: Options(headers: {
      'Authorization': 'Bearer ${supabase.auth.currentSession!.accessToken}',
    }),
    onSendProgress: (sent, total) {
      progress.value = sent / total;
    },
  );
}
```

## Storage Policies (equivalent to RLS)

```sql
-- Users can only upload to their own folder
CREATE POLICY "users can upload own files"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'uploads'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Public bucket is readable by everyone
CREATE POLICY "public read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'public-assets');

-- Users can only delete their own files
CREATE POLICY "users can delete own files"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'uploads'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
```

## Summary

```
Basic upload    → storage.from('bucket').upload(path, file)
Compression     → image package: resize + encodeJpg
Progress        → dio + Supabase REST API with onSendProgress
Policies        → storage.foldername(name)[1] = auth.uid() isolates per-user
```

Use separate buckets for public and private assets — access control is per-bucket.
