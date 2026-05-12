---
title: "Flutter × Supabase Storage ��� ファイルア���プロード完全ガイド"
tags: flutter,supabase,AI,個人開発
published: true
---

# Flutter × Supabase Storage — ファイルアップロード完全ガイド

画像・PDF・動画のアップロードを Supabase Storage で一元管理する。

## 基本的なアップロード

```dart
Future<String> uploadFile(File file, String userId) async {
  final ext = file.path.split('.').last;
  final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';

  await supabase.storage
      .from('uploads')
      .upload(path, file, fileOptions: const FileOptions(upsert: false));

  // 公開 URL を取得
  final url = supabase.storage.from('uploads').getPublicUrl(path);
  return url;
}
```

## 画像の圧縮 + アップロ���ド

```dart
import 'package:image/image.dart' as img;

Future<String> uploadCompressedImage(XFile picked, String userId) async {
  // 読み込み
  final bytes = await picked.readAsBytes();
  final original = img.decodeImage(bytes)!;

  // 最大 1200px にリサイズ
  final resized = img.copyResize(
    original,
    width: original.width > 1200 ? 1200 : original.width,
  );

  // JPEG 圧縮 (quality 85)
  final compressed = img.encodeJpg(resized, quality: 85);

  final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
  await supabase.storage
      .from('avatars')
      .uploadBinary(path, Uint8List.fromList(compressed));

  return supabase.storage.from('avatars').getPublicUrl(path);
}
```

## アップロード進捗の表示

```dart
// Supabase Flutter SDK は現時点でネイティブ progress callback なし
// dio を使って進捗を表示する場合:
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

  // Supabase Storage REST API エンドポイントに直接 POST
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

## Storage Policies (RLS 相当)

```sql
-- 自分のフォルダのみアップロード可
CREATE POLICY "users can upload own files"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'uploads'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ���開バケットは全員閲覧可
CREATE POLICY "public read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'public-assets');

-- 自分のファイルのみ削除可
CREATE POLICY "users can delete own files"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'uploads'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
```

## まとめ

```
基本アップロード → storage.from('bucket').upload(path, file)
圧縮         → image パッケージで resize + encodeJpg
進捗表示     → dio + Supabase REST API で onSendProgress
Policies     → storage.foldername(name)[1] = auth.uid() でユーザー隔離
```

Storage はバケット単位でアクセス制御。`public` バケットと `private` バケットを目的別に分ける。
