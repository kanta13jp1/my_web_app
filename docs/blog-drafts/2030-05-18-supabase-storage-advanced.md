---
title: "Supabase Storage 完全ガイド — バケット設計・署名URL・画像変換・RLS"
tags: supabase,flutter,個人開発,AI
published: true
---

# Supabase Storage 完全ガイド — バケット設計・署名URL・画像変換・RLS

Supabase Storage は S3 互換のオブジェクトストレージを PostgreSQL の RLS と統合したサービスです。単なるファイル置き場でなく、アクセス制御・画像変換・CDN配信まで一括で扱えます。

## バケット設計の基本

```sql
-- Public バケット: 署名URL不要、URLだけで誰でもアクセス可
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true);

-- Private バケット: 署名URLが必要
INSERT INTO storage.buckets (id, name, public)
VALUES ('user-documents', 'user-documents', false);
```

**設計方針**:
- アバター・OGP画像 → Public (CDN キャッシュ効率最大)
- ユーザー添付ファイル・請求書 → Private (署名URL で時限アクセス)
- 管理者専用データ → Private + RLS でユーザー完全排除

## RLS でストレージを保護

```sql
-- avatars バケット: 本人のみ upload/delete 可、誰でも読める (Public)
CREATE POLICY "User can upload own avatar"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'avatars'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "User can delete own avatar"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'avatars'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- user-documents: 本人のみ全操作
CREATE POLICY "Users access own documents"
ON storage.objects
USING (
  bucket_id = 'user-documents'
  AND auth.uid()::text = (storage.foldername(name))[1]
)
WITH CHECK (
  bucket_id = 'user-documents'
  AND auth.uid()::text = (storage.foldername(name))[1]
);
```

`storage.foldername(name)[1]` で `{uid}/filename.pdf` のパス先頭要素 (uid) を抽出。

## Flutter からのアップロード

```dart
Future<String> uploadAvatar(Uint8List bytes, String userId) async {
  final ext = 'jpg'; // or detect from bytes
  final path = '$userId/avatar.$ext';

  await Supabase.instance.client.storage
      .from('avatars')
      .uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true, // 上書き許可
        ),
      );

  // Public URL を返す (変換なし)
  return Supabase.instance.client.storage
      .from('avatars')
      .getPublicUrl(path);
}
```

## 署名URL (Private バケット)

```dart
// 1時間有効の署名URL生成
Future<String> getSignedUrl(String userId, String filename) async {
  final path = '$userId/$filename';
  final response = await Supabase.instance.client.storage
      .from('user-documents')
      .createSignedUrl(path, 3600); // 秒
  return response;
}

// 複数ファイルを一括で署名URL化
Future<List<SignedUrl>> getBatchSignedUrls(
    String userId, List<String> filenames) async {
  final paths = filenames.map((f) => '$userId/$f').toList();
  return Supabase.instance.client.storage
      .from('user-documents')
      .createSignedUrls(paths, 3600);
}
```

署名URLは Edge Function 経由で生成し、クライアントに `service_role` を渡さない設計が安全。

## 画像変換 (Image Transformation)

```dart
// リサイズ + WebP変換 (Public バケット)
String getAvatarUrl(String userId, {int size = 64}) {
  return Supabase.instance.client.storage
      .from('avatars')
      .getPublicUrl(
        '$userId/avatar.jpg',
        transform: TransformOptions(
          width: size,
          height: size,
          resize: ResizeMode.cover,
          format: RequestImageFormat.webp,
          quality: 80,
        ),
      );
}

// サムネイル生成
String getThumbnail(String path) {
  return Supabase.instance.client.storage
      .from('avatars')
      .getPublicUrl(
        path,
        transform: TransformOptions(width: 200, height: 200),
      );
}
```

変換後画像は CDN にキャッシュされる。同一パラメータの2回目以降はオリジンへのアクセスなし。

## Edge Function から Storage を操作

```typescript
// Deno Edge Function: ファイルアップロード + DB記録をアトミックに処理
Deno.serve(async (req) => {
  const { userId, filename, base64Data } = await req.json();
  const bytes = Uint8Array.from(atob(base64Data), c => c.charCodeAt(0));

  const { error: storageError } = await supabaseAdmin.storage
    .from('user-documents')
    .upload(`${userId}/${filename}`, bytes, {
      contentType: 'application/pdf',
      upsert: false,
    });

  if (storageError) {
    return new Response(JSON.stringify({ error: storageError.message }), {
      status: 400,
    });
  }

  // DB にメタデータを記録
  const { error: dbError } = await supabaseAdmin
    .from('documents')
    .insert({ user_id: userId, filename, uploaded_at: new Date() });

  if (dbError) {
    // ロールバック: storage から削除
    await supabaseAdmin.storage
      .from('user-documents')
      .remove([`${userId}/${filename}`]);
    return new Response(JSON.stringify({ error: dbError.message }), {
      status: 500,
    });
  }

  return new Response(JSON.stringify({ success: true }));
});
```

## ファイルサイズ制限とバリデーション

```dart
const maxFileSizeBytes = 10 * 1024 * 1024; // 10MB

Future<void> validateAndUpload(XFile file) async {
  final bytes = await file.readAsBytes();

  if (bytes.length > maxFileSizeBytes) {
    throw Exception('ファイルサイズは10MB以下にしてください');
  }

  // MIME type チェック (server side でも必須)
  final allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];
  final mimeType = file.mimeType ?? 'application/octet-stream';
  if (!allowedTypes.contains(mimeType)) {
    throw Exception('対応していないファイル形式です');
  }

  await uploadToStorage(bytes, file.name);
}
```

クライアント側バリデーションは UX のため。**サーバー側 (Edge Function + RLS) が信頼の起点**。

## ストレージ使用量モニタリング

```sql
-- バケット別使用量サマリ
SELECT
  bucket_id,
  count(*) AS file_count,
  pg_size_pretty(sum(metadata->>'size')::bigint) AS total_size
FROM storage.objects
GROUP BY bucket_id
ORDER BY sum(metadata->>'size')::bigint DESC;
```

## まとめ

| 用途 | バケット種別 | URL種別 | 変換 |
|------|------------|---------|------|
| アバター・公開画像 | Public | Public URL | ✅ transform |
| ユーザードキュメント | Private | 署名URL (1h) | ❌ |
| 管理者ファイル | Private | Edge Function 経由 | ❌ |

Supabase Storage は PostgreSQL RLS と同じ思想で設計されており、SQL でアクセス制御を完結できる点が他の S3 互換サービスにない強みです。
