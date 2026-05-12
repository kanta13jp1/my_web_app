---
title: "Supabase Storage 実践 — 画像アップロード・CDN配信・RLSポリシー設計"
tags: flutter,dart,個人開発,AI
published: true
---

# Supabase Storage 実践 — 画像アップロード・CDN配信・RLSポリシー設計

Supabase Storage はオブジェクトストレージ・CDN・RLS (Row Level Security) ポリシーを統合したファイル管理サービスです。本記事では Flutter アプリからの画像アップロード、RLS によるアクセス制御、署名付き URL、画像変換 (Transform) まで実践的なコードで解説します。

## バケットの作成

Supabase ダッシュボードまたは SQL で作成します。

```sql
-- public バケット（CDN キャッシュ有効）
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true);

-- private バケット（署名付き URL が必要）
INSERT INTO storage.buckets (id, name, public)
VALUES ('documents', 'documents', false);
```

`public = true` のバケットは認証なしで URL アクセス可能になります。ユーザーアバターや OGP 画像など公開してよいリソースに使います。

## Flutter からのファイルアップロード

```dart
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final _supabase = Supabase.instance.client;

  /// 画像ピッカーで選択してアバターとしてアップロード
  Future<String?> uploadAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null) return null;

    final userId = _supabase.auth.currentUser!.id;
    final ext = file.path.split('.').last.toLowerCase();
    final path = 'public/$userId/avatar.$ext';

    await _supabase.storage.from('avatars').upload(
      path,
      File(file.path),
      fileOptions: const FileOptions(
        cacheControl: '3600',
        upsert: true, // 上書き許可
        contentType: 'image/jpeg',
      ),
    );

    return _supabase.storage.from('avatars').getPublicUrl(path);
  }

  /// バイト列を直接アップロード（Web 対応）
  Future<String> uploadBytes({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await _supabase.storage.from(bucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: contentType,
        upsert: true,
      ),
    );
    return _supabase.storage.from(bucket).getPublicUrl(path);
  }

  /// 複数ファイルをまとめてアップロード
  Future<List<String>> uploadMultiple(List<XFile> files, String folder) async {
    final userId = _supabase.auth.currentUser!.id;
    final urls = <String>[];

    for (final file in files) {
      final name = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final path = '$folder/$userId/$name';
      final bytes = await file.readAsBytes();

      await _supabase.storage.from('documents').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: file.mimeType ?? 'application/octet-stream'),
      );

      final signedUrl = await _supabase.storage
          .from('documents')
          .createSignedUrl(path, 60 * 60 * 24); // 24時間有効
      urls.add(signedUrl);
    }

    return urls;
  }
}
```

## RLS ポリシーの設計

Storage の RLS は `storage.objects` テーブルに設定します。

```sql
-- ポリシー 1: 認証ユーザーは自分のフォルダのみ読み書き可能
CREATE POLICY "Users can manage own avatars"
ON storage.objects
FOR ALL
TO authenticated
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = 'public'
  AND (storage.foldername(name))[2] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = 'public'
  AND (storage.foldername(name))[2] = auth.uid()::text
);

-- ポリシー 2: 全員がアバターを閲覧可能（public バケット補完）
CREATE POLICY "Public avatars are viewable by everyone"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'avatars');

-- ポリシー 3: documents は本人のみ
CREATE POLICY "Private documents owner access"
ON storage.objects
FOR ALL
TO authenticated
USING (
  bucket_id = 'documents'
  AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'documents'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- ポリシー 4: 管理者は全ファイルへのアクセスを許可
CREATE POLICY "Admins can access all files"
ON storage.objects
FOR ALL
TO authenticated
USING (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
);
```

## 署名付き URL (Signed URL)

private バケットのファイルへの時限アクセスを提供します。

```dart
class SignedUrlService {
  final _supabase = Supabase.instance.client;

  /// 1時間有効な署名付き URL を生成
  Future<String> getSignedUrl(String path, {int expiresInSeconds = 3600}) async {
    return await _supabase.storage
        .from('documents')
        .createSignedUrl(path, expiresInSeconds);
  }

  /// 複数ファイルの署名付き URL をまとめて生成（バッチ）
  Future<List<SignedUrl>> getSignedUrls(List<String> paths) async {
    return await _supabase.storage
        .from('documents')
        .createSignedUrls(paths, 3600);
  }

  /// アップロード専用 URL（クライアントから直接アップロード）
  Future<String> getUploadUrl(String path) async {
    final response = await _supabase.storage
        .from('documents')
        .createSignedUploadUrl(path);
    return response.signedUrl;
  }
}
```

## 画像変換 (Image Transform)

Supabase Storage Pro 以上で使える画像変換機能で、リサイズ・フォーマット変換をエッジで処理できます。

```dart
class ImageTransformService {
  final _supabase = Supabase.instance.client;

  /// サムネイル URL を取得 (200x200, WebP形式)
  String getThumbnailUrl(String path) {
    return _supabase.storage
        .from('avatars')
        .getPublicUrl(
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

  /// レスポンシブ画像 URL セットを生成
  Map<String, String> getResponsiveUrls(String path) {
    final sizes = {'sm': 400, 'md': 800, 'lg': 1200};
    return sizes.map((key, width) => MapEntry(
      key,
      _supabase.storage.from('images').getPublicUrl(
        path,
        transform: TransformOptions(width: width, format: TransformFormat.webp),
      ),
    ));
  }
}
```

Flutter ウィジェットで表示する例:

```dart
class AvatarWidget extends StatelessWidget {
  const AvatarWidget({required this.userId, required this.path, super.key});
  final String userId;
  final String path;

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = ImageTransformService().getThumbnailUrl(path);

    return CircleAvatar(
      radius: 40,
      backgroundImage: NetworkImage(thumbnailUrl),
      onBackgroundImageError: (_, __) {},
      child: thumbnailUrl.isEmpty
          ? Text(userId[0].toUpperCase())
          : null,
    );
  }
}
```

## ファイル管理 (一覧・削除・移動)

```dart
class FileManagerService {
  final _supabase = Supabase.instance.client;

  /// フォルダ内のファイル一覧
  Future<List<FileObject>> listFiles(String folder) async {
    return await _supabase.storage.from('documents').list(
      path: folder,
      searchOptions: const SearchOptions(
        sortBy: SortBy(column: 'created_at', order: 'desc'),
        limit: 100,
      ),
    );
  }

  /// ファイル削除
  Future<void> deleteFile(String path) async {
    await _supabase.storage.from('documents').remove([path]);
  }

  /// ファイル移動（コピー → 削除）
  Future<void> moveFile(String from, String to) async {
    await _supabase.storage.from('documents').move(from, to);
  }

  /// バケット使用量確認
  Future<void> printBucketStats() async {
    final files = await _supabase.storage.from('documents').list();
    final totalSize = files.fold<int>(0, (sum, f) => sum + (f.metadata?['size'] as int? ?? 0));
    print('Files: ${files.length}, Total: ${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB');
  }
}
```

## CDN キャッシュ設定

アップロード時に `Cache-Control` ヘッダーを設定することで CDN のキャッシュ時間を制御できます。

```dart
// 長期キャッシュ（静的アセット向け）
await supabase.storage.from('images').upload(
  path,
  file,
  fileOptions: const FileOptions(
    cacheControl: '31536000', // 1年
    upsert: false,
  ),
);

// キャッシュ無効（頻繁に更新されるファイル）
await supabase.storage.from('avatars').upload(
  path,
  file,
  fileOptions: const FileOptions(
    cacheControl: '0',
    upsert: true,
  ),
);
```

## まとめ

| ユースケース | API / 設定 |
|-------------|-----------|
| 公開ファイル | `public = true` バケット + `getPublicUrl` |
| 認証ユーザー限定 | RLS ポリシー + `createSignedUrl` |
| 画像リサイズ | `TransformOptions` (Pro プラン以上) |
| CDN 最適化 | `cacheControl` ヘッダー指定 |
| アップロード専用 URL | `createSignedUploadUrl` |

Supabase Storage は RLS によるきめ細かいアクセス制御と CDN キャッシュを組み合わせることで、セキュアかつ高速なファイル配信を実現できます。

---

Supabase Storage を使っていて詰まった点はありましたか？RLS ポリシーの設計でハマりがちな箇所があればコメントで教えてください！
