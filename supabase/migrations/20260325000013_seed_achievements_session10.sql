-- ============================================================
-- Session 10 開発実績シード (2026-03-25)
-- ランディングページ ヒーロー改善・ウェイトリスト・機能リクエスト
-- ============================================================

insert into public.development_achievements
  (title, description, category, achieved_at, impact_level)
values
  (
    'ランディングページ ヒーローセクションを刷新',
    'キャッチコピーを「Notion・Evernote・MoneyForward・Slack を1つに。完全無料。」に変更。実装済み件数バッジ・プライマリCTA「無料で始める（30秒）」・セカンダリCTA「登録なしで1件試す」を新設し、コンバージョン率強化。',
    'marketing',
    '2026-03-25',
    'high'
  ),
  (
    'ランディングページにウェイトリスト登録フォームを追加',
    'newsletter_waitlist テーブル（anon insert 可・service_role select）を作成し、ランディングページに「新機能リリースをメールで受け取る」フォームを追加。未登録ユーザーのメールアドレスを捕捉できるようになった。',
    'marketing',
    '2026-03-25',
    'high'
  ),
  (
    'ランディングページに機能リクエストフォームを追加',
    'feature_requests テーブル（anon insert・open status は公開）を作成し、ランディングページに「こんな機能が欲しい！をリクエスト」フォームを追加。ユーザー要望を直接DB収集できるようになった。',
    'product',
    '2026-03-25',
    'medium'
  );
