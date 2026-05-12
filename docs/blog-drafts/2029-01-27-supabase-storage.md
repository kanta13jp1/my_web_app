---
title: "Supabase Storage 完全ガイド — Flutter でファイル・画像管理を実装する"
tags: supabase,flutter,AI,個人開発
published: true
---

# Supabase Storage 完全ガイド — Flutter でファイル・画像管理を実装する

Supabase Storage は S3 互換のオブジェクトストレージです。Flutter から画像・動画・ドキュメントのアップロード・ダウンロード・削除を実装する方法を解説します。

## Supabase Storage の概念

```
Storage
└── Bucket (バケット)
    ├── public  → 認証不要でアクセス可
    └── private → 認証必須 (RLS 適用)
        └── {user_id}/
            ├── avatar.jpg
            └── documents/report.pdf
```

## セットアップ

```yaml
# pubspec.yaml
dependencies:
  supabase_flutter: ^2.5.0
  image_picker: ^1.1.0    # 画像選択
  file_picker: ^8.0.0     # ファイル選択
```

## バケット作成 (Supabase ダッシュボード or SQL)

```sql
-- バケット作成
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true);

-- RLS ポリシー: 自分のファイルのみ操作可
CREATE POLICY "own_avatar_upload" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'avatars' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "own_avatar_update" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'avatars' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "avatars_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');
```

## 画像アップロード

```dart
import 'package:image_picker/image_picker.dart';
import 'dart:io';

Future<String?> uploadAvatar() async {
  final picker = ImagePicker();
  final image = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 800,
    maxHeight: 800,
    imageQuality: 85,
  );
  if (image == null) return null;

  final userId = supabase.auth.currentUser!.id;
  final extension = image.path.split('.').last.toLowerCase();
  final filePath = '$userId/avatar.$extension';
  final file = File(image.path);

  await supabase.storage.from('avatars').upload(
    filePath,
    file,
    fileOptions: const FileOptions(
      cacheControl: '3600',
      upsert: true,  // 上書き許可
    ),
  );

  // 公開 URL を返す
  return supabase.storage.from('avatars').getPublicUrl(filePath);
}
```

## ファイル一覧取得

```dart
Future<List<FileObject>> listUserFiles() async {
  final userId = supabase.auth.currentUser!.id;
  return await supabase.storage
    .from('documents')
    .list(path: userId, searchOptions: const SearchOptions(limit: 100));
}

// Widget
FutureBuilder<List<FileObject>>(
  future: listUserFiles(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const CircularProgressIndicator();
    return ListView.builder(
      itemCount: snapshot.data!.length,
      itemBuilder: (context, index) {
        final file = snapshot.data![index];
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
    );
  },
)
```

## ダウンロード (署名付き URL)

```dart
Future<String> getSignedUrl(String filePath) async {
  // プライベートファイルは署名付き URL を使用 (60秒有効)
  return await supabase.storage
    .from('documents')
    .createSignedUrl(filePath, 60);
}

Future<void> downloadFile(String fileName) async {
  final userId = supabase.auth.currentUser!.id;
  final signedUrl = await getSignedUrl('$userId/$fileName');

  // URL をブラウザや DL マネージャで開く
  if (await canLaunchUrl(Uri.parse(signedUrl))) {
    await launchUrl(Uri.parse(signedUrl));
  }
}
```

## ファイル削除

```dart
Future<void> deleteFile(String filePath) async {
  await supabase.storage.from('documents').remove([filePath]);
}
```

## 画像表示の最適化

```dart
// キャッシュ付き画像表示
import 'package:cached_network_image/cached_network_image.dart';

CachedNetworkImage(
  imageUrl: supabase.storage
    .from('avatars')
    .getPublicUrl('$userId/avatar.jpg'),
  placeholder: (context, url) => const CircularProgressIndicator(),
  errorWidget: (context, url, error) => const Icon(Icons.person),
  width: 80,
  height: 80,
  fit: BoxFit.cover,
)
```

## アップロード進捗の表示

```dart
// Supabase Flutter v2 では onUploadProgress コールバックあり
await supabase.storage.from('documents').upload(
  filePath,
  file,
  fileOptions: FileOptions(upsert: true),
  onUploadProgress: (bytesUploaded, bytesTotal) {
    final progress = bytesUploaded / bytesTotal;
    setState(() => _uploadProgress = progress);
  },
);
```

## まとめ

Supabase Storage は RLS と組み合わせることで、安全なユーザーファイル管理を簡単に実装できます。Flutter との相性も良く、`supabase_flutter` パッケージ一つで完結します。

---

自分株式会社では Flutter × Supabase でAIライフマネジメントアプリを開発中。個人開発の知見を毎週発信しています。
