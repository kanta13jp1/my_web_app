---
title: "Supabase Storage 実装ガイド — 画像・ファイル管理を Flutter と統合する"
tags: supabase,flutter,個人開発,postgresql
published: true
---

# Supabase Storage 実装ガイド — 画像・ファイル管理を Flutter と統合する

Supabase Storage は S3 互換のファイルストレージで、RLS と統合されている。「ユーザーは自分のファイルだけアクセスできる」という制御が SQL で書ける。Flutter からの操作パターンを全公開する。

## バケット設計

```sql
-- バケット作成 (Supabase Dashboard または SQL)
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true),   -- 公開バケット (アバター)
       ('documents', 'documents', false); -- 非公開バケット (書類)
```

**public バケット**: URL 知ってれば誰でも閲覧可。アバター・OG 画像など。
**private バケット**: 認証済みユーザーのみ。RLS で細かく制御。

## Storage RLS ポリシー

```sql
-- 自分のファイルのみ操作可
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

`storage.foldername(name)` でパスの先頭ディレクトリを取得。`{user_id}/filename.pdf` という構造にすることで自動的にユーザー分離できる。

## Flutter からのアップロード

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
      fileOptions: const FileOptions(upsert: true), // 上書き許可
    );

    // 公開 URL を取得
    final url = supabase.storage.from('avatars').getPublicUrl(fileName);
    return url;
  } catch (e) {
    debugPrint('Upload error: $e');
    return null;
  }
}
```

## 画像ピッカーと統合

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
    // DB にも URL を保存
    await supabase.from('profiles').update({'avatar_url': url})
        .eq('id', supabase.auth.currentUser!.id);
  }
}
```

`imageQuality: 80` で圧縮 → アップロードサイズ削減。`maxWidth/maxHeight` でリサイズ。

## 署名付き URL (プライベートファイル)

```dart
// 有効期限付き URL を生成 (1時間)
Future<String?> getSignedUrl(String filePath) async {
  try {
    final url = await supabase.storage.from('documents').createSignedUrl(
      filePath,
      3600, // 秒数
    );
    return url;
  } catch (e) {
    return null;
  }
}
```

プライベートバケットのファイルは直接 URL アクセス不可。署名付き URL を都度生成して表示する。

## ファイル一覧取得

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

## 削除

```dart
Future<void> deleteFile(String filePath) async {
  await supabase.storage.from('documents').remove([filePath]);
}
```

## 画像変換 (Image Transformations)

Supabase Storage は URL パラメータで画像変換できる:

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

サムネイル生成が不要になる。URL パラメータだけでリサイズ・トリミング対応。

## まとめ

Supabase Storage の実装ポイント:
1. バケット設計 (public/private) はユースケースで判断
2. RLS でユーザー分離 → `{user_id}/filename` パス構造が鉄則
3. プライベートファイルは署名付き URL で配信
4. Image Transformations でサーバーサイドリサイズ → フロント実装不要
