-- Win Claude (L3): Repair stale WBS rows for asset-management Issues already
-- CLOSED on GitHub (sync-drift repair, per docs/WBS_GITHUB_ISSUE_SYNC_RUNBOOK.md).
--
-- These 5 GitHub Issues are already closed by the owner, yet their linked WBS
-- rows still appeared as pending / in_progress in the 2026-07-15 user-tasks
-- snapshot. The GitHub Issues WBS Sync should have completed them; this migration
-- performs the same repair deterministically so the burn-down count is honest.
-- No fabrication: WBS is being made to match the owner's existing GitHub decision.
--
--   #2941 口座間移動タスク管理            → closed as COMPLETED (2026-06-08)
--   #2939 支払原資口座の未設定レビュー     → closed as COMPLETED (2026-06-08)
--   #3357 枯渇ウォッチ自動移動提案         → closed as DUPLICATE  (2026-06-15)
--   #3318 安全割れ『差替え口座移動』提案    → closed as DUPLICATE  (2026-06-13)
--   #3325 ショート予兆ワンクリック作成      → closed as DUPLICATE  (2026-06-13)
--
-- Targeted by the exact WBS row UUIDs verified against GitHub in this session.
-- github_issue_state='CLOSED' is set in the same UPDATE so the open-issue
-- completion guard permits the terminal state; ai_review_status='manual_override'
-- records that completion is authorized by the GitHub closure, not an AI review.
-- Idempotent: fixed-value UPDATE guarded on status <> 'completed'.

UPDATE public.wbs_tasks AS t
SET
  status             = 'completed',
  progress           = 100,
  ai_review_status   = 'manual_override',
  ai_reviewed_at     = now(),
  github_issue_state = 'CLOSED',
  end_date           = COALESCE(end_date, DATE '2026-07-16'),
  ai_review_notes    = concat_ws(
    ' ',
    'Stale-row repair (Win Claude 2026-07-16):',
    m.reason
  ),
  remaining_work     = '',
  updated_at         = now()
FROM (
  VALUES
    ('7fd7bc79-614b-4af7-abb5-dfe3a77db72a'::uuid, 2941,
     'GitHub Issue #2941 was closed as completed on 2026-06-08; WBS row synced to completed.'),
    ('8fe460ea-f0c5-4180-aeb9-866a03e9dfb3'::uuid, 2939,
     'GitHub Issue #2939 was closed as completed on 2026-06-08; WBS row synced to completed.'),
    ('23c94c9f-3a64-45e4-a56e-0b7fede6f841'::uuid, 3357,
     'GitHub Issue #3357 was closed as duplicate on 2026-06-15; WBS row synced to completed (duplicate).'),
    ('f21e5bd3-939b-4f01-97cd-df9145cfed1d'::uuid, 3318,
     'GitHub Issue #3318 was closed as duplicate on 2026-06-13; WBS row synced to completed (duplicate).'),
    ('e4658da1-2bcd-4786-8cba-6b6f89074dcf'::uuid, 3325,
     'GitHub Issue #3325 was closed as duplicate on 2026-06-13; WBS row synced to completed (duplicate).')
) AS m(row_id, issue_number, reason)
WHERE t.id = m.row_id
  AND t.status <> 'completed';
