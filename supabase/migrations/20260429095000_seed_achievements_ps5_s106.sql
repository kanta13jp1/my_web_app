-- PS#5 S106: widget async safety + migration collision resolve
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#5 S106: widget async safety + migration timestamp collision修正',
  'api_key_status_banner.dartにif(!mounted)return guard追加(anon-guard済みだがmounted guard漏れ)。supabase/migrations timestamp collision 3件修正(075000/080000/090000)。全58 widgetsスキャン完了。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
