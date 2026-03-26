-- ============================================================
-- Session 12 開発実績シード (2026-03-26)
-- Zenn 記事公開・管理画面機能リクエスト管理・ウェイトリスト管理
-- ============================================================

insert into public.development_achievements
  (title, description, category, achieved_at, impact_level)
values
  (
    'Zenn 技術ブログ第1弾を公開',
    'docs/zenn_growth_dashboard_20260325.md の published を true に変更。FlutterとSupabase Edge Functionsで13競合を打倒するグロースダッシュボードを作った話を公開。Zenn からの有機流入による新規登録者獲得を狙う。',
    'marketing',
    '2026-03-26',
    'high'
  ),
  (
    'Zenn 技術ブログ第2弾を作成（ユーザー獲得施策編）',
    'docs/zenn_community_growth_20260325.md を新規作成。LP全面刷新・価格比較・ウェイトリスト・機能リクエスト公開ページの実装解説記事。Supabase anon RLS活用・flutter analyze 0件維持のノウハウを公開。',
    'marketing',
    '2026-03-26',
    'high'
  ),
  (
    'Admin: 機能リクエスト管理UI を追加',
    'AdminAnalyticsPage に _buildFeatureRequestsAdminCard() を実装。機能リクエスト一覧を投票数順に表示し、ステータス（open / in_progress / done / rejected）をPopupMenuで変更可能。上位3件はゴールドハイライト表示。',
    'product',
    '2026-03-26',
    'medium'
  ),
  (
    'Admin: メールウェイトリスト管理UI を追加',
    'AdminAnalyticsPage に _buildWaitlistCard() を実装。newsletter_waitlist テーブルから登録メールアドレス・ソース・登録日時を一覧表示。登録者数の可視化とフォローアップ計画立案に活用。',
    'product',
    '2026-03-26',
    'medium'
  );
