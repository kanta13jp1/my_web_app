---
title: "Supabase Storage 完全ガイド — ファイルアップロード / CDN / 変換"
tags: supabase,flutter,個人開発,AI
published: true
---

# Supabase Storage 完全ガイド — ファイルアップロード / CDN / 変換

画像・動画・PDF の管理に S3 互換の Supabase Storage を使う。RLS で認証連携、CDN で配信高速化する方法を整理する。

## Supabase Storage の全体像

```
Supabase Storage の構成:
  Bucket (バケット)
    ├── public  → 誰でも読み取り可
    └── private → RLS で制御 (認証必須)

  オブジェクト = ファイル (パスで管理)
  例: avatars/<user_id>/profile.jpg
      posts/<post_id>/cover.webp
      documents/<user_id>/report.pdf
```

## セットアップ: バケット作成

```sql
-- マイグレーションでバケットを作成
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)  -- public bucket
ON CONFLICT DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('documents', 'documents', false)  -- private bucket
ON CONFLICT DO NOTHING;

-- RLS ポリシー (documents は本人のみ)
CREATE POLICY "users can manage own documents"
ON storage.objects FOR ALL
TO authenticated
USING (
  bucket_id = 'documents'
  AND (storage.foldername(name))[1] = auth.uid()::text
);
```

## Flutter からのアップロード

```dart
// 画像ピッカー → Supabase Storage にアップロード
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
        upsert: true,  // 上書き許可
      ),
    );

  return supabase.storage
    .from('avatars')
    .getPublicUrl(path);
}
```

## CDN URL と画像変換

```dart
// 公開 URL (CDN 経由で配信)
final publicUrl = supabase.storage
  .from('avatars')
  .getPublicUrl('user123/profile.jpg');

// 変換付き URL (リサイズ・フォーマット変換)
final thumbnailUrl = supabase.storage
  .from('avatars')
  .getPublicUrl(
    'user123/profile.jpg',
    transform: TransformOptions(
      width: 100,
      height: 100,
      resize: ResizeOption.cover,
      format: FormatOption.webp,  // WebP に変換
      quality: 80,
    ),
  );
```

**変換の活用例**:

```dart
// ウィジェットサイズに合わせた最適サイズを要求
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

## Private ファイルの署名付き URL

```dart
// 認証済みユーザーのみアクセス可能な一時 URL (60秒有効)
Future<String> getSignedUrl(String path) async {
  final response = await supabase.storage
    .from('documents')
    .createSignedUrl(path, 60);
  return response;
}

// ダウンロード (バイト列として取得)
Future<Uint8List> downloadFile(String path) async {
  return supabase.storage
    .from('documents')
    .download(path);
}
```

## ファイル管理 (一覧・削除)

```dart
// バケット内のファイル一覧
Future<List<FileObject>> listFiles(String userId) async {
  return supabase.storage
    .from('documents')
    .list(path: userId);
}

// 削除
Future<void> deleteFile(String path) async {
  await supabase.storage
    .from('documents')
    .remove([path]);
}
```

## まとめ

```
public bucket    → 誰でも読める (アバター・OGP画像)
private bucket   → RLS + 署名付き URL (契約書・レポート)
変換 API         → リサイズ・WebP変換を URL パラメータで指定
CDN              → Supabase が自動的にエッジキャッシュ
```

S3 互換 API のため、既存の S3 ライブラリも使える。Supabase Storage は認証と RLS がシームレスに統合されている点が最大の利点。

