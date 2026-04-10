-- Session Windows#23: blog_posts テーブルに content_preview カラムを追加
-- blog-post-manager EF が content_preview を INSERT しようとするが
-- テーブル定義に存在しなかったためエラーが発生していた問題を修正
ALTER TABLE blog_posts
  ADD COLUMN IF NOT EXISTS content_preview text;

-- 投稿実績を記録
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '技術記事 Qiita/dev.to 初投稿: Claude Code Schedule 自動化記事',
  'blog-auto-publisher EF を使い Qiita (https://qiita.com/kanta13jp1/items/38f0383e0ea01b787900) と dev.to (https://dev.to/kanta13jp1/how-i-automated-cs-bug-fixes-and-competitor-monitoring-with-claude-code-schedule-18a6) に技術記事を自動投稿。Zenn向け記事 (2026-03-28-zenn-database-view.md) は published: true に変更しGitHub連携でデプロイ済み。ユーザー獲得加速施策タスクT-1の第1弾実行完了。',
  '2026-04-11'
)
ON CONFLICT DO NOTHING;
