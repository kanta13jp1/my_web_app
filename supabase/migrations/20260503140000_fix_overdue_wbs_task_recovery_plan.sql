-- PS#1 S24: WBS同期失敗修正 — overdue タスク recovery_plan 追加
-- タスク eec47160 (deadline=2026-05-02) が recovery_plan なしで HTTP 500 を返し
-- GitHub Issues WBS Sync の全バッチが失敗していた問題を修正する
-- nocheck: time-relative (意図的に deadline < NOW() を使用 — このマイグレーション自体が
-- overdue タスクの一括修復を目的としており、再実行時は WHERE 条件が 0 行を返すため安全)
UPDATE wbs_tasks
SET
  recovery_plan = 'deadline 超過: 2026-05-02 → 次セッションで優先着手。PS#1が直接対応できないタスクはcross-instance-prでVSCode版/Win版に委譲する',
  recovery_planned_at = NOW(),
  updated_at = NOW()
WHERE id = 'eec47160-7ae3-40f4-9e5f-4d4401d7e71f'
  AND (recovery_plan IS NULL OR length(trim(recovery_plan)) = 0);

-- 同様に deadline 超過かつ recovery_plan 空の全タスクを一括修正
-- (future-proof: 同じエラーが他タスクで再発しないよう)
UPDATE wbs_tasks
SET
  recovery_plan = '期限超過タスク: 次セッションで優先レビューし cross-instance-pr または直接実装で対応予定',
  recovery_planned_at = NOW(),
  updated_at = NOW()
WHERE COALESCE(planned_end_date, end_date) < CURRENT_DATE
  AND status NOT IN ('completed', 'cancelled')
  AND (recovery_plan IS NULL OR length(trim(recovery_plan)) = 0);
