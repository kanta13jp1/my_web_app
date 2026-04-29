---
title: "Supabase Storage Complete Guide — File & Image Management in Flutter"
tags: supabase,flutter,ai,indiedev
published: true
---

# Supabase Storage Complete Guide — File & Image Management in Flutter

Supabase Storage is an S3-compatible object storage service. This guide covers uploading, downloading, and deleting files and images from Flutter.

## Supabase Storage Concepts

```
Storage
└── Bucket
    ├── public  → No auth required
    └── private → Auth required (RLS enforced)
        └── {user_id}/
            ├── avatar.jpg
            └── documents/report.pdf
```

## Setup

```yaml
dependencies:
  supabase_flutter: ^2.5.0
  image_picker: ^1.1.0
  file_picker: ^8.0.0
```

## Creating a Bucket

```sql
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true);

-- RLS: users can only manage their own files
CREATE POLICY "own_avatar_upload" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'avatars' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "avatars_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');
```

## Uploading Images

```dart
import 'package:image_picker/image_picker.dart';
import 'dart:io';

Future<String?> uploadAvatar() async {
  final image = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 800,
    maxHeight: 800,
    imageQuality: 85,
  );
  if (image == null) return null;

  final userId = supabase.auth.currentUser!.id;
  final ext = image.path.split('.').last.toLowerCase();
  final filePath = '$userId/avatar.$ext';

  await supabase.storage.from('avatars').upload(
    filePath,
    File(image.path),
    fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
  );

  return supabase.storage.from('avatars').getPublicUrl(filePath);
}
```

## Listing Files

```dart
Future<List<FileObject>> listUserFiles() async {
  final userId = supabase.auth.currentUser!.id;
  return supabase.storage.from('documents').list(
    path: userId,
    searchOptions: const SearchOptions(limit: 100),
  );
}

ListView.builder(
  itemCount: files.length,
  itemBuilder: (context, index) {
    final file = files[index];
    return ListTile(
      leading: const Icon(Icons.insert_drive_file),
      title: Text(file.name),
      subtitle: Text('${(file.metadata?['size'] as int? ?? 0) ~/ 1024} KB'),
      trailing: IconButton(
        icon: const Icon(Icons.download),
        onPressed: () => downloadFile(file.name),
      ),
    );
  },
)
```

## Downloading with Signed URLs

```dart
Future<String> getSignedUrl(String filePath) async {
  // Signed URL valid for 60 seconds for private files
  return supabase.storage.from('documents').createSignedUrl(filePath, 60);
}

Future<void> downloadFile(String fileName) async {
  final userId = supabase.auth.currentUser!.id;
  final url = await getSignedUrl('$userId/$fileName');
  if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url));
}
```

## Deleting Files

```dart
await supabase.storage.from('documents').remove([filePath]);
```

## Optimized Image Display

```dart
import 'package:cached_network_image/cached_network_image.dart';

CachedNetworkImage(
  imageUrl: supabase.storage.from('avatars').getPublicUrl('$userId/avatar.jpg'),
  placeholder: (_, __) => const CircularProgressIndicator(),
  errorWidget: (_, __, ___) => const Icon(Icons.person),
  width: 80,
  height: 80,
  fit: BoxFit.cover,
)
```

## Upload Progress

```dart
await supabase.storage.from('documents').upload(
  filePath,
  file,
  fileOptions: const FileOptions(upsert: true),
  onUploadProgress: (bytesUploaded, bytesTotal) {
    setState(() => _progress = bytesUploaded / bytesTotal);
  },
);
```

## Summary

Supabase Storage combined with RLS makes secure per-user file management straightforward. The `supabase_flutter` package handles everything in one dependency.

---

Building an AI Life Management app with Flutter × Supabase at 自分株式会社. Sharing indie dev insights every week.
