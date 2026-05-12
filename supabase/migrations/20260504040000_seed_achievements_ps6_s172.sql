-- PS#6 S172: blog_posts 完全修復 — status='ready' + tags列追加
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S172: ブログ投稿管理機能 完全修復 — status ready + tags列追加',
  'blog_posts.status CHECK制約に''ready''を追加(draft→ready→posted フローが有効化)。tags text[]列を新設しFlutter UIのタグフィールドとDB連携。schedule-hub EF blog.insert_post/blog.update_post もtags対応に更新。これによりFlutter管理ページの「公開準備」トグルが正常動作し、タグ情報もDB保存できるようになった。',
  '2026-05-04'
) ON CONFLICT DO NOTHING;
