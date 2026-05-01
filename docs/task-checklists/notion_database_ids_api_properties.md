# Notion Database IDs And API Properties Checklist

Source issue: #1288
Source material: `docs/SETUP_SLACK_NOTION_MANUAL.md`
Owner lane: Codex #3 / PowerShell docs and automation
Review lane: Codex #2 for workflow execution drift

## Goal

Make Notion database ID handling and API property mapping repeatable, strict,
and safe for the WBS / ROADMAP / Memory mirror.

## Manual Setup Checklist

- [ ] Create or confirm the top-level `jibun mirror` Notion page.
- [ ] Create or confirm the `ROADMAP` page.
- [ ] Create or confirm the `WBS Tasks` database.
- [ ] Create or confirm the `Memory Index` database.
- [ ] Create or confirm the `Today's Digest` page if digest sync is enabled.
- [ ] Invite the internal Notion integration to the top-level page and verify
      child page/database access.
- [ ] Record the raw page/database URLs in a private scratch space only.
- [ ] Extract the 32-character page/database ids from URLs.
- [ ] Normalize ids to a form accepted by Notion API, with or without hyphens.
- [ ] Store ids as Supabase Edge Function secrets, not in source files.
- [ ] Store GitHub Actions secrets only when a workflow needs direct access.
- [ ] Confirm the API token has read, update, and insert content capability.

## Property Schema Checklist

### WBS Tasks

- [ ] `id` is the Title property.
- [ ] `task_title` is Rich text.
- [ ] `instance` is Select.
- [ ] `status` is Select.
- [ ] `progress` is Number.
- [ ] `deadline` is Date.
- [ ] `updated_at` is Date.
- [ ] Do not create a Rich text property named `title`; Notion reserves the
      internal title property id and this can produce validation errors.

### Memory Index

- [ ] `filename` is the Title property.
- [ ] `type` is Select with `feedback_success`, `feedback_correction`, and
      `project`.
- [ ] `timestamp` is Date.
- [ ] `description` is Rich text.

## API Payload Checklist

- [ ] Build Title payloads through a title wrapper.
- [ ] Build Rich text payloads through a rich_text wrapper.
- [ ] Build Select payloads through a select wrapper and normalize option names.
- [ ] Build Number payloads through a numeric wrapper with finite-number guards.
- [ ] Omit empty Date properties instead of sending invalid date payloads.
- [ ] Reject any attempt to create a non-title property named `title`.
- [ ] Truncate long text before sending it to Notion.
- [ ] Rate-limit writes to stay below Notion API limits.
- [ ] Treat missing secrets as a soft-fail in scheduled workflows.
- [ ] Treat schema mismatch as actionable setup drift, not as data loss.

## Verification Checklist

- [ ] Query each Notion database and inspect the returned `properties` object.
- [ ] Run `schedule-hub:notion.sync_wbs` with a small limit.
- [ ] Run `schedule-hub:notion.sync_roadmap` with a small limit.
- [ ] Run `schedule-hub:notion.sync_memory_index` with a small limit.
- [ ] Confirm reruns update or skip existing pages rather than duplicating rows.
- [ ] Confirm workflow logs expose summary counts without leaking tokens.
