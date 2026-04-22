-- WBS Codex takeover: life-capital alert notification routing.
-- 2026-04-22
--
-- Scoped to the actual Codex work in this session: route repeated
-- life-capital degradation alerts into the existing in-app notification
-- center with duplicate protection and a return path to the home command
-- center.

INSERT INTO wbs_tasks (
  category,
  category_icon,
  category_order,
  title,
  description,
  instance,
  owner_instance,
  status,
  progress,
  start_date,
  end_date,
  milestone_code,
  priority,
  remaining_work,
  recovery_plan,
  estimated_hours
)
SELECT
  'コアSaaS機能',
  '🧩',
  4,
  'ライフ資本アラート通知導線',
  '時間・お金・健康・体力・知能・集中力の継続低下アラートを既存通知センターへ送信し、同日同資本の重複通知を抑制しながら、通知からホームのライフ浪費ゼロ司令塔へ戻れるようにする。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-22',
  '2026-04-22',
  'beta',
  'high',
  'Done 2026-04-22: Codex added a LifeWasteAlertNotificationRepository abstraction, a Supabase/core-hub notification implementation, duplicate notification keys, notification-center metadata, and service tests for routing and fallback.',
  'Next: consider weekly digest aggregation once the notification center supports priority grouping across all life-capital alerts.',
  2
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = 'ライフ資本アラート通知導線'
);

UPDATE wbs_tasks
SET
  remaining_work = 'Done 2026-04-22: Codex followed up Supabase sync by routing repeated life-capital alerts to the notification center.',
  recovery_plan = 'Completed by task: ライフ資本アラート通知導線.'
WHERE title = 'ライフ資本スナップショット Supabase同期';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'ライフ資本アラート通知導線',
  'Codex routed repeated life-capital degradation alerts into the existing core-hub notification center. Alerts are deduplicated by date/resource/severity, notifications deep-link back to /home, and the home monitoring box surfaces when a notification was queued.',
  '2026-04-22'
)
ON CONFLICT DO NOTHING;
