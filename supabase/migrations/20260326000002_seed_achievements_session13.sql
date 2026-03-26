-- ============================================================
-- Session 13 開発実績シード (2026-03-26)
-- ウェイトリスト通知 Edge Function・通知送信UI
-- ============================================================

insert into public.development_achievements
  (title, description, category, achieved_at, impact_level)
values
  (
    'send-waitlist-notification Edge Function を実装',
    'Resend API を使用したメール一括送信 Edge Function を新規作成。newsletter_waitlist テーブルの全登録メールに一斉送信。HTMLメールテンプレート（ヘッダー/本文/配信停止リンク）内蔵。認証済みユーザーのみ呼び出し可能。CI/CD に自動デプロイ追加。',
    'infrastructure',
    '2026-03-26',
    'high'
  ),
  (
    'Admin: ウェイトリスト通知送信 UI を追加',
    'AdminAnalyticsPage のウェイトリストカードに「通知送信」ボタンを追加。件名・本文を入力するダイアログから send-waitlist-notification Edge Function を呼び出し、送信件数をスナックバーで確認できる。',
    'product',
    '2026-03-26',
    'medium'
  );
