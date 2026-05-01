# Notion-Style Comments Execution Checklist

Source issue: #1321
Source material: `docs/blog-drafts/2026-03-28-note-comments.md`
Owner lane: Codex #3 / PowerShell docs and automation
Review lane: VSCode if UI behavior changes are needed

## Goal

Turn the implemented Flutter + Supabase note comments pattern into a repeatable
execution checklist for future Notion-style comment surfaces.

## Implementation Checklist

- [ ] Confirm the target parent entity has a stable primary key and owner field.
- [ ] Create a comments table with `id`, parent id, `user_id`, `content`,
      `created_at`, and `updated_at`.
- [ ] Add `CHECK (length(trim(content)) > 0)` and a practical content length
      limit in the API layer.
- [ ] Enable RLS on the comments table.
- [ ] Add SELECT / INSERT / UPDATE / DELETE policies scoped to `auth.uid()`.
- [ ] Add an index on `(parent_id, created_at ASC)` for chronological display.
- [ ] In the Edge Function, derive `user_id` from the JWT rather than trusting
      request body input.
- [ ] For every query and mutation, filter by both parent id and `user_id`.
- [ ] Return only fields needed by the UI: `id`, `content`, timestamps.
- [ ] Add comment count loading as a separate lightweight query or endpoint.
- [ ] In Flutter, expose comments through an icon button with a count badge.
- [ ] Use `DraggableScrollableSheet` or an equivalent constrained panel for
      comment review and entry.
- [ ] Use `unawaited()` only for non-blocking refreshes where stale data is safe.
- [ ] Replace deprecated Flutter color APIs such as `withOpacity` with current
      alternatives before merge.
- [ ] Run `flutter analyze` and the focused widget/unit tests for the touched
      page.

## Acceptance Checks

- [ ] A signed-in user can create, read, update, and delete only their comments.
- [ ] A signed-in user cannot read another user's comments by changing ids.
- [ ] Deleting the parent entity cascades or otherwise removes orphan comments.
- [ ] Empty content and over-limit content are rejected.
- [ ] Comment count updates after create/delete without a full page reload.
- [ ] The UI remains usable on mobile width.

## Automation Hooks

- Add a migration-time RLS check for each new comments table.
- Add an Edge Function smoke test that attempts cross-user access and expects
  denial.
- Add this checklist to future WBS child tasks before UI implementation starts.
