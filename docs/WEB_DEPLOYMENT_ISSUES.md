# Web版デプロイ後の問題診断ガイド

**作成日**: 2025年11月10日
**対象**: ローカルでは動作するがデプロイ後のみエラーが発生する問題

---

## 🔍 問題の概要

**症状**:
- ✅ ローカル開発環境では添付ファイル機能が正常に動作
- ❌ デプロイ後（本番環境）でのみエラーが発生
- DBの問題ではない（テーブル、バケット、RLSポリシーは正常）

**このパターンが示すこと**:
- データベースやバックエンドの設定は正常
- **Web版特有の問題**または**環境設定の問題**の可能性が高い

---

## 🧪 Web版特有の問題チェックリスト

### 1. CORS（Cross-Origin Resource Sharing）の問題 🌐

**症状**:
- ブラウザのコンソールに`CORS policy`エラー
- `Access to fetch at 'https://...' from origin 'https://...' has been blocked by CORS policy`

**原因**:
- Supabase StorageのCORS設定が不足
- デプロイ先のドメインがCORS許可リストに含まれていない

**確認方法**:
```javascript
// ブラウザの開発者ツール（F12） → Console を確認
// CORS関連のエラーメッセージがあるか確認
```

**解決策**:

#### Supabase Dashboard での設定

1. Supabase Dashboard → **Storage** → **Policies**
2. **Configuration** タブを開く
3. **CORS Configuration** を確認

```json
// 推奨CORS設定
{
  "allowedOrigins": [
    "http://localhost:*",
    "https://your-app-domain.netlify.app",
    "https://your-app-domain.firebaseapp.com",
    "https://your-custom-domain.com"
  ],
  "allowedMethods": ["GET", "POST", "PUT", "DELETE"],
  "allowedHeaders": ["*"],
  "maxAge": 3600
}
```

#### プログラムでの対応

`supabase/config.toml`を確認:

```toml
[storage]
# CORS設定
file_size_limit = "5MiB"

# allowed_origins を追加
[storage.cors]
allowed_origins = [
  "http://localhost:*",
  "https://your-app.netlify.app"
]
```

---

### 2. Content Security Policy (CSP) の問題 🔒

**症状**:
- ブラウザのコンソールに`Content Security Policy`エラー
- `Refused to load ... because it violates the following Content Security Policy directive`

**原因**:
- デプロイ先（Netlify/Firebase Hosting等）のCSP設定が厳しすぎる
- Supabase StorageのURLが許可されていない

**確認方法**:
```bash
# ブラウザの開発者ツール → Network タブ
# Response Headers に Content-Security-Policy があるか確認
```

**解決策（Netlifyの場合）**:

`public/_headers` または `netlify.toml`を作成:

```toml
# netlify.toml
[[headers]]
  for = "/*"
  [headers.values]
    Content-Security-Policy = """
      default-src 'self';
      connect-src 'self' https://*.supabase.co;
      img-src 'self' https://*.supabase.co data:;
      script-src 'self' 'unsafe-inline' 'unsafe-eval';
      style-src 'self' 'unsafe-inline';
    """
```

---

### 3. ファイルサイズ制限の問題 📦

**症状**:
- 大きめのファイル（1MB以上）でエラー
- 小さいファイルは成功する

**原因**:
- デプロイ先のファイルサイズ制限（Netlify: 無料プランは制限あり）
- ネットワークタイムアウト

**確認方法**:
```dart
// デバッグコードを追加
print('File size: ${file.size} bytes (${file.size / 1024 / 1024} MB)');
```

**解決策**:
1. ファイルサイズをチェック
2. 必要に応じて圧縮
3. チャンク分割アップロードを検討

```dart
// ファイルサイズ制限を追加
static const int maxFileSize = 5 * 1024 * 1024; // 5MB

if (file.size > maxFileSize) {
  throw Exception('ファイルサイズは5MB以下にしてください（現在: ${(file.size / 1024 / 1024).toStringAsFixed(2)}MB）');
}
```

---

### 4. `file_picker` Web版の問題 📁

**症状**:
- ファイル選択ダイアログは開くがアップロード時にエラー
- `bytes` が null になる

**原因**:
- Web版の`file_picker`は`withData: true`が必須
- ブラウザによって挙動が異なる

**確認方法**:
```dart
// lib/services/attachment_service.dart
static Future<PlatformFile?> pickFile() async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf'],
      withData: true, // ← これが重要！
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;

      // デバッグ: bytes が取得できているか確認
      print('File name: ${file.name}');
      print('File size: ${file.size}');
      print('File bytes: ${file.bytes != null ? "OK" : "NULL"}');

      // ...
    }
  } catch (e) {
    print('Error picking file: $e');
    rethrow;
  }
}
```

**解決策**: `withData: true`が設定されているか確認

---

### 5. Supabase Storage の公開URL vs 署名付きURL 🔑

**症状**:
- アップロードは成功するがファイルが表示されない
- `403 Forbidden` エラー

**原因**:
- Storageバケットが`public: false`（プライベート）の場合、署名付きURLが必要
- `getPublicUrl()`ではアクセスできない

**確認方法**:
```sql
-- Supabase Dashboard → SQL Editor
SELECT id, public FROM storage.buckets WHERE id = 'attachments';

-- public が false の場合、署名付きURLが必要
```

**解決策**:

#### 方法A: バケットを公開にする（非推奨）

```sql
UPDATE storage.buckets
SET public = true
WHERE id = 'attachments';
```

#### 方法B: 署名付きURLを使用（推奨）

```dart
// lib/services/attachment_service.dart

// 公開URLではなく署名付きURLを使用
static Future<String> getSignedUrl(String filePath) async {
  try {
    final signedUrl = await supabase.storage
        .from('attachments')
        .createSignedUrl(filePath, 60 * 60); // 1時間有効

    return signedUrl;
  } catch (e) {
    print('Error getting signed URL: $e');
    rethrow;
  }
}

// 使用例
final url = await AttachmentService.getSignedUrl(attachment.filePath);
```

---

### 6. 環境変数の問題 🔐

**症状**:
- `Invalid API key` エラー
- `Failed to fetch` エラー

**原因**:
- デプロイ先でSupabase URLまたはAPIキーが正しく設定されていない
- 環境変数が読み込まれていない

**確認方法**:

#### Netlifyの場合

1. Netlify Dashboard → Site Settings → Environment variables
2. 以下の環境変数が設定されているか確認:
   - `SUPABASE_URL`: `https://smmkxxavexumewbfaqpy.supabase.co`
   - `SUPABASE_ANON_KEY`: `your-anon-key`

#### Firebase Hostingの場合

```bash
# .env ファイルを確認
SUPABASE_URL=https://smmkxxavexumewbfaqpy.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

**解決策**:

Flutter Webの場合、環境変数はビルド時に埋め込まれます:

```dart
// lib/main.dart
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://smmkxxavexumewbfaqpy.supabase.co',
);

const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'your-default-key-here',
);
```

または、直接ハードコード（開発時のみ推奨）:

```dart
await Supabase.initialize(
  url: 'https://smmkxxavexumewbfaqpy.supabase.co',
  anonKey: 'your-anon-key-here',
);
```

---

### 7. ネットワークタイムアウト ⏱️

**症状**:
- 大きいファイルでタイムアウト
- `TimeoutException` エラー

**原因**:
- デプロイ先のネットワークタイムアウト設定
- Supabaseのアップロード時間制限

**解決策**:

```dart
// タイムアウトを延長
static Future<Attachment?> uploadFile({
  required int noteId,
  required PlatformFile file,
}) async {
  try {
    // タイムアウトを60秒に設定
    await supabase.storage
        .from('attachments')
        .uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: false,
          ),
        )
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            throw TimeoutException('アップロードがタイムアウトしました');
          },
        );
  } catch (e) {
    rethrow;
  }
}
```

---

## 🔧 デバッグ手順

### ステップ1: ブラウザコンソールの確認

1. **デプロイされたサイトを開く**
2. **F12キー**を押して開発者ツールを開く
3. **Console**タブを確認
4. ファイルをアップロードしようとする
5. エラーメッセージを記録

**確認すべきエラー**:
- `CORS policy` → CORS問題
- `Content Security Policy` → CSP問題
- `403 Forbidden` → 署名付きURL問題
- `Invalid API key` → 環境変数問題
- `TimeoutException` → ネットワークタイムアウト

---

### ステップ2: Network タブの確認

1. **Network**タブを開く
2. ファイルをアップロードしようとする
3. 失敗したリクエストを確認
4. **Headers**と**Response**を確認

**確認すべき項目**:
- **Request URL**: Supabase StorageのURLか
- **Request Method**: POST または PUT
- **Status Code**:
  - `403` → 権限問題
  - `413` → ファイルサイズ超過
  - `0` または `(failed)` → CORS問題
- **Response Headers**: `Access-Control-Allow-Origin` があるか

---

### ステップ3: デバッグコードの追加

```dart
// lib/services/attachment_service.dart

static Future<Attachment?> uploadFile({
  required int noteId,
  required PlatformFile file,
}) async {
  try {
    final userId = supabase.auth.currentUser!.id;
    final bytes = file.bytes;

    // デバッグログ
    print('🔍 DEBUG: Starting upload...');
    print('  User ID: $userId');
    print('  Note ID: $noteId');
    print('  File name: ${file.name}');
    print('  File size: ${file.size} bytes');
    print('  Bytes available: ${bytes != null}');

    if (bytes == null) {
      print('❌ ERROR: File bytes is null!');
      throw Exception('ファイルデータが取得できません');
    }

    final mimeType = lookupMimeType(file.name) ?? 'application/octet-stream';
    final fileType = _getFileType(mimeType);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${timestamp}_${file.name}';
    final filePath = '$userId/$noteId/$fileName';

    print('  MIME type: $mimeType');
    print('  File type: $fileType');
    print('  File path: $filePath');

    // Storageにアップロード
    print('📤 Uploading to storage...');
    try {
      await supabase.storage
          .from('attachments')
          .uploadBinary(filePath, bytes);
      print('✅ Upload successful');
    } catch (storageError) {
      print('❌ Storage upload failed: $storageError');
      rethrow;
    }

    // データベースに記録
    print('💾 Saving to database...');
    try {
      final response = await supabase
          .from('attachments')
          .insert({
            'note_id': noteId,
            'user_id': userId,
            'file_name': file.name,
            'file_path': filePath,
            'file_size': file.size,
            'file_type': fileType,
            'mime_type': mimeType,
          })
          .select()
          .single();
      print('✅ Database save successful');

      return Attachment.fromJson(response);
    } catch (dbError) {
      print('❌ Database save failed: $dbError');

      // ロールバック: Storageから削除
      try {
        await supabase.storage.from('attachments').remove([filePath]);
        print('🔄 Rolled back storage upload');
      } catch (rollbackError) {
        print('⚠️ Rollback failed: $rollbackError');
      }

      rethrow;
    }
  } catch (e, stackTrace) {
    print('❌ FATAL ERROR: $e');
    print('Stack trace: $stackTrace');
    rethrow;
  }
}
```

---

## ✅ 推奨される対応手順

### 1. エラーメッセージの取得

デプロイされたサイトで:
1. ブラウザの開発者ツールを開く（F12）
2. Console タブと Network タブを確認
3. ファイルアップロードを試す
4. エラーメッセージとステータスコードを記録

### 2. CORS設定の確認

```sql
-- Supabase Dashboard → SQL Editor
SELECT * FROM storage.buckets WHERE id = 'attachments';
```

結果を確認し、必要に応じてCORS設定を追加

### 3. 署名付きURLの実装

プライベートバケットの場合、署名付きURLを使用:

```dart
// getPublicUrl() の代わりに createSignedUrl() を使用
final url = await supabase.storage
    .from('attachments')
    .createSignedUrl(filePath, 60 * 60); // 1時間有効
```

### 4. デバッグコードの追加

上記のデバッグコードを追加してログを確認

### 5. 環境変数の確認

デプロイ先でSupabase URLとAPIキーが正しく設定されているか確認

---

## 📋 問題別の診断フローチャート

```
ファイルアップロードエラー
    │
    ├─ ブラウザコンソールにCORSエラー？
    │   └─ YES → CORS設定を追加（上記セクション1）
    │
    ├─ Status Code 403？
    │   └─ YES → 署名付きURLを使用（上記セクション5）
    │
    ├─ Status Code 413？
    │   └─ YES → ファイルサイズ制限を確認（上記セクション3）
    │
    ├─ bytes が null？
    │   └─ YES → withData: true を確認（上記セクション4）
    │
    ├─ TimeoutException？
    │   └─ YES → タイムアウトを延長（上記セクション7）
    │
    └─ その他のエラー
        └─ デバッグコードを追加して詳細確認
```

---

## 🎯 次のステップ

1. **ブラウザの開発者ツールでエラーを確認**
   - Console と Network タブを確認
   - エラーメッセージとステータスコードを記録

2. **上記の診断フローチャートに従って問題を特定**

3. **該当するセクションの解決策を実施**

4. **デバッグコードを追加して詳細ログを確認**

5. **結果を報告**
   - どのエラーが発生したか
   - どの解決策を試したか
   - 問題が解決したかどうか

---

**作成者**: Claude Code
**最終更新**: 2025年11月10日
**関連ドキュメント**:
- [デプロイ検証ガイド](./DEPLOYMENT_VERIFICATION.md)
- [添付ファイル修正ガイド](./technical/FILE_ATTACHMENT_FIX.md)
- [バグレポート](./BUG_REPORT.md)
