-- PS#1 S14: comparison_page 4件重複削除 + stale EF cross-instance-pr
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#1 S14: comparison_page 4件重複削除 (588 keys) + stale EF VSCode cross-instance-pr',
  'cohere/together-ai/replicate + together-ai再発 4件削除 → 588 keys。'
  'Stale EF: recipe-meal-planner(health_coach) + travel-itinerary-planner(travel×7) DEAD_LIST。'
  'VSCode版へ cross-instance-pr (20260429_stale_ef_health_travel_vscode.md)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
