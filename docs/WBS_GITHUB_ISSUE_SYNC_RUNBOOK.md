# WBS GitHub Issue Sync Runbook

This runbook keeps GitHub Issues and `wbs_tasks` aligned when a session sees a
closed GitHub Issue still appearing in `wbs.priority_for_instance`.

## Safe Resync

1. Confirm the latest `main` deploy finished, because `tools-hub` is deployed by
   `Deploy to Production`.

   ```bash
   gh run list --workflow "Deploy to Production" --branch main --limit 3
   ```

2. Run the full Issue -> WBS sync from `main`.

   ```bash
   gh workflow run "GitHub Issues WBS Sync" --ref main
   ```

3. Watch the run until it completes.

   ```bash
   gh run list --workflow "GitHub Issues WBS Sync" --limit 5
   gh run watch <run-id> --exit-status
   ```

4. Check the sync summary. The workflow prints the aggregate
   `/tmp/wbs-sync-response.json`. A healthy run includes these response fields:
   `success`, `issue_count`, `created`, `updated`, `skipped`,
   `wbs_task_scan_count`, `completed_from_closed_issues`,
   `duplicate_wbs_closed`, `stale_wbs_repaired`, `issues_to_close`,
   `duplicate_wbs_tasks`, `repaired_wbs_tasks`, and `batch_failures`.

   `wbs_task_scan_count` and `stale_wbs_repaired` are summed across batches.
   `repaired_wbs_tasks` is merged across batches without dropping task IDs,
   linked issue numbers, or repair reasons, so stale repair audits can be
   traced from the workflow log.

## Drift Rules

- Prefer the explicit `[Issue #NNN]` prefix in WBS titles over stale
  `github_issue_number` metadata.
- If GitHub says an Issue is closed, every linked WBS row must become
  `completed` with `progress = 100` or be excluded from priority routing.
- Duplicate WBS rows for the same Issue should keep one canonical row and mark
  the rest as duplicate/completed when the Issue is closed.
- The sync workflow fetches GitHub Issues with REST pagination and retries
  transient 502/503/504 responses.

## Known Backfill

Migration `20260503053400_repair_stale_closed_issue_wbs_rows.sql` repairs the
observed stale rows for closed Issues `#1270`, `#1272`, and `#1274`. Future
drift should be repaired by `tools-hub:wbs.sync_github_issues` and reported in
`repaired_wbs_tasks`.
