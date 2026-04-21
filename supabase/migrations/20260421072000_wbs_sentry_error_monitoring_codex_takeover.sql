-- Codex takeover: optional Sentry error monitoring.
--
-- Only the task Codex actually started is moved to the Codex owner.
-- This slice wires SENTRY_DSN-based Sentry capture into the existing
-- ErrorReporter feedback fallback and adds setup documentation.

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 25),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done: Codex added optional sentry_flutter integration behind SENTRY_DSN, route breadcrumbs, Supabase auth user context, and docs/SENTRY_SETUP.md.',
    'Next: create the production Sentry project/DSN secret, pass dart-defines in deploy-prod, and add alert rules after first production event.'
  ),
  recovery_plan = CASE
    WHEN COALESCE(recovery_plan, '') = '' THEN
      'If Sentry setup blocks release, keep SENTRY_DSN unset so the app falls back to Supabase feedback reporting while the DSN/alert routing is fixed.'
    ELSE recovery_plan
  END,
  updated_at = now()
WHERE title = 'エラー監視強化 (Sentry連携)'
  AND status <> 'completed';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Optional Sentry error monitoring integration',
  'Codex が エラー監視強化 (Sentry連携) を一時引き継ぎ、SENTRY_DSN が設定された本番ビルドで sentry_flutter に Flutter/Dart/AppLogger エラー、route breadcrumb、Supabase auth user context を送信する基盤を追加。未設定時は既存 feedback.submit 送信のみ継続する。',
  '2026-04-21'
)
ON CONFLICT DO NOTHING;
