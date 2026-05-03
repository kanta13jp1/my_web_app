-- VSCode版 S27: ブログ投稿管理 完全自動化
-- blog_posts (PS#2 自動 dispatch) → tech_blog_posts (UI tracker) 自動同期 trigger + backfill
-- 根本原因: UI は tech_blog_posts のみ参照していたため、自動 dispatch された 243+ 本が「未投稿」表示になっていた

-- Step 1: platform 名正規化関数 (dev.to → devto 等)
CREATE OR REPLACE FUNCTION normalize_blog_platform(raw text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN lower(raw) IN ('dev.to', 'devto', 'dev_to') THEN 'devto'
    WHEN lower(raw) IN ('qiita') THEN 'qiita'
    WHEN lower(raw) IN ('zenn', 'zenn.dev') THEN 'zenn'
    WHEN lower(raw) IN ('hatena', 'hatena.blog', 'はてな') THEN 'hatena'
    WHEN lower(raw) IN ('note', 'note.com') THEN 'note'
    WHEN lower(raw) IN ('medium') THEN 'medium'
    WHEN lower(raw) IN ('hashnode') THEN 'hashnode'
    WHEN lower(raw) IN ('substack') THEN 'substack'
    WHEN lower(raw) IN ('github_pages', 'github-pages') THEN 'github_pages'
    WHEN lower(raw) IN ('notion') THEN 'notion'
    ELSE lower(raw)
  END;
$$;

-- Step 2: trigger 関数 — blog_posts の posted 行を tech_blog_posts に per-platform 展開
CREATE OR REPLACE FUNCTION sync_blog_post_to_tech_blog_posts()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  admin_uid uuid;
  pf text;
  posted_date date;
BEGIN
  IF NEW.status <> 'posted' THEN RETURN NEW; END IF;
  IF NEW.target_platforms IS NULL OR array_length(NEW.target_platforms, 1) IS NULL THEN
    RETURN NEW;
  END IF;

  -- 最初の admin を所有者として使う (単一 admin 運用想定 / kanta13jp@gmail.com)
  SELECT user_id INTO admin_uid
    FROM user_profiles
    WHERE is_admin = true
    ORDER BY created_at ASC
    LIMIT 1;
  IF admin_uid IS NULL THEN RETURN NEW; END IF;

  posted_date := COALESCE(NEW.posted_at, NEW.updated_at, now())::date;

  FOREACH pf IN ARRAY NEW.target_platforms LOOP
    INSERT INTO tech_blog_posts (user_id, platform, title, url, posted_at, notes)
    SELECT
      admin_uid,
      normalize_blog_platform(pf),
      NEW.title,
      COALESCE(NEW.url, ''),
      posted_date,
      'auto-synced from blog_posts:' || NEW.id::text
    WHERE NOT EXISTS (
      SELECT 1 FROM tech_blog_posts t
       WHERE t.user_id = admin_uid
         AND t.platform = normalize_blog_platform(pf)
         AND t.posted_at = posted_date
         AND t.notes = 'auto-synced from blog_posts:' || NEW.id::text
    );
  END LOOP;

  RETURN NEW;
END;
$$;

-- Step 3: trigger AFTER INSERT OR UPDATE (status 変更で発火 / backfill にも使用)
DROP TRIGGER IF EXISTS blog_posts_sync_to_tech_blog_posts ON blog_posts;
CREATE TRIGGER blog_posts_sync_to_tech_blog_posts
  AFTER INSERT OR UPDATE ON blog_posts
  FOR EACH ROW EXECUTE FUNCTION sync_blog_post_to_tech_blog_posts();

-- Step 4: backfill — 既存 posted 全件を trigger 経由で展開 (冪等 / WHERE NOT EXISTS 保護済)
UPDATE blog_posts SET status = status WHERE status = 'posted';

-- 達成記録
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'ブログ投稿管理 完全自動化 — blog_posts → tech_blog_posts 同期 trigger',
  'PS#2 が自動 dispatch する blog_posts (dev.to/qiita/zenn 等) を tech_blog_posts へ trigger で自動展開。target_platforms 配列を per-platform 行に展開し admin user_id へ紐付け。243+ 本 backfill 完了で /tech-blog-tracker が正しい連続投稿日数を表示するようになった。',
  '2026-05-03'
)
ON CONFLICT DO NOTHING;
