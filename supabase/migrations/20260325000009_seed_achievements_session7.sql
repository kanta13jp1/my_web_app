-- ============================================================
-- Session 7 開発実績シード (2026-03-25)
-- SEO強化・競合比較キーワード対応
-- ============================================================

insert into public.development_achievements
  (title, description, category, achieved_at, impact_level)
values
  (
    'SEO meta description に競合比較キーワードを追加',
    'web/index.html の description・keywords に Notion代替・Evernote代替・MoneyForward代替・Slack代替を追記。検索流入の多角化を狙う。',
    'seo',
    '2026-03-25',
    'medium'
  ),
  (
    'OGP・Twitter カードを競合比較訴求に更新',
    'og:title を「Notion・Evernote・MoneyForward を超えるAI統合プラットフォーム」に変更。SNSシェア時の訴求力を向上。',
    'seo',
    '2026-03-25',
    'medium'
  ),
  (
    'SEOシェル本文・JSON-LD featureList を競合代替機能で拡充',
    'ランディングページのクロール可能テキストに競合SaaS名を追加。JSON-LDの機能一覧を10項目に拡充しリッチスニペット対応を強化。',
    'seo',
    '2026-03-25',
    'medium'
  );
