-- Win版#132 part 254 (2026-06-10 / Win Claude): SDLC×WBS カバレッジ監査で検出した重複タスクの解消
-- 「インシデント対応プロセス」(task 3cb3aa46-9dc3-41dc-a0d1-3614ee90da55 / category business-ops /
--  milestone paying-100 / 2026-04-25 起票 / 定義 = Runbook + RACI + Postmortem template)
--
-- 監査 (docs/SDLC_WBS_COVERAGE_AUDIT.md §3) の判定: 本タスクの定義 3 点は part 245 (2026-06-09) 完了の
-- WBS 8830188a 成果物 docs/ONCALL_INCIDENT_SOP.md が既に充足している:
--   - Runbook        → SOP §5 Runbook dispatch 表 (front door)
--   - Postmortem     → SOP §7 Postmortem テンプレート (blameless)
--   - RACI           → SOP §2 On-call モデル (solo founder + AI fleet 役割) + §6 通信プロトコル が実質カバー
-- よって completed-by-reference で完了化 (重複作業の再実施はしない / [WBS-DEDUP] 整合)。
-- 形式的な RACI マトリクス表が将来必要になった場合は SOP 改訂タスクとして別起票する。
--
-- 新規成果物なしの dedup 解消のため development_achievements への INSERT は行わない。
-- ai_review_status='approved' を同一 UPDATE で設定 → trigger 回避で status='completed' 確定。
-- Idempotent: 固定値 UPDATE / description append は LIKE guard。

UPDATE public.wbs_tasks
SET
  status            = 'completed',
  progress          = 100,
  ai_review_status  = 'approved',
  ai_reviewed_at    = now(),
  ai_review_notes   = 'Win Claude (L3 / SDLC×WBS カバレッジ監査 part 254) による completed-by-reference。タスク定義 (Runbook + RACI + Postmortem template) は docs/ONCALL_INCIDENT_SOP.md (part 245 / WBS 8830188a) が充足: §5 Runbook dispatch 表 / §7 Postmortem テンプレート / §2+§6 役割分担 (RACI 相当)。重複作業を再実施せず監査 doc docs/SDLC_WBS_COVERAGE_AUDIT.md §3 に判定根拠を記録。形式 RACI 表が必要になれば SOP 改訂として別起票。',
  owner_instance    = 'win',
  start_date        = COALESCE(start_date, DATE '2026-06-10'),
  end_date          = DATE '2026-06-10',
  remaining_work    = 'Completed by reference (part 254 audit). 実体 = docs/ONCALL_INCIDENT_SOP.md (8830188a / part 245)。残: 形式 RACI マトリクスが必要になった場合のみ SOP 改訂を別起票。',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-06-10: duplicate of ONCALL_INCIDENT_SOP%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-06-10: duplicate of ONCALL_INCIDENT_SOP (Win Claude part 254 / SDLC-WBS coverage audit). This task (filed 2026-04-25, before the SOP existed) asked for Runbook + RACI + Postmortem template. All three are satisfied by docs/ONCALL_INCIDENT_SOP.md delivered for WBS 8830188a in part 245 (2026-06-09): section 5 runbook dispatch table, section 7 blameless postmortem template, and sections 2+6 role/communication assignments covering RACI substance for a solo-founder + AI-fleet org. Closed as completed-by-reference per the audit at docs/SDLC_WBS_COVERAGE_AUDIT.md section 3 rather than re-authoring duplicate content ([WBS-DEDUP] discipline). If a formal RACI matrix becomes necessary, it should be filed as an SOP revision task.'
  END,
  updated_at        = now()
WHERE id = '3cb3aa46-9dc3-41dc-a0d1-3614ee90da55';
