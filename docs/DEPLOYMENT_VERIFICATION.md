# デプロイ後の検証ガイド

**作成日**: 2025年11月10日
**目的**: デプロイ後に問題が継続している場合の詳細診断

---

## 🔍 現在の状況

**報告された問題**:
1. ✅ AI機能のエラー - デプロイ済み
2. ❌ **添付ファイル機能のエラー** - デプロイ済みだが問題継続中
3. ❌ **リーダーボードの問題** - デプロイ済みだが問題継続中

---

## 📊 問題1: 添付ファイル機能

### 検証手順

#### ステップ1: データベーステーブルの確認

Supabase Dashboard → SQL Editor で以下を実行:

```sql
-- attachmentsテーブルの存在確認
SELECT
  table_name,
  table_schema
FROM information_schema.tables
WHERE table_name = 'attachments';

-- 結果: 1行返ってくれば正常
-- 結果: 0行の場合、テーブルが作成されていない
```

**期待される結果**:
```
table_name  | table_schema
------------|-------------
attachments | public
```

#### ステップ2: Storageバケットの確認

```sql
-- attachmentsバケットの存在確認
SELECT
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
FROM storage.buckets
WHERE id = 'attachments';

-- 結果: 1行返ってくれば正常
```

**期待される結果**:
```
id          | name        | public | file_size_limit | allowed_mime_types
------------|-------------|--------|-----------------|--------------------
attachments | attachments | false  | 5242880         | {image/jpeg,...}
```

#### ステップ3: Database RLSポリシーの確認

```sql
-- attachmentsテーブルのRLSポリシー確認
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'attachments'
ORDER BY cmd, policyname;

-- 結果: 4つのポリシー（SELECT, INSERT, UPDATE, DELETE）が返ってくれば正常
```

**期待される結果**: 4つのポリシー
1. `Users can view their own attachments` (SELECT)
2. `Users can insert their own attachments` (INSERT)
3. `Users can update their own attachments` (UPDATE)
4. `Users can delete their own attachments` (DELETE)

#### ステップ4: Storage RLSポリシーの確認

```sql
-- Storage objectsのRLSポリシー確認
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'objects'
  AND schemaname = 'storage'
  AND policyname LIKE '%attachments%' OR policyname LIKE '%files%'
ORDER BY cmd, policyname;

-- 結果: 4つのポリシー（SELECT, INSERT, UPDATE, DELETE）が返ってくれば正常
```

**期待される結果**: 4つのポリシー
1. `Users can upload their own files` (INSERT)
2. `Users can view their own files` (SELECT)
3. `Users can update their own files` (UPDATE)
4. `Users can delete their own files` (DELETE)

#### ステップ5: 実際のエラーメッセージの取得

Flutterアプリで添付ファイルをアップロードしようとした時のエラーを確認:

```dart
// lib/services/attachment_service.dart に以下のデバッグコードを追加

static Future<Attachment?> uploadFile({
  required int noteId,
  required PlatformFile file,
}) async {
  try {
    // ... 既存のコード ...

    // Storageにアップロード（デバッグログ追加）
    print('DEBUG: Uploading to storage - Path: $filePath');
    await supabase.storage.from('attachments').uploadBinary(
      filePath,
      bytes,
    );
    print('DEBUG: Upload successful');

    // データベースに記録（デバッグログ追加）
    print('DEBUG: Inserting to database');
    final response = await supabase
        .from('attachments')
        .insert({...})
        .select()
        .single();
    print('DEBUG: Insert successful: ${response}');

    return Attachment.fromJson(response);
  } catch (e, stackTrace) {
    print('ERROR: Upload failed - $e');
    print('STACKTRACE: $stackTrace');
    rethrow;
  }
}
```

**確認すべきエラー**:
- `StorageException: Bucket not found` → バケットが作成されていない
- `StorageException: Permission denied` → Storage RLSポリシーの問題
- `PostgrestException: ... violates row-level security policy` → Database RLSポリシーの問題
- `PostgrestException: relation "public.attachments" does not exist` → テーブルが作成されていない

---

## 📊 問題2: リーダーボード

### 検証手順

#### ステップ1: user_statsテーブルの確認

```sql
-- user_statsテーブルのデータ確認
SELECT
  user_id,
  total_points,
  current_level,
  notes_created,
  created_at
FROM user_stats
ORDER BY total_points DESC
LIMIT 10;

-- 結果: 複数のユーザーが返ってくればデータは存在
```

#### ステップ2: user_stats RLSポリシーの確認

```sql
-- user_statsテーブルのRLSポリシー確認
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'user_stats'
ORDER BY cmd, policyname;

-- 重要: SELECTポリシーのqualが 'true' であることを確認
```

**期待される結果**:
```
policyname                                  | cmd    | qual
--------------------------------------------|--------|------
Anyone can view user stats for leaderboard | SELECT | true
Users can insert their own stats           | INSERT | (auth.uid() = user_id)
Users can update their own stats           | UPDATE | (auth.uid() = user_id)
```

**問題の可能性**:
- SELECTポリシーが存在しない
- SELECTポリシーのqualが `auth.uid() = user_id` になっている（これだと自分だけ表示）
- SELECTポリシーのqualが `true` になっている必要がある（全員表示）

#### ステップ3: 実際のクエリテスト

```sql
-- 現在のユーザーでSELECTできるデータを確認
-- （Supabase Dashboardではauth.uid()が取得できないため、実際のアプリで確認）

-- 代わりに、RLSを一時的に無効化してデータを確認
ALTER TABLE user_stats DISABLE ROW LEVEL SECURITY;

SELECT COUNT(*) as total_users
FROM user_stats;

-- 結果を確認後、必ずRLSを再有効化
ALTER TABLE user_stats ENABLE ROW LEVEL SECURITY;
```

#### ステップ4: リーダーボードマイグレーションの再適用

もしSELECTポリシーが正しくない場合、以下のSQLを実行:

```sql
-- 古いポリシーを削除
DROP POLICY IF EXISTS "Users can view their own stats" ON user_stats;
DROP POLICY IF EXISTS "Anyone can view user stats for leaderboard" ON user_stats;

-- 新しいポリシーを作成（全員が全員の統計を閲覧可能）
CREATE POLICY "Anyone can view user stats for leaderboard"
  ON user_stats FOR SELECT
  USING (true);
```

#### ステップ5: Flutterアプリでのデバッグ

```dart
// lib/services/gamification_service.dart にデバッグコードを追加

Future<List<LeaderboardEntry>> getLeaderboard({
  int limit = 100,
  String orderBy = 'total_points',
}) async {
  try {
    print('DEBUG: Fetching leaderboard...');
    final response = await _supabase
        .from('user_stats')
        .select()
        .order(orderBy, ascending: false)
        .limit(limit);

    print('DEBUG: Response received: ${response.length} users');
    print('DEBUG: First user: ${response.isNotEmpty ? response[0] : "None"}');

    // ... 既存のコード ...
  } catch (e, stackTrace) {
    print('ERROR: Leaderboard fetch failed - $e');
    print('STACKTRACE: $stackTrace');
    return [];
  }
}
```

**確認すべき出力**:
- `Response received: 1 users` → RLSポリシーで自分だけフィルタされている
- `Response received: 2+ users` → 正常（複数ユーザー表示）
- `ERROR: ... violates row-level security policy` → RLSポリシーの問題

---

## 🔧 修正手順

### 添付ファイル問題の修正

#### 問題A: テーブルまたはバケットが存在しない

**解決策**: マイグレーションを再実行

```bash
# 方法1: Supabase CLI
cd /home/user/my_web_app
supabase db reset  # 注意: 開発環境のみ！本番では使用しないこと
supabase db push

# 方法2: Supabase Dashboard
# SQL Editorで supabase/migrations/20251108120000_attachments_complete_setup.sql の内容を実行
```

#### 問題B: Storage RLSポリシーの問題

**症状**: `StorageException: Permission denied`

**解決策**: Storage RLSポリシーを再作成

```sql
-- Storage RLSポリシーを削除
DROP POLICY IF EXISTS "Users can upload their own files" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own files" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own files" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own files" ON storage.objects;

-- 再作成
CREATE POLICY "Users can upload their own files"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users can view their own files"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users can update their own files"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users can delete their own files"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
```

### リーダーボード問題の修正

#### 問題: SELECTポリシーが制限的

**解決策**: SELECTポリシーを全公開に変更

```sql
-- 古いポリシーを削除
DROP POLICY IF EXISTS "Users can view their own stats" ON user_stats;

-- 新しいポリシーを作成
CREATE POLICY "Anyone can view user stats for leaderboard"
  ON user_stats FOR SELECT
  USING (true);
```

---

## ✅ 検証チェックリスト

デプロイ後の確認:

### 添付ファイル機能
- [ ] attachmentsテーブルが存在する
- [ ] attachmentsバケットが存在する
- [ ] Database RLSポリシーが4つ設定されている（SELECT, INSERT, UPDATE, DELETE）
- [ ] Storage RLSポリシーが4つ設定されている（SELECT, INSERT, UPDATE, DELETE）
- [ ] 実際にファイルをアップロードできる
- [ ] アップロードしたファイルが表示される

### リーダーボード機能
- [ ] user_statsテーブルに複数ユーザーのデータが存在する
- [ ] SELECTポリシーが `USING (true)` になっている
- [ ] リーダーボードページで複数ユーザーが表示される
- [ ] 自分のランクが正しく表示される

---

## 📝 トラブルシューティングFAQ

### Q1: マイグレーションを実行したがテーブルが作成されない

**A**: マイグレーションの実行ログを確認してください。エラーが発生している可能性があります。

```bash
# Supabase CLI
supabase db push --debug

# エラーメッセージを確認
```

### Q2: RLSポリシーを作成したが反映されない

**A**: ポリシー名の重複またはテーブル名の誤りの可能性があります。

```sql
-- 既存のポリシーを確認
SELECT policyname FROM pg_policies WHERE tablename = 'your_table_name';

-- 重複している場合は削除してから再作成
DROP POLICY IF EXISTS "policy_name" ON table_name;
```

### Q3: Storageバケットを作成したがアクセスできない

**A**: Storage RLSポリシーが正しく設定されているか確認してください。

```sql
-- storage.objectsのポリシーを確認
SELECT * FROM pg_policies
WHERE schemaname = 'storage' AND tablename = 'objects';
```

---

## 🚀 次のステップ

1. **検証手順を実施**: 上記の検証手順を順番に実行
2. **エラーメッセージを記録**: 具体的なエラーメッセージをメモ
3. **修正手順を適用**: 問題に応じた修正を実施
4. **再検証**: 修正後に動作確認

---

**作成者**: Claude Code
**最終更新**: 2025年11月10日
**関連ドキュメント**:
- [添付ファイル修正ガイド](./technical/FILE_ATTACHMENT_FIX.md)
- [バグレポート](./BUG_REPORT.md)
- [user_stats 406エラー修正](../FIX_USER_STATS_406_ERROR.md)
