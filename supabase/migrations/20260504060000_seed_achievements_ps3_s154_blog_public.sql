-- PS#3 S154: サイト内公式ブログ機能追加
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'サイト内公式ブログ機能追加 (PS#3 S154)',
  'blog_page.dart 新規作成 (公開記事一覧 / プラットフォームフィルター / エンゲージメント表示) + blog_post_page.dart 新規作成 (flutter_markdown フルレンダリング / 外部リンク) + /blog ルート追加 + HomeToolCatalog「公式ブログ」エントリ追加 + anon RLS 緩和 migration (status=posted 公開)。Qiita/dev.to に加えてサイト内でも閲覧可能に。',
  '2026-05-03'
)
ON CONFLICT DO NOTHING;
