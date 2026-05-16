-- PS#5 S125: Blog投稿管理 完全実装
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#5 S125: Blog投稿管理 完全実装 (RLS緩和/content列/EF publish/CRUD UI)',
  'blog_posts.content列追加 + RLS SELECT全認証ユーザー開放 + schedule-hub blog.publish_post/update_post/delete_post/insert_post 新規4アクション + tech_blog_tracker_page.dart CRUD完全実装 (公開/編集/削除/新規作成/エラー表示/パイプライン状態カード/自動プラットフォーム区分) + blog-draft-register.yml content保存対応 + blog-publish.yml Step4.5 blog_posts.status更新',
  '2026-05-04'
)
ON CONFLICT DO NOTHING;
