-- ============================================================
-- Session 16 開発実績シード (2026-03-26)
-- 登録ユーザー管理機能・ユーザー数カウント修正
-- ============================================================

insert into public.development_achievements
  (title, description, category, achieved_at, impact_level)
values
  (
    'get-admin-users Edge Function を実装',
    'サービスロールキーで auth.users を取得する Edge Function を新規作成。ページネーション対応。user_profiles テーブルとの JOIN でdisplay_name も取得。認証済みユーザーのみ呼び出し可能。',
    'infrastructure',
    '2026-03-26',
    'medium'
  ),
  (
    'ユーザー数カウントを user_profiles → auth.users に修正',
    'get-home-dashboard Edge Function のユーザー数集計を user_profiles（プロフィール未設定ユーザーが含まれない）から auth.admin.listUsers（全登録ユーザーを正確に反映）に変更。実際の登録者数2人→21人の乖離を解消。',
    'infrastructure',
    '2026-03-26',
    'high'
  ),
  (
    'Admin: 登録ユーザー管理 UI を追加',
    'AdminAnalyticsPage に _buildAdminUsersCard() を追加。get-admin-users Edge Function 経由で全登録ユーザー一覧を表示。メール・表示名・登録日・最終ログイン日時・認証プロバイダー（Google/Email）を一覧表示。合計ユーザー数をヘッダーに常時表示。',
    'product',
    '2026-03-26',
    'high'
  );
