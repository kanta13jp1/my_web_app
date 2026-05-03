# Blog and News Automation Runbook

Last updated: 2026-05-03

## Blog Flow

1. Write from `/blog/compose` or create a draft from `/blog-management`.
2. Drafts are saved to `blog_posts` with `status = 'draft'`.
3. Admin review happens in `/blog-management`.
4. Mark a draft as `ready` to place it on the automated publish queue.
5. `.github/workflows/blog-publish.yml` runs daily at 21:00 JST and calls
   `schedule-hub` `blog.publish_post` for ready posts.
6. Manual publish is still available from `/blog-management` for urgent posts.
7. Published posts become visible on `/blog` and `/blog/post`.

## Automation Guards

- Empty Markdown content is rejected by `blog.publish_post`.
- `ready` posts are processed oldest first, up to 5 per scheduled run.
- Qiita tags are limited to 5 and dev.to tags to 4 by `schedule-hub`.
- Existing `blog-engagement.yml` syncs engagement, and the UI exposes manual
  sync for recovery.

## News Flow

1. `/news-rss` calls `tools-hub` `rss.fetch_latest`.
2. `tools-hub` fetches RSS/Atom feeds server-side and returns normalized news
   items, avoiding browser CORS failures.
3. The page shows default sources and adds authenticated user feeds from
   `rss.list_feeds`.
4. Authenticated users can register an RSS URL from the page.

## Follow-Up Automation Ideas

- Add a scheduled `rss.fetch_latest` cache table when traffic grows.
- Add AI summarization and duplicate clustering after RSS normalization is
  stable.
- Add a blog draft generator that converts high-ranking news items into draft
  briefs, but keep human review before publish.
