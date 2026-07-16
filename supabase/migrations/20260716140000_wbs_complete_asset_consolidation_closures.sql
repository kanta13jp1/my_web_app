-- Win Claude (L3): Complete WBS rows for asset-management Issues closed on GitHub
-- during the 2026-07-16 consolidation (owner-approved). Companion to the audit
-- docs/asset-management-wbs-consolidation-2026-07-16.md.
--
-- ② IMPLEMENTED → closed COMPLETED (acceptance criteria met in code):
--   #3343 ショート→口座移動提案+UIパネル+タスク化 (_buildTransferSuggestions planning:1729 /
--         _buildTransferSuggestionSection page:24785 / _createTransferTaskFromSuggestion page:3534)
--   #3384 transfer_task ステータス→projectedBalance 即時再計算 (planning:1693-1722 / page:8181)
--
-- ③ DUPLICATE of an implemented parent → closed DUPLICATE; the single residual delta
--    of each was consolidated into GitHub Issue #4059:
--   #3595 (dup #3343) 全額補填+buffer / #3585 (dup #3343) 対象支払 rationale /
--   #3328 (dup #3343) safety_balance 発火+赤帯内ボタン /
--   #3354 (dup #2941) PaymentFundingRule+keyed dedupe / #3383 (dup #2939) 重要度バッジ
--
-- Each Issue has 2 WBS rows (GitHub-issue row + user-request row); all 14 completed.
-- github_issue_state='CLOSED' + ai_review_status='manual_override' in the same UPDATE
-- so the open-issue completion guard permits the terminal state. Idempotent
-- (guarded on status <> 'completed').

UPDATE public.wbs_tasks AS t
SET
  status             = 'completed',
  progress           = 100,
  ai_review_status   = 'manual_override',
  ai_reviewed_at     = now(),
  github_issue_state = 'CLOSED',
  owner_instance     = COALESCE(NULLIF(t.owner_instance, ''), 'win'),
  end_date           = COALESCE(t.end_date, DATE '2026-07-16'),
  ai_review_notes    = m.note,
  remaining_work     = '',
  updated_at         = now()
FROM (
  VALUES
    -- ② implemented (closed completed)
    ('40ebedb5-ab95-4ea7-9e4a-16e527f4b6f9'::uuid,
     'Issue #3343 closed as completed 2026-07-16: shortfall->transfer suggestion + UI panel + one-click task creation implemented (planning:1729 / page:24785 / page:3534). Verified by L3 code audit.'),
    ('0ad2f504-51d7-4003-b7ed-6bc039c3aa55'::uuid,
     'Issue #3343 closed as completed 2026-07-16: shortfall->transfer suggestion + UI panel + one-click task creation implemented (planning:1729 / page:24785 / page:3534). Verified by L3 code audit.'),
    ('5612b9d2-f622-4433-8d4e-0c59818ee230'::uuid,
     'Issue #3384 closed as completed 2026-07-16: transfer_task status change recomputes projectedBalance immediately (planning:1693-1722 / page:8181). Verified by L3 code audit.'),
    ('88609fab-9089-48f5-bcca-cc9c6dcb399c'::uuid,
     'Issue #3384 closed as completed 2026-07-16: transfer_task status change recomputes projectedBalance immediately (planning:1693-1722 / page:8181). Verified by L3 code audit.'),
    -- ③ duplicate of an implemented parent; residual delta tracked in #4059
    ('a735a493-e507-49c6-a8ec-df0499c204a4'::uuid,
     'Issue #3595 closed as duplicate of #3343 (implemented) 2026-07-16; residual delta (full-shortfall + buffer) tracked in #4059.'),
    ('2adcbdaf-b05a-40ec-b391-f60b11b4a98f'::uuid,
     'Issue #3595 closed as duplicate of #3343 (implemented) 2026-07-16; residual delta (full-shortfall + buffer) tracked in #4059.'),
    ('43d04c07-2ab0-43ca-be88-3ec2b477497c'::uuid,
     'Issue #3585 closed as duplicate of #3343 (implemented) 2026-07-16; residual delta (target-payment rationale) tracked in #4059.'),
    ('e674162a-ca29-4e34-a9d3-c7d899491e8a'::uuid,
     'Issue #3585 closed as duplicate of #3343 (implemented) 2026-07-16; residual delta (target-payment rationale) tracked in #4059.'),
    ('9291ac7b-cdb3-4505-99fb-f6f706627817'::uuid,
     'Issue #3328 closed as duplicate of #3343 (implemented) 2026-07-16; residual delta (safety_balance trigger + inline banner button) tracked in #4059.'),
    ('85cb6e45-eee2-46cb-9d0c-083a09ce8091'::uuid,
     'Issue #3328 closed as duplicate of #3343 (implemented) 2026-07-16; residual delta (safety_balance trigger + inline banner button) tracked in #4059.'),
    ('a674fa34-c866-4181-a139-717a9b9500f5'::uuid,
     'Issue #3354 closed as duplicate of #2941 (implemented) 2026-07-16; residual delta (PaymentFundingRule + keyed dedupe) tracked in #4059.'),
    ('3d679e4c-382e-45c8-824b-24bcec32352d'::uuid,
     'Issue #3354 closed as duplicate of #2941 (implemented) 2026-07-16; residual delta (PaymentFundingRule + keyed dedupe) tracked in #4059.'),
    ('1ce4159b-b490-4949-9987-a37835d9bb2a'::uuid,
     'Issue #3383 closed as duplicate of #2939 (implemented) 2026-07-16; residual delta (severity badges + tooltip) tracked in #4059.'),
    ('7ee74412-c07f-4c28-b9be-bc8cbd9dea37'::uuid,
     'Issue #3383 closed as duplicate of #2939 (implemented) 2026-07-16; residual delta (severity badges + tooltip) tracked in #4059.')
) AS m(row_id, note)
WHERE t.id = m.row_id
  AND t.status <> 'completed';
