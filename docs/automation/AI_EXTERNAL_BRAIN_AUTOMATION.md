# AI External Brain Automation

Last updated: 2026-05-05

## Goal

Turn one-off AI research into compounding project memory. News, articles,
NotebookLM takeaways, Claude Code discoveries, and Codex discoveries should move
through the same four loops:

1. Ingest: save original material as `raw/*`.
2. Compile: create maintained summaries in `wiki/*`.
3. Query: answer project questions from accumulated memory.
4. Lint: find stale facts, contradictions, and broken links.

## Project Mapping

This repository uses Supabase `memory_index` as the cloud mirror of the external
brain. Scheduled jobs and Edge Functions cannot read local Obsidian files, so
automations write virtual paths into `memory_index`:

- `raw/news/YYYY-MM-DD/<signal>.md`
- `wiki/sources/news/YYYY-MM-DD/<signal>.md`
- `memory/*.md` from local project memories

The local `memory-search-sync.yml` workflow keeps checked-in `memory/*.md` files
indexed. The news pipeline writes directly from `schedule-hub` so it works even
when the Windows machine is off.

## Current Automation

- `tools-hub` `rss.fetch_latest`: fetches RSS/Atom, normalizes items, and ranks
  news signals.
- `schedule-hub` `blog.news_signal_draft`: creates a `blog_posts` draft and
  mirrors the same material into `memory_index` raw/wiki paths.
- `.github/workflows/blog-news-signal-draft.yml`: runs the action daily at
  06:20 JST.
- `/news-rss`: manual review surface for RSS sources and blog draft creation.

## Operating Constraints

- Only two local agent instances are allowed: Claude Code #1 Windows app and
  Codex #1 Windows app.
- Repeating jobs should run on GitHub Actions, Supabase Edge Functions, or
  scheduled app tasks instead of extra local instances.
- Development repositories should stay under `C:\Users\kanta\GitHub`.
- Avoid OneDrive for active repos, worktrees, `node_modules`, `.venv`, `.git`,
  and build outputs.

## Next Additions

- Add `blog.news_signal_lint` to compare `raw/news` and `wiki/sources/news` for
  stale facts and source conflicts.
- Add a manual admin UI panel that shows the memory file paths attached to each
  blog draft.
- Add high-risk-topic review flags before publishing finance, election, medical,
  legal, or disaster-related drafts.
