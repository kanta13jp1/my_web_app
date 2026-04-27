-- PS#5 S72: stale EF migration — agent-hub/changelog-manager → enterprise-hub/app-hub
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'stale EF 参照修正 — agent-hub/changelog-manager を hub EF に統合',
  'agent-hub(不在)→enterprise-hub(agent.departments/performance/routing), changelog-manager(不在)→app-hub(changelog.list/create) に移行。EF 数 50 維持。dart format 2 ファイル修正も含む。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
