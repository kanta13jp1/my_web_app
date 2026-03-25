-- ============================================================
-- Session 9 開発実績シード (2026-03-25)
-- Admin Analytics weekly digest UI・sitemap 拡充
-- ============================================================

insert into public.development_achievements
  (title, description, category, achieved_at, impact_level)
values
  (
    'Admin Analytics ページに週次ダイジェスト UI を追加',
    'GrowthMissionService.loadWeeklyDigest() を AdminAnalyticsPage に統合。チャネル別タッチ数・登録数・紹介数・インポートCTA数をKPIチップで表示する週次レポートカードを実装。',
    'analytics',
    '2026-03-25',
    'medium'
  ),
  (
    'sitemap.xml に /tech-blog-tracker / /import / /user-manual を追加',
    '検索エンジンへのクロール対象 URL を 4 件から 7 件に拡充。技術ブログ投稿管理・インポート・ユーザーマニュアルページが Google Search Console から認識されるよう対応。',
    'seo',
    '2026-03-25',
    'low'
  );
