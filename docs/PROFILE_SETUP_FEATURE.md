# プロフィール設定機能 実装ドキュメント

**作成日**: 2025年11月11日
**ステータス**: 実装完了、デプロイ待ち

---

## 📋 概要

リーダーボードで全員が「ユーザー」と表示される問題を解決するため、プロフィール設定機能を実装しました。

### 問題

- リーダーボードで全ユーザーが「ユーザー」と表示される
- ユーザーの表示名が設定できない
- user_statsテーブルとuser_profilesテーブルがJOINされていない

### 解決策

1. user_stats_with_profilesビューを作成し、user_statsとuser_profilesをJOIN
2. プロフィール設定ページを作成
3. プロフィール設定サービスを作成
4. ホームページメニューにプロフィール設定を追加

---

## 🔧 実装内容

### 1. データベースマイグレーション

**ファイル**: `supabase/migrations/20251111140000_add_user_names_to_leaderboard.sql`

**内容**:
- `user_stats_with_profiles` ビューを作成
- user_stats、user_profiles、auth.usersをJOIN
- display_nameがnullの場合はemailをuser_nameとして返す
- RLSポリシーを確認・更新（全ユーザーがuser_statsを閲覧可能）

```sql
CREATE OR REPLACE VIEW user_stats_with_profiles AS
SELECT
  us.user_id,
  us.total_points,
  us.current_level,
  us.notes_created,
  us.current_streak,
  us.longest_streak,
  us.notes_edited,
  us.notes_deleted,
  us.categories_created,
  us.tags_created,
  us.achievements_unlocked,
  us.last_activity_date,
  us.created_at,
  us.updated_at,
  COALESCE(up.display_name, au.email) as user_name,
  up.avatar_url
FROM user_stats us
LEFT JOIN user_profiles up ON us.user_id = up.user_id
LEFT JOIN auth.users au ON us.user_id = au.id;
```

### 2. プロフィールサービス

**ファイル**: `lib/services/profile_service.dart`

**機能**:
- プロフィール取得 (`getProfile`, `getCurrentUserProfile`)
- プロフィール更新 (`updateProfile`)
- 個別フィールド更新 (`updateDisplayName`, `updateBio`, `updateAvatarUrl`, `updatePublicStatus`)
- デフォルトプロフィール作成 (`_createDefaultProfile`)
- プロフィール削除 (`deleteProfile`)

**主要メソッド**:
```dart
Future<UserProfile?> getProfile(String userId)
Future<UserProfile?> getCurrentUserProfile()
Future<UserProfile?> updateProfile(UserProfile profile)
Future<bool> updateDisplayName(String userId, String displayName)
Future<bool> updateBio(String userId, String bio)
```

### 3. プロフィール設定ページ

**ファイル**: `lib/pages/profile_settings_page.dart`

**UI要素**:
- アバター画像（プレースホルダー、今後画像アップロード機能を実装予定）
- 表示名入力（必須、50文字以内）
- 自己紹介入力（オプション、200文字以内）
- ウェブサイトURL入力（オプション、http/https必須）
- 場所入力（オプション、50文字以内）
- Twitterハンドル入力（オプション、@付き、15文字以内）
- GitHubハンドル入力（オプション、39文字以内）
- プロフィール公開設定スイッチ
- 保存ボタン

**バリデーション**:
- 表示名：必須、50文字以内
- 自己紹介：200文字以内
- ウェブサイト：http/https必須
- 場所：50文字以内
- Twitterハンドル：@付き、15文字以内
- GitHubハンドル：39文字以内

### 4. ホームページメニューへの追加

**ファイル**: `lib/widgets/home_page/home_app_bar.dart`

**変更内容**:
- `profile_settings_page.dart`をインポート
- PopupMenuにプロフィール設定項目を追加（リーダーボードの後）
- onSelectedハンドラーにプロフィール設定ページへのナビゲーションを追加

**メニュー項目**:
```dart
const PopupMenuItem(
  value: 'profile_settings',
  child: Row(
    children: [
      Icon(Icons.person, color: Colors.blue),
      SizedBox(width: 8),
      Text('プロフィール設定'),
    ],
  ),
),
```

### 5. GamificationServiceの更新

**ファイル**: `lib/services/gamification_service.dart`

**変更内容**:
- `getLeaderboard`メソッドを更新
- `user_stats`テーブルの代わりに`user_stats_with_profiles`ビューを使用
- これにより、リーダーボードにuser_name（表示名）が自動的に含まれる

**変更前**:
```dart
final response = await _supabase
    .from('user_stats')
    .select()
    .order(orderBy, ascending: false)
    .limit(limit);
```

**変更後**:
```dart
final response = await _supabase
    .from('user_stats_with_profiles')
    .select()
    .order(orderBy, ascending: false)
    .limit(limit);
```

### 6. その他の修正

**ファイル**: `lib/pages/document_viewer_page.dart:82`

**内容**:
- `withOpacity(0.1)` → `withValues(alpha: 0.1)` に修正
- 非推奨警告を解消

---

## 📊 影響範囲

### データベース
- ✅ user_stats_with_profilesビューを追加
- ✅ 既存のuser_profilesテーブルを活用
- ✅ RLSポリシーを確認・更新

### バックエンド
- ✅ ProfileServiceを追加
- ✅ GamificationServiceを更新

### フロントエンド
- ✅ ProfileSettingsPageを追加
- ✅ HomeAppBarにメニュー項目を追加
- ✅ LeaderboardPageはそのまま（ビューから自動的にuser_nameを取得）

---

## 🚀 デプロイ手順

### 1. データベースマイグレーション

```bash
cd /home/user/my_web_app
supabase db push
```

### 2. Flutterアプリのビルド

```bash
flutter build web --release
```

### 3. Firebaseへのデプロイ

```bash
firebase deploy --only hosting
```

### 4. 動作確認

1. **プロフィール設定ページにアクセス**
   - ホームページ → メニュー（⋮）→ プロフィール設定
   - 表示名を入力して保存

2. **リーダーボードで確認**
   - ホームページ → メニュー（⋮）→ リーダーボード
   - 自分の表示名が表示されることを確認
   - 他のユーザーの表示名も表示されることを確認

---

## ✅ チェックリスト

デプロイ後の確認項目：

- [ ] user_stats_with_profilesビューが作成されている
- [ ] プロフィール設定ページにアクセスできる
- [ ] 表示名を設定できる
- [ ] プロフィールを保存できる
- [ ] リーダーボードに表示名が表示される
- [ ] 表示名未設定のユーザーはメールアドレスが表示される
- [ ] 自分の順位が正しく表示される
- [ ] withOpacity警告が解消されている

---

## 🔮 今後の拡張

### 短期（1-2週間）
- [ ] アバター画像アップロード機能
- [ ] プロフィール画像のトリミング機能
- [ ] プロフィールプレビュー機能

### 中期（1ヶ月）
- [ ] 他のユーザーのプロフィール閲覧機能
- [ ] プロフィールバッジ機能（アチーブメント表示）
- [ ] プロフィールの公開URL機能

### 長期（3ヶ月）
- [ ] プロフィールカスタマイズ（テーマカラー）
- [ ] プロフィール統計情報の表示
- [ ] ソーシャルメディア連携

---

## 📝 関連ファイル

### 新規作成
- `supabase/migrations/20251111140000_add_user_names_to_leaderboard.sql`
- `lib/services/profile_service.dart`
- `lib/pages/profile_settings_page.dart`
- `docs/PROFILE_SETUP_FEATURE.md`（このファイル）

### 修正
- `lib/services/gamification_service.dart`
- `lib/widgets/home_page/home_app_bar.dart`
- `lib/pages/document_viewer_page.dart`

### 既存（活用）
- `lib/models/user_profile.dart`
- `supabase/migrations/20251107000000_ai_features.sql`（user_profilesテーブル定義）

---

## 🐛 既知の問題

### 1. 画像アップロード未実装
**問題**: アバター画像のアップロード機能がまだ実装されていません。
**回避策**: プレースホルダーアイコンを表示し、「近日実装予定」のメッセージを表示。
**対応予定**: 次回のスプリント

### 2. プロフィール画像の表示
**問題**: リーダーボードやコメントでアバター画像を表示する機能が未実装。
**回避策**: user_stats_with_profilesビューにavatar_urlカラムを含めているため、将来の実装が容易。
**対応予定**: プロフィール閲覧機能と同時に実装

---

## 🎯 成功指標（KPI）

### ユーザー体験
- プロフィール設定完了率: 目標 80%
- リーダーボードでの表示名表示率: 目標 100%

### 技術指標
- マイグレーション成功率: 100%
- ページロード時間: 3秒以内
- エラー発生率: 1%以下

---

**最終更新**: 2025年11月11日
**作成者**: Claude Code
**次回レビュー**: デプロイ後の動作確認
