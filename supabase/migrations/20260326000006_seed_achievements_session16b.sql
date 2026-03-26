-- Session 16b: Admin User Management + Profile Completion UI
-- 1. get-admin-users Edge Function (全登録ユーザー管理・completionPct算出)
-- 2. ProfileCompletionBanner (ホーム画面プロフィール促進バナー)
-- 3. Admin UI: ユーザーカードにプロフィール完成度プログレスバー追加

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'Admin: 登録ユーザー管理 UI (プロフィール完成度表示)',
    'AdminAnalyticsPage に _buildAdminUsersCard() を追加。get-admin-users Edge Function から全auth.usersを取得し、プロフィール完成度プログレスバー（緑/オレンジ/赤）・プロバイダーバッジ・bio/location 表示を実装',
    '2026-03-26'
  ),
  (
    'ProfileCompletionBanner: ホーム画面プロフィール促進バナー',
    'lib/widgets/profile_completion_banner.dart を新規作成。display_name/bio 未設定ユーザーにインディゴ色バナーを表示。「設定する」→/profile-settings CTA と「後で」非表示ボタン付き',
    '2026-03-26'
  )
ON CONFLICT DO NOTHING;
