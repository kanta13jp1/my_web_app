# 添付ファイル機能の修正ガイド

**作成日**: 2025年11月8日
**問題**: デプロイ先で添付ファイル機能が動作しない
**原因**: Supabase StorageとDatabaseの設定が不足

---

## 🚨 問題の詳細

### 症状
- デプロイ先（本番環境）で添付ファイルのアップロードができない
- エラー: `LateInitializationError: Field '' has not been initialized.`
- 開発環境でも発生する可能性がある

### 根本原因

#### 1. **Supabaseクライアントの初期化エラー** 🔴 **最優先**
**問題のコード** (`lib/main.dart:33`):
```dart
final supabase = Supabase.instance.client;  // ← 初期化前にアクセス
```

この変数は`main()`関数の外側で宣言されているため、`Supabase.initialize()`が完了する**前**に評価されてしまい、`LateInitializationError`が発生していました。

**修正**:
```dart
// ゲッターに変更（呼ばれるたびに取得）
SupabaseClient get supabase => Supabase.instance.client;
```

#### 2. **attachmentsテーブルが存在しない**
   - マイグレーションファイルに定義がない

#### 3. **Supabase Storageのattachmentsバケットが作成されていない**
   - ストレージバケットの設定がない

#### 4. **Storage RLS（Row Level Security）ポリシーが設定されていない**
   - ファイルのアップロード/ダウンロード権限が未設定

---

## ✅ 解決策

### ステップ0: Supabaseクライアントの初期化修正 🔴 **最優先**

**ファイル**: `lib/main.dart`

**修正内容**:
```dart
// 旧コード（削除）
final supabase = Supabase.instance.client;

// 新コード（追加）
SupabaseClient get supabase => Supabase.instance.client;
```

**理由**:
- `final`変数は宣言時に即座に評価される
- `get`ゲッターは呼ばれるたびに評価される
- これにより`Supabase.initialize()`完了後にのみアクセス可能

**影響範囲**:
- この修正により、アプリ全体で`supabase`を使用している箇所すべてが正常に動作
- コードの変更は不要（使用方法は同じ）

✅ **この修正により`LateInitializationError`が完全に解決します**

---

### ステップ1: マイグレーションファイルの適用

マイグレーションファイル `20251108_attachments_setup.sql` を作成しました。
このファイルには以下が含まれています：

1. **attachmentsテーブルの作成**
   - note_id, user_id, file_name, file_path, file_size, file_type, mime_type
   - インデックス設定

2. **Database RLSポリシー**
   - ユーザーは自分の添付ファイルのみアクセス可能
   - SELECT, INSERT, UPDATE, DELETE ポリシー

3. **Storageバケットの作成**
   - `attachments` バケット
   - プライベート設定（public = false）
   - ファイルサイズ制限: 5MB
   - 許可するMIMEタイプ: JPEG, PNG, GIF, WebP, PDF

4. **Storage RLSポリシー**
   - ユーザーIDベースのフォルダ構造でアクセス制御
   - ユーザーは自分のフォルダ内のみアクセス可能

5. **便利な関数**
   - `get_attachment_stats()` - 添付ファイル統計取得

### ステップ2: Supabaseへのマイグレーション適用

#### 方法A: Supabase CLI（推奨）

```bash
# Supabase CLIがインストールされている場合
cd /home/user/my_web_app

# マイグレーションを適用
supabase db push

# または特定のマイグレーションを実行
supabase migration up
```

#### 方法B: Supabase Dashboard（手動）

1. Supabase Dashboard にログイン
   - https://app.supabase.com/

2. プロジェクトを選択

3. SQL Editor を開く

4. `supabase/migrations/20251108_attachments_setup.sql` の内容をコピー＆ペースト

5. 「Run」をクリックして実行

### ステップ3: 動作確認

```dart
// テストコード例
void testAttachmentFeature() async {
  // 1. ファイル選択
  final file = await AttachmentService.pickFile();
  if (file == null) return;

  // 2. アップロード
  final attachment = await AttachmentService.uploadFile(
    noteId: 1, // テスト用のメモID
    file: file,
  );

  print('Uploaded: ${attachment?.fileName}');

  // 3. 取得
  final attachments = await AttachmentService.getAttachments(1);
  print('Total attachments: ${attachments.length}');

  // 4. 公開URL取得
  if (attachments.isNotEmpty) {
    final url = AttachmentService.getPublicUrl(attachments.first.filePath);
    print('Public URL: $url');
  }
}
```

---

## 📊 データベース設計

### attachmentsテーブル

| カラム名 | 型 | 説明 |
|:---------|:---|:-----|
| id | BIGSERIAL | 主キー |
| note_id | BIGINT | メモID（外部キー） |
| user_id | UUID | ユーザーID（外部キー） |
| file_name | TEXT | 元のファイル名 |
| file_path | TEXT | Storageのパス（一意） |
| file_size | BIGINT | ファイルサイズ（バイト） |
| file_type | TEXT | ファイルタイプ（image/pdf/other） |
| mime_type | TEXT | MIMEタイプ |
| created_at | TIMESTAMPTZ | 作成日時 |
| updated_at | TIMESTAMPTZ | 更新日時 |

### ファイルパス構造

```
attachments/
  └── {user_id}/
      └── {note_id}/
          └── {timestamp}_{filename}
```

例:
```
attachments/
  └── 550e8400-e29b-41d4-a716-446655440000/
      └── 123/
          └── 1699459200000_example.jpg
```

---

## 🔒 セキュリティ設計

### Database RLS

**原則**: ユーザーは自分の添付ファイル（`user_id` が一致）のみアクセス可能

```sql
-- SELECT例
CREATE POLICY "Users can view their own attachments"
  ON public.attachments
  FOR SELECT
  USING (auth.uid() = user_id);
```

### Storage RLS

**原則**: ユーザーは自分のフォルダ内のファイルのみアクセス可能

```sql
-- SELECT例
CREATE POLICY "Users can view their own files"
  ON storage.objects
  FOR SELECT
  USING (
    bucket_id = 'attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
```

**フォルダ構造によるアクセス制御**:
- `550e8400-e29b-41d4-a716-446655440000/123/file.jpg`
  - フォルダの第1階層 = `user_id`
  - 第2階層 = `note_id`
  - この構造により、他のユーザーのファイルへのアクセスを防止

---

## 🎯 制限事項

### ファイルサイズ制限
- **最大ファイルサイズ**: 5MB
- コード: `AttachmentService.maxFileSize = 5 * 1024 * 1024`
- Database: `file_size_limit = 5242880` (Storage buckets)

### 許可されるファイル形式

**画像**:
- JPEG (.jpg, .jpeg)
- PNG (.png)
- GIF (.gif)
- WebP (.webp)

**ドキュメント**:
- PDF (.pdf)

### 変更方法

```dart
// lib/services/attachment_service.dart

// ファイルサイズ制限を変更
static const int maxFileSize = 10 * 1024 * 1024; // 10MBに変更

// 許可する拡張子を変更
static const List<String> allowedExtensions = [
  'jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf',
  'doc', 'docx', 'xls', 'xlsx', // Office文書を追加
];
```

**注意**: コードを変更した場合、マイグレーションファイルの `allowed_mime_types` も更新する必要があります。

```sql
-- supabase/migrations/20251108_attachments_setup.sql

-- bucketの設定を更新
UPDATE storage.buckets
SET allowed_mime_types = ARRAY[
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/gif',
  'image/webp',
  'application/pdf',
  'application/msword',  -- .doc
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document'  -- .docx
]::text[]
WHERE id = 'attachments';
```

---

## 🔍 トラブルシューティング

### 問題1: アップロード時に「Permission denied」エラー

**原因**:
- Storage RLSポリシーが正しく設定されていない
- ユーザーが認証されていない

**解決策**:
```bash
# Supabase Dashboardで確認
# Storage → attachments → Policies
# 「Users can upload their own files」ポリシーが存在することを確認
```

### 問題2: 「Bucket not found」エラー

**原因**:
- attachmentsバケットが作成されていない

**解決策**:
```sql
-- SQL Editorで実行
SELECT * FROM storage.buckets WHERE id = 'attachments';

-- 結果が空の場合、マイグレーションを再実行
```

### 問題3: ファイルが表示されない

**原因**:
- 公開URLの取得に失敗
- ファイルパスが間違っている

**解決策**:
```dart
// デバッグコード
final filePath = attachment.filePath;
print('File path: $filePath');

try {
  final signedUrl = await AttachmentService.getSignedUrl(filePath);
  print('Signed URL: $signedUrl');
} catch (e) {
  print('Error: $e');
}
```

### 問題4: Flutter Webでファイル選択ダイアログが開かない

**原因**:
- file_pickerパッケージの問題
- ブラウザの権限設定

**解決策**:
```yaml
# pubspec.yaml
dependencies:
  file_picker: ^6.0.0  # 最新バージョンを確認
```

```dart
// Web用の設定を確認
final result = await FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf'],
  withData: true, // Web用には必須
);
```

---

## 📈 今後の改善案

### 短期（1-2週間）
- [ ] アップロード進捗表示
- [ ] 画像プレビュー機能の強化
- [ ] エラーハンドリングの改善
- [ ] ファイル形式のアイコン表示

### 中期（1-2ヶ月）
- [ ] 画像のリサイズ・圧縮（Edge Functions）
- [ ] PDFサムネイル生成
- [ ] ドラッグ&ドロップアップロード
- [ ] 一括アップロード機能

### 長期（3-6ヶ月）
- [ ] ファイルバージョン管理
- [ ] 共有リンク生成
- [ ] OCR機能（画像からテキスト抽出）
- [ ] 動画・音声ファイル対応

---

## 📚 関連ドキュメント

- [Supabase Storage Documentation](https://supabase.com/docs/guides/storage)
- [Row Level Security (RLS)](https://supabase.com/docs/guides/auth/row-level-security)
- [file_picker Package](https://pub.dev/packages/file_picker)

---

## ✅ チェックリスト

デプロイ前の確認事項：

- [ ] マイグレーションファイル `20251108_attachments_setup.sql` を作成
- [ ] Supabase Dashboardでマイグレーションを実行
- [ ] attachmentsテーブルが存在することを確認
- [ ] attachmentsバケットが存在することを確認
- [ ] Database RLSポリシーが設定されていることを確認
- [ ] Storage RLSポリシーが設定されていることを確認
- [ ] 開発環境で動作テスト
- [ ] 本番環境で動作テスト

---

**作成日**: 2025年11月8日
**最終更新**: 2025年11月8日
**ステータス**: マイグレーション作成完了 ⏳ デプロイ待ち
