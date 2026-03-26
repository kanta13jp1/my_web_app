-- ============================================================
-- Session 15 開発実績シード (2026-03-26)
-- 競合比較 SEO ランディングページ実装
-- ============================================================

insert into public.development_achievements
  (title, description, category, achieved_at, impact_level)
values
  (
    '競合比較 SEO ページ群を実装 (/vs-notion 等)',
    'ComparisonPage ウィジェットを新規作成。/vs-notion / /vs-evernote / /vs-moneyforward / /vs-slack / /vs-chatwork の5ルートを追加。各ページで競合の痛点・機能比較表・移行CTAを表示。sitemap.xml に5URL追加（合計13URL）。「Notion代替」等の検索キーワードからの有機流入獲得を狙う。',
    'marketing',
    '2026-03-26',
    'high'
  );
