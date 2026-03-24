# リーダーボード問題の詳細調査

**作成日**: 2025年11月10日
**ステータス**: デプロイ済み、問題継続中

---

## 🔍 問題の概要

**症状**: リーダーボードに自分しか表示されない

**ユーザー報告**:
- マイグレーション `20251109120000_fix_user_stats_leaderboard_rls.sql` はデプロイ済み
- しかし、リーダーボードの問題は継続している

---

## 🧪 診断手順

### ステップ1: user_statsテーブルのデータ確認

Supabase Dashboard → SQL Editor で以下を実行:

```sql
-- user_statsテーブルに複数ユーザーのデータが存在するか確認
SELECT
  user_id,
  total_points,
  current_level,
  notes_created,
  created_at
FROM user_stats
ORDER BY total_points DESC
LIMIT 10;
```

**期待される結果**:
- 2行以上のデータが返ってくる（複数ユーザーが存在）

**もし1行しか返ってこない場合**:
- **原因**: データ自体が存在しない
- **解決策**: 他のユーザーアカウントを作成してデータを確認

---

### ステップ2: RLSポリシーの確認

```sql
-- user_statsテーブルのRLSポリシーを確認
SELECT
  schemaname,
  tablename,
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'user_stats'
ORDER BY cmd, policyname;
```

**期待される結果**:

| policyname | cmd | qual | with_check |
|   :--------- -  -  |   :- - - -  | : - ----  | :---- ------- |
| Anyone can view user stats for leaderboard | SELECT | true | (NULL) |
| Users can insert their own stats | INSERT | (NULL) | (auth.uid() = user_id) |
| Users can update their own stats | UPDATE | (auth.uid() = user_id) | (auth.uid() = user_id) |

**重要**: SELECTポリシーの`qual`カラムが`true`であることを確認

**もし`qual`が`(auth.uid() = user_id)`の場合**:
- **原因**: 古いポリシーがまだ残っている
- **解決策**: 以下のステップ3を実行

---

### ステップ3: ポリシーの再作成

古いポリシーが残っている場合、以下のSQLを実行:

```sql
-- ステップ3-1: すべての既存ポリシーを削除
DROP POLICY IF EXISTS "Users can view their own stats" ON user_stats;
DROP POLICY IF EXISTS "Anyone can view user stats for leaderboard" ON user_stats;
DROP POLICY IF EXISTS "Users can view all stats for leaderboard" ON user_stats;

-- ステップ3-2: 新しいポリシーを作成
CREATE POLICY "Anyone can view user stats for leaderboard"
  ON user_stats FOR SELECT
  USING (true);

-- ステップ3-3: 確認
SELECT policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'user_stats' AND cmd = 'SELECT';
```

**期待される出力**:
```
policyname                                  | cmd    | qual
--------------------------------------------|--------|------
Anyone can view user stats for leaderboard | SELECT | true
```

---

### ステップ4: Flutterアプリでのテスト

```dart
// lib/pages/leaderboard_page.dart または lib/services/gamification_service.dart にデバッグコードを追加

Future<List<LeaderboardEntry>> getLeaderboard({
  int limit = 100,
  String orderBy = 'total_points',
}) async {
  try {
    print('🔍 DEBUG: Fetching leaderboard data...');

    final response = await _supabase
        .from('user_stats')
        .select()
        .order(orderBy, ascending: false)
        .limit(limit);

    print('✅ DEBUG: Received ${(response as List).length} users');

    if ((response as List).isNotEmpty) {
      print('📊 DEBUG: First user: ${response[0]}');
    }

    // ... 既存のコード ...
  } catch (e, stackTrace) {
    print('❌ ERROR: Leaderboard fetch failed');
    print('Error: $e');
    print('StackTrace: $stackTrace');
    return [];
  }
}
```

**デバッグ出力の確認**:

1. **「Received 1 users」の場合**:
   - RLSポリシーで自分のデータだけがフィルタされている
   - ステップ3を再実行

2. **「Received 2+ users」の場合**:
   - RLSポリシーは正常
   - UIまたはデータマッピングの問題の可能性

3. **「ERROR: ... violates row-level security policy」の場合**:
   - RLSポリシーが厳しすぎる
   - ステップ3を実行

---

### ステップ5: RLSの一時的な無効化テスト（診断のみ）

**警告**: これは診断目的のみで、本番環境では短時間のみ実行すること

```sql
-- RLSを一時的に無効化
ALTER TABLE user_stats DISABLE ROW LEVEL SECURITY;

-- アプリでリーダーボードを確認
-- 複数ユーザーが表示されれば、RLSポリシーの問題

-- すぐにRLSを再有効化（必須！）
ALTER TABLE user_stats ENABLE ROW LEVEL SECURITY;
```

**結果の解釈**:
- RLS無効化で複数ユーザーが表示される → RLSポリシーの問題
- RLS無効化でも1人しか表示されない → データまたはUIの問題

---

## 🔧 考えられる問題と解決策

### 問題1: 古いポリシーが残っている

**症状**:
- マイグレーションを実行したが、SELECTポリシーの`qual`が`(auth.uid() = user_id)`のまま

**原因**:
- `DROP POLICY IF EXISTS`が失敗している
- ポリシー名が微妙に異なる

**解決策**:
```sql
-- すべてのuser_statsのSELECTポリシーを強制削除
DO $$
DECLARE
  pol record;
BEGIN
  FOR pol IN
    SELECT policyname
    FROM pg_policies
    WHERE tablename = 'user_stats' AND cmd = 'SELECT'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON user_stats', pol.policyname);
  END LOOP;
END;
$$;

-- 新しいポリシーを作成
CREATE POLICY "Anyone can view user stats for leaderboard"
  ON user_stats FOR SELECT
  USING (true);
```

### 問題2: マイグレーションが実行されていない

**症状**:
- ポリシーが全く存在しない、または古いポリシーのみ存在

**原因**:
- `supabase db push`が失敗している
- マイグレーションファイルが読み込まれていない

**解決策**:
```bash
# ローカルで確認
cd /home/user/my_web_app

# マイグレーションファイルの存在確認
ls -la supabase/migrations/20251109120000_fix_user_stats_leaderboard_rls.sql

# マイグレーション状態の確認
supabase migration list

# 再デプロイ
supabase db push
```

### 問題3: キャッシュの問題

**症状**:
- ポリシーは正しいが、アプリで反映されない

**原因**:
- Supabaseのキャッシュ
- アプリのキャッシュ

**解決策**:
1. **Supabase側**: ポリシーを再作成（上記ステップ3）
2. **アプリ側**: アプリを再起動またはキャッシュクリア

### 問題4: データが実際に1ユーザーしかない

**症状**:
- ポリシーは正しいが、1人しか表示されない

**原因**:
- user_statsテーブルに実際に1ユーザーのデータしかない

**確認方法**:
```sql
-- RLSを無視してデータを確認（管理者権限が必要）
SELECT COUNT(*) as total_users FROM user_stats;
```

**解決策**:
- 他のユーザーアカウントを作成
- サンプルデータを挿入（開発環境のみ）

---

## ✅ 推奨される修正手順

### 手順1: 現状確認
```sql
-- ポリシーの確認
SELECT policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'user_stats'
ORDER BY cmd;

-- データの確認
SELECT COUNT(*) as user_count FROM user_stats;
```

### 手順2: ポリシーの強制再作成
```sql
-- すべてのSELECTポリシーを削除
DROP POLICY IF EXISTS "Users can view their own stats" ON user_stats;
DROP POLICY IF EXISTS "Anyone can view user stats for leaderboard" ON user_stats;
DROP POLICY IF EXISTS "Users can view all stats for leaderboard" ON user_stats;

-- 新しいポリシーを作成
CREATE POLICY "Anyone can view user stats for leaderboard"
  ON user_stats FOR SELECT
  USING (true);
```

### 手順3: 動作確認
```sql
-- 現在のユーザーでSELECTできるか確認
SELECT user_id, total_points
FROM user_stats
ORDER BY total_points DESC
LIMIT 5;

-- 期待: 複数ユーザーのデータが返ってくる
```

### 手順4: アプリで確認
- Flutterアプリを再起動
- リーダーボードページを開く
- 複数ユーザーが表示されることを確認

---

## 📝 チェックリスト

デプロイ後の確認:

- [ ] user_statsテーブルに複数ユーザーのデータが存在する（2人以上）
- [ ] SELECTポリシーが存在する
- [ ] SELECTポリシーの`qual`が`true`である
- [ ] INSERTポリシーが`auth.uid() = user_id`である
- [ ] UPDATEポリシーが`auth.uid() = user_id`である
- [ ] Flutterアプリで複数ユーザーが表示される
- [ ] 自分のランクが正しく表示される

---

## 🚀 次のステップ

1. **診断手順を実施**: ステップ1〜5を順番に実行
2. **問題を特定**: 上記の「考えられる問題」のどれに該当するか確認
3. **修正を適用**: 推奨される修正手順を実行
4. **動作確認**: アプリで複数ユーザーが表示されることを確認

---

**作成者**: Claude Code
**最終更新**: 2025年11月10日
**関連ドキュメント**:
- [デプロイ検証ガイド](./DEPLOYMENT_VERIFICATION.md)
- [バグレポート](./BUG_REPORT.md)
- [user_stats 406エラー修正](../FIX_USER_STATS_406_ERROR.md)
