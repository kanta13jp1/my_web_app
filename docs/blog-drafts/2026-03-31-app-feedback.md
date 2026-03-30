---
title: FlutterアプリにSupabaseでユーザーフィードバック収集機能を実装した
published: false
emoji: 📬
type: tech
topics: [flutter, supabase, dart, rls]
---

# FlutterアプリにSupabaseでユーザーフィードバック収集機能を実装した

## はじめに

自分株式会社 (https://my-web-app-b67f4.web.app/) は、Notion・Evernote・Slack・MoneyForwardなど21競合SaaSを1つに統合するAIライフマネジメントアプリです。

ユーザーから直接フィードバック（機能要望・バグ報告・ご意見）を収集するために、`app_feedback` テーブルを軸にした仕組みを実装しました。
Flutter Web + Supabase の構成で、RLS（行レベルセキュリティ）を使って一般ユーザーと管理者の権限を分離した実装例を紹介します。

---

## 実装したもの

1. **FeedbackPage** — ログイン済みユーザーがフィードバックを送信できるフォーム画面
2. **FeedbackListPage** — 管理者が全フィードバックを一覧・ステータス管理できる画面
3. **app_feedback テーブル** — Supabase PostgreSQL テーブル + RLS ポリシー
4. **AdminAnalyticsPage への統合** — 管理者ダッシュボードから直接アクセスできるカード追加

---

## DBスキーマ (Supabase Migration)

```sql
CREATE TABLE IF NOT EXISTS app_feedback (
  id bigserial PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  category text NOT NULL DEFAULT 'other', -- 'feature' | 'bug' | 'other'
  content text NOT NULL,
  status text NOT NULL DEFAULT 'new',     -- 'new' | 'reviewed' | 'implemented'
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE app_feedback ENABLE ROW LEVEL SECURITY;

-- ユーザーは自分のフィードバックのみ投稿・閲覧可
CREATE POLICY "users_insert_own_feedback" ON app_feedback
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_select_own_feedback" ON app_feedback
  FOR SELECT USING (auth.uid() = user_id);

-- 管理者は全件閲覧・更新可 (SECURITY DEFINER関数で無限再帰を回避)
CREATE POLICY "admin_select_all_feedback" ON app_feedback
  FOR SELECT USING (is_user_admin(auth.uid()));

CREATE POLICY "admin_update_all_feedback" ON app_feedback
  FOR UPDATE
  USING (is_user_admin(auth.uid()))
  WITH CHECK (is_user_admin(auth.uid()));
```

ポイントは `is_user_admin()` 関数を `SECURITY DEFINER` で定義して、RLSポリシーの無限再帰を防いでいる点です（`user_profiles` テーブル内で `is_admin` カラムを参照）。

---

## Flutter: フィードバック送信フォーム

```dart
Future<void> _submitFeedback() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() => _isSubmitting = true);

  try {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('ログインが必要です');

    await supabase.from('app_feedback').insert({
      'user_id': userId,
      'category': _selectedCategory,
      'content': _contentController.text.trim(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('フィードバックを送信しました！')),
      );
      Navigator.pop(context);
    }
  } catch (e) {
    // エラーハンドリング
  } finally {
    if (mounted) setState(() => _isSubmitting = false);
  }
}
```

カテゴリは `'feature'`（機能要望）、`'bug'`（バグ報告）、`'other'`（その他）の3種類。

---

## Flutter: 管理者ページでのステータス管理

```dart
Future<void> _updateStatus(int id, String newStatus) async {
  await supabase
      .from('app_feedback')
      .update({'status': newStatus}).eq('id', id);

  setState(() {
    final index = _feedbacks.indexWhere((f) => f['id'] == id);
    if (index != -1) _feedbacks[index]['status'] = newStatus;
  });
}
```

管理者のRLSポリシー (`admin_update_all_feedback`) があるため、このクエリは管理者ユーザーのみ成功します。

---

## 詰まったポイント

### RLS の無限再帰

管理者チェックのポリシーで `user_profiles` テーブル内を参照すると、`user_profiles` 自身にもRLSポリシーがある場合に無限再帰が発生します。

解決策として `SECURITY DEFINER` 関数を経由することでRLSをバイパスしつつ、管理者判定を安全に実装しました：

```sql
CREATE OR REPLACE FUNCTION is_user_admin(check_user_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM user_profiles WHERE user_id = check_user_id),
    false
  );
$$;
```

---

## まとめ

- Supabase RLS で一般ユーザーと管理者の権限分離が明確に実装できた
- `SECURITY DEFINER` 関数で管理者チェックの無限再帰問題を解消
- Flutter側はシンプルな `supabase.from().insert()` / `.update()` で完結

今後は `feature_requests` テーブルとの統合や、フィードバックへの管理者返信機能も検討中です。

---

サービスURL: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic
