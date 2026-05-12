---
title: "PostgreSQL RLS 完全ガイド — Supabase でのマルチテナントセキュリティ実装"
tags: supabase,postgresql,個人開発,AI
published: true
---

# PostgreSQL RLS 完全ガイド — Supabase でのマルチテナントセキュリティ実装

Row Level Security (RLS) は PostgreSQL の強力な機能。Supabase では必須の設計だ。設定ミスがデータ漏洩に直結するので、正しく理解する。

## RLS の基本

```sql
-- テーブルに RLS を有効化
ALTER TABLE user_notes ENABLE ROW LEVEL SECURITY;

-- これだけだと全行にアクセス不可になる (デフォルト deny)
-- 必ず policy を追加する
```

RLS を有効にすると、policy がない限り誰もデータを読み書きできなくなる。

## 基本パターン: 自分のデータのみアクセス可

```sql
-- SELECT policy: 自分の行のみ読める
CREATE POLICY "user_can_read_own_notes"
  ON user_notes
  FOR SELECT
  USING (auth.uid() = user_id);

-- INSERT policy: 自分のIDで追加できる
CREATE POLICY "user_can_insert_own_notes"
  ON user_notes
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- UPDATE policy: 自分の行のみ更新可
CREATE POLICY "user_can_update_own_notes"
  ON user_notes
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- DELETE policy: 自分の行のみ削除可
CREATE POLICY "user_can_delete_own_notes"
  ON user_notes
  FOR DELETE
  USING (auth.uid() = user_id);
```

`USING` = 読み出し条件 / `WITH CHECK` = 書き込み条件。

## admin ロールで全行アクセス

```sql
-- service_role (管理者) は全行アクセス可
CREATE POLICY "service_role_full_access"
  ON user_notes
  FOR ALL
  USING (auth.jwt() ->> 'role' = 'service_role');
```

Edge Function では `SUPABASE_SERVICE_ROLE_KEY` を使うと RLS をバイパスできる。Flutter クライアントからは `anon` キーで呼ぶため RLS が適用される。

## 共有データパターン: 公開/非公開の切り替え

```sql
-- public_notes テーブル (is_public フラグあり)
CREATE POLICY "public_notes_are_readable_by_all"
  ON public_notes
  FOR SELECT
  USING (is_public = true OR auth.uid() = user_id);

-- 自分の非公開ノートも読めるが、他人の非公開は読めない
```

## チームアクセス: 組織メンバーが共有

```sql
-- members テーブル経由でチームのデータにアクセス
CREATE POLICY "team_members_can_read_team_notes"
  ON team_notes
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM team_members
      WHERE team_members.team_id = team_notes.team_id
        AND team_members.user_id = auth.uid()
    )
  );
```

## Flutter からの呼び出し

```dart
// Flutter: anon キー (RLS が適用される)
final supabase = Supabase.instance.client;

// 自分の notes のみ返ってくる (RLS が自動フィルタ)
final notes = await supabase
    .from('user_notes')
    .select('*');

// INSERT: user_id は WITH CHECK で検証される
await supabase.from('user_notes').insert({
  'title': 'New note',
  'user_id': supabase.auth.currentUser!.id,  // RLS が確認
});
```

## RLS のデバッグ

```sql
-- 特定ユーザーとして policy をテスト
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "user-uuid-here"}';

SELECT * FROM user_notes;  -- policy が適用された結果が返る
RESET role;
```

## よくあるミス

```sql
-- ❌ NG: user_id を INSERT で渡さず、RLS が通らない
INSERT INTO user_notes (title) VALUES ('test');
-- ERROR: new row violates row-level security policy

-- ✅ OK: user_id を必ず含める
INSERT INTO user_notes (title, user_id)
VALUES ('test', auth.uid());

-- さらに良い: DEFAULT を使う
ALTER TABLE user_notes
  ALTER COLUMN user_id SET DEFAULT auth.uid();
```

## まとめ

```
RLS 設計チェックリスト:
  ☑ ENABLE ROW LEVEL SECURITY 設定
  ☑ SELECT / INSERT / UPDATE / DELETE 全て policy を作成
  ☑ auth.uid() を使って自分のデータのみ操作可能に
  ☑ service_role key は Edge Function のみ (Flutter には渡さない)
  ☑ user_id に DEFAULT auth.uid() を設定
```

RLS を正しく設計すれば、アプリ層でのフィルタリングは不要になる。DB 側で安全が保証される。
