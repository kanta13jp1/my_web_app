-- ============================================================
-- Session 11 開発実績シード (2026-03-25)
-- 機能リクエスト公開ページ・sitemap 拡充
-- ============================================================

insert into public.development_achievements
  (title, description, category, achieved_at, impact_level)
values
  (
    '機能リクエスト公開ページ (/feature-requests) を実装',
    'FeatureRequestsPage を新規作成。anon ユーザーも投稿・閲覧・投票（upvote）が可能。ランディングページ SEO シェルのナビにリンク追加。sitemap.xml に /feature-requests を追加。コミュニティ主導の開発優先度決定フローを構築。',
    'product',
    '2026-03-25',
    'high'
  ),
  (
    'main.dart に /feature-requests ルートを追加',
    'onGenerateRoute に FeatureRequestsPage のルートを追加し、ディープリンクからのアクセスを有効化。',
    'infrastructure',
    '2026-03-25',
    'low'
  );
