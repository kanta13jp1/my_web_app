-- Session Web#27: ブログ実投稿パイプライン完成 (機能 #16)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'ブログ実投稿パイプライン: Qiita/dev.to API自動投稿',
  'blog-auto-publisher Edge FunctionにQiita API (publish_qiita) / dev.to API (publish_devto) / auto_publishアクションを実装。blog_posts.statusをdraft→postedに自動更新。SUPABASE_SECRET QIITA_ACCESS_TOKEN/DEVTO_API_KEY設定で即稼働。CLAUDE.mdのblog-draft Scheduleタスクにauto_publish呼び出しStep 4を追加。',
  '2026-04-11'
)
ON CONFLICT DO NOTHING;
