-- Codex takeover: onboarding optimization.
--
-- Only the task Codex actually started is moved to the Codex owner.
-- This records the first implementation slice: persisted onboarding
-- progress, controlled navigation, and regression coverage.

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 35),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done: Codex added resumable onboarding progress via local persistence, guarded back/next controls, and widget coverage for saved-page resume.',
    'Next: verify completion flow against live Supabase data, add funnel/drop-off metrics, and tune copy/steps from user activation data.'
  ),
  recovery_plan = 'If onboarding completion does not persist in production, validate user_stats metadata upsert/update semantics and add a server-side completion RPC.',
  updated_at = now()
WHERE title = 'オンボーディング最適化'
  AND status <> 'completed';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Onboarding progress resume optimization',
  'Codex がオンボーディング最適化を一時引き継ぎ、保存済みページから再開できる進捗永続化、戻る/次への明示制御、widget test を追加。WBS owner を Codex に変更し、残作業をファネル計測と本番データ検証へ整理した。',
  '2026-04-21'
)
ON CONFLICT DO NOTHING;
