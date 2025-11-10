# デプロイ環境問題診断ガイド 🔍

**作成日**: 2025年11月10日
**最終更新**: 2025年11月10日
**目的**: Web版デプロイ後の問題を診断・修正するためのガイド

---

## 📋 概要

このドキュメントは、ローカル環境では正常に動作するが、Web版デプロイ後に問題が発生する場合の診断・修正手順をまとめたものです。

---

## 🔴 問題1: リーダーボードに自分しか表示されない

### 症状
- リーダーボードページで自分のデータしか表示されない
- 他のユーザーのスコアが見えない

### 診断手順

#### ステップ1: データベースのユーザー数を確認

Supabaseダッシュボードで以下のSQLを実行：

```sql
-- user_statsテーブルのユーザー数を確認
SELECT COUNT(*) as user_count FROM user_stats;

-- 全ユーザーのstatsを確認
SELECT user_id, total_points, current_level, notes_created
FROM user_stats
ORDER BY total_points DESC
LIMIT 10;
```

**判定**:
- `user_count` が 1 → **実際に1ユーザーしかいない**（データ問題）
- `user_count` が 2以上 → **RLSポリシー問題の可能性**

#### ステップ2: RLSポリシーの確認

```sql
-- user_statsテーブルのSELECTポリシーを確認
SELECT policyname, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'user_stats' AND cmd = 'SELECT';
```

**期待される結果**:
| policyname | cmd | qual | with_check |
|:-----------|:----|:-----|:-----------|
| Anyone can view user stats for leaderboard | SELECT | true | NULL |

**判定**:
- ポリシーが存在しない → **マイグレーション未適用**
- `qual` が `true` 以外 → **ポリシー設定ミス**
- ポリシーが複数存在 → **古いポリシーが残っている**

#### ステップ3: マイグレーションの確認

```sql
-- 適用済みマイグレーションを確認
SELECT * FROM supabase_migrations.schema_migrations
ORDER BY version DESC
LIMIT 10;
```

`20251109120000` のマイグレーションが適用されているか確認。

### 修正手順

#### 修正A: RLSポリシーの再作成

```sql
-- 既存のSELECTポリシーをすべて削除
DROP POLICY IF EXISTS "Users can view their own stats" ON user_stats;
DROP POLICY IF EXISTS "Anyone can view user stats for leaderboard" ON user_stats;
DROP POLICY IF EXISTS "Enable read access for all users" ON user_stats;

-- 新しいポリシーを作成
CREATE POLICY "Anyone can view user stats for leaderboard"
  ON user_stats FOR SELECT
  USING (true);
```

#### 修正B: マイグレーションの再適用

ローカル環境から：

```bash
supabase db push
```

または、Supabaseダッシュボードから直接SQLを実行。

#### 修正C: キャッシュのクリア

1. ブラウザのハードリフレッシュ（Ctrl+Shift+R / Cmd+Shift+R）
2. ブラウザのキャッシュをクリア
3. Supabaseダッシュボード → Settings → API → Connection pooling を一時的にオフ/オン

### 確認

修正後、以下のコマンドで確認：

```sql
-- 認証なしでデータを取得できるか確認
SELECT user_id, total_points FROM user_stats ORDER BY total_points DESC LIMIT 5;
```

---

## 🔴 問題2: 添付ファイル機能がエラーになる

### 症状
- ローカル環境では正常に動作
- Web版デプロイ後、ファイルアップロードボタンを押すとエラー

### 診断手順

#### ステップ1: ブラウザコンソールのエラーを確認

1. ブラウザで `F12` を押して開発者ツールを開く
2. **Console** タブを開く
3. ファイルアップロードボタンをクリック
4. エラーメッセージを記録

**エラーパターンと原因**:

| エラーメッセージ | 原因 | 修正先 |
|:----------------|:-----|:-------|
| `CORS policy` | CORS設定不足 | Supabase Storage |
| `LateInitializationError` | file_picker初期化問題 | コード |
| `403 Forbidden` | 署名付きURL必要 | コード or Storage |
| `bytes is null` | withData未設定 | コード |
| `Failed to fetch` | ネットワーク問題 | 環境 |

#### ステップ2: Network タブの確認

1. 開発者ツールの **Network** タブを開く
2. ファイルアップロードを実行
3. 失敗したリクエストを確認
4. **Status Code** を確認

**Status Code別の対処**:

| Status Code | 原因 | 対処 |
|:------------|:-----|:-----|
| 0 | CORS問題 | CORS設定 |
| 403 | 認証/RLS問題 | RLS確認 |
| 413 | ファイルサイズ超過 | サイズ制限確認 |
| 500 | サーバーエラー | ログ確認 |

### 修正手順

#### 修正A: CORS設定（最も可能性が高い）

Supabaseダッシュボード:

1. **Storage** → **attachments** バケット → **Settings**
2. **CORS** タブを開く
3. 以下を追加:

```json
[
  {
    "allowedOrigins": [
      "https://your-deployed-domain.com",
      "http://localhost:*"
    ],
    "allowedMethods": ["GET", "POST", "PUT", "DELETE"],
    "allowedHeaders": ["*"],
    "maxAge": 3600
  }
]
```

**重要**: `your-deployed-domain.com` を実際のデプロイ先ドメインに置き換えてください。

#### 修正B: 署名付きURLの使用

`lib/services/attachment_service.dart` を確認:

```dart
// 現在の実装
final url = supabase.storage.from('attachments').getPublicUrl(filePath);

// 署名付きURLに変更（バケットがプライベートの場合）
final url = await supabase.storage.from('attachments').createSignedUrl(
  filePath,
  60 * 60 * 24, // 24時間有効
);
```

#### 修正C: file_pickerの初期化確認

`lib/services/attachment_service.dart` の `pickFile()` メソッドを確認:

```dart
// withData: true が設定されているか確認（Web必須）
final result = await FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf'],
  withData: true, // ← これが必須
  allowMultiple: false,
);
```

#### 修正D: RLSポリシーの確認

```sql
-- attachmentsテーブルのポリシーを確認
SELECT policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'attachments';
```

**期待される結果**:
- INSERT: `auth.uid() = user_id`
- SELECT: `auth.uid() = user_id`
- DELETE: `auth.uid() = user_id`

#### 修正E: Storageバケットの設定確認

Supabaseダッシュボード:

1. **Storage** → **attachments** バケット
2. **Settings** タブ
3. 以下を確認:
   - **Public bucket**: OFF（プライベートが推奨）
   - **File size limit**: 5MB
   - **Allowed MIME types**: `image/*,application/pdf`

### 確認

修正後:
1. ブラウザのキャッシュをクリア
2. ファイルアップロードを再テスト
3. Console と Network タブでエラーがないことを確認

---

## 🔴 問題3: ドキュメントが表示されない

### 症状
- ドキュメント一覧は表示される
- ドキュメントを開くとエラー

### 診断手順

#### ステップ1: エラーメッセージの確認

ブラウザコンソールでエラーを確認。

**エラーパターン**:
- `Unable to load asset` → アセットがビルドに含まれていない
- `404 Not Found` → ファイルパスが間違っている
- `null` → ファイルが存在しない

#### ステップ2: ビルド出力の確認

```bash
# ビルドディレクトリの確認
ls -la build/web/assets/
ls -la build/web/assets/docs/
```

`docs/` ディレクトリとその中身が含まれているか確認。

### 修正手順

#### 修正A: pubspec.yaml の確認

`pubspec.yaml` の `assets` セクションを確認:

```yaml
flutter:
  assets:
    - docs/
    - docs/release-notes/
    - docs/roadmaps/
    - docs/user-docs/
    - docs/session-summaries/
    - docs/technical/
```

#### 修正B: document_service.dart の更新

`lib/services/document_service.dart` の `_documentFiles` マップを確認し、実際に存在するファイルのみを記載。

#### 修正C: 再ビルド

```bash
flutter clean
flutter pub get
flutter build web
```

### 確認

1. `build/web/assets/docs/` にファイルが存在することを確認
2. デプロイ後、ドキュメントが表示されることを確認

---

## 🔧 一般的なデバッグ手順

### 環境変数の確認

デプロイ先（Firebase Hosting / Netlify / Vercel）で以下の環境変数が設定されているか確認:

```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

### ローカルとの差分確認

1. **ローカル環境でWeb版をビルド**:
   ```bash
   flutter build web
   flutter run -d chrome
   ```
2. 同じ問題が発生するか確認
3. 発生する場合 → コード問題
4. 発生しない場合 → デプロイ環境問題

### ログの確認

#### Supabaseログ

Supabaseダッシュボード → **Logs** → **Postgres Logs**, **API Logs**

#### ブラウザログ

開発者ツール → **Console** タブ

---

## 📊 チェックリスト

修正前に以下を確認:

### デプロイ前
- [ ] `flutter build web` でエラーがないか
- [ ] `pubspec.yaml` のアセット設定が正しいか
- [ ] ローカルWeb版で動作するか

### デプロイ後
- [ ] 環境変数が設定されているか
- [ ] ブラウザコンソールにエラーがないか
- [ ] Network タブでリクエストが成功しているか

### データベース
- [ ] RLSポリシーが正しく設定されているか
- [ ] マイグレーションが適用されているか
- [ ] テストデータが存在するか

### Storage（添付ファイル機能）
- [ ] バケットが作成されているか
- [ ] CORS設定がされているか
- [ ] RLSポリシーが正しいか

---

## 🔗 関連ドキュメント

- [Web版デプロイ問題](./WEB_DEPLOYMENT_ISSUES.md)
- [バグレポート](./BUG_REPORT.md)
- [リーダーボード問題詳細](./BUG_REPORT_LEADERBOARD_ISSUE.md)
- [添付ファイル修正ガイド](./technical/FILE_ATTACHMENT_FIX.md)

---

**最終更新**: 2025年11月10日
**次回レビュー**: 問題発生時
**作成者**: Claude Code
