-- PS#3 S153: ブログ投稿管理機能 完全実装
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'ブログ投稿管理機能 完全実装 (PS#3 S153)',
  'blog_management_page.dart に訂正レビュータブ追加 (blog_corrections承認/却下UI) + blog_draft_editor_page.dart 新規作成 (Markdown フルページエディタ + flutter_markdown プレビュー + 公開ボタン) + blog_service.dart 薄い wrapper + /admin/blog/new・/admin/blog/edit ルート追加。T-1 自動化パイプラインとの共存 (手動 override + 自動継続) を確立。',
  '2026-05-03'
)
ON CONFLICT DO NOTHING;
