-- Session PS#20: 管理者ユーザープロフィール編集機能
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    '管理者: ユーザープロフィール編集機能追加',
    '管理ダッシュボードのユーザー一覧からプロフィールを直接編集可能に。表示名・自己紹介・場所・Twitter/X・GitHub・ウェブサイト・公開設定を管理者権限で更新。user-profile-manager Edge FunctionにPATCHエンドポイント追加。',
    '2026-04-05 15:00:00+00'
  )
ON CONFLICT DO NOTHING;
