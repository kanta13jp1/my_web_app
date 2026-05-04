# Blog and News Automation Runbook

Last updated: 2026-05-05

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
3. `tools-hub` also returns ranked `signals` using source confidence,
   freshness, keyword signal score, and duplicate clustering.
4. The page shows default sources and adds authenticated user feeds from
   `rss.list_feeds`.
5. Authenticated users can register an RSS URL from the page.

## News Signal Draft Flow

1. `.github/workflows/blog-news-signal-draft.yml` runs daily at 06:20 JST.
2. The workflow calls `schedule-hub` `blog.news_signal_draft` with the Supabase
   service role key.
3. `schedule-hub` calls `tools-hub` `rss.fetch_latest`, takes the top ranked
   signals, and creates a `blog_posts` draft.
4. The same action mirrors every signal into `memory_index` as
   `raw/news/YYYY-MM-DD/<signal>.md` and
   `wiki/sources/news/YYYY-MM-DD/<signal>.md`.
5. Draft `notes` keep `AI_NEWS_SIGNAL_DRAFT_KEY` for dedupe and
   `EXTERNAL_BRAIN_FILE_PATHS` for later query/lint automation.

## Two-Instance Operating Rule

- Local development stays on two app instances only: Claude Code #1 Windows app
  and Codex #1 Windows app.
- Recurring news/blog work should run in GitHub Actions or Supabase Edge
  Functions, not additional local Claude/Codex windows.
- Keep build artifacts, `.venv`, `node_modules`, `.git`, and worktrees outside
  OneDrive-synced paths. Use `C:\Users\kanta\GitHub` as the only active repo
  root.
- Prefer scheduled external-brain writes to `memory_index` over keeping large
  chat context alive. This reduces token and memory pressure.

## Latest Tool Notes Checked 2026-05-05

- Claude Code: the current changelog includes `claude project purge [path]`,
  Windows PowerShell detection/primary-shell fixes, and memory leak fixes around
  image-heavy or large transcript sessions. Use these for cleanup work before
  starting extra instances.
- Codex: the current Codex docs expose App Automations, in-app browser,
  computer use, commands, GitHub Action automation, skills, and memories. Use
  those surfaces to move repeatable checks out of local interactive sessions.

## Follow-Up Automation Ideas

- Add a scheduled `rss.fetch_latest` cache table when traffic grows.
- Add AI summarization after RSS normalization is stable.
- Add a `blog.news_signal_lint` action that checks contradictions, broken links,
  and stale facts across `raw/news` and `wiki/sources/news`.
- Add a human-review queue for high-risk domains such as investment, medical,
  legal, election, and disaster information before any publish automation.
