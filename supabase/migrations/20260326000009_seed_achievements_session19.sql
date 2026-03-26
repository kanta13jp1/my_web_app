-- Session 19: 機能リクエスト通知・UUID バグ修正・LP フローティング CTA

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'notify-feature-request Edge Function 実装',
    '管理者がステータスを done/in_progress に変更した際、投稿者へ Resend API でメール通知。notify-feature-request Edge Function を新規作成。CI/CD に自動デプロイ追加',
    '2026-03-26'
  ),
  (
    'Admin: 機能リクエスト UUID バグ修正・通知ダイアログ追加',
    'req["id"] as int → req["id"]?.toString() に修正。ステータス変更後に通知確認ダイアログを表示する UX を追加',
    '2026-03-26'
  ),
  (
    'LP: 固定フローティング CTA ボタン追加',
    'LandingPage に FloatingActionButton.extended「無料で始める」を追加。常時表示され、タップで登録フォームへスクロール',
    '2026-03-26'
  )
ON CONFLICT DO NOTHING;
