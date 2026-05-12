-- PS#6 S172: blog_posts status CHECK constraint fix + tags column追加
-- 'ready' status を追加 (draft→ready→posted flow を有効化)
-- tags text[] column を追加 (Flutter UI のタグフィールドをDB連携)

-- Fix 1: status CHECK constraint に 'ready' を追加
ALTER TABLE blog_posts DROP CONSTRAINT IF EXISTS blog_posts_status_check;
ALTER TABLE blog_posts ADD CONSTRAINT blog_posts_status_check
  CHECK (status IN ('draft', 'ready', 'posted', 'skipped'));

-- Fix 2: tags column追加
ALTER TABLE blog_posts ADD COLUMN IF NOT EXISTS tags text[] DEFAULT '{}';
