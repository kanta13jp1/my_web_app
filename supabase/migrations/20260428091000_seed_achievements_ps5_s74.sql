-- PS#5 S74: anon guard 20 ページ追加
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'anon guard 20 ページ一括追加 — EF invoke 前 currentUser == null チェック',
  'agent_hub/ai_presentation_builder/ai_writing_assistant/analyze_reality/behavior_log/changelog_manager/data_backup/edge_function_status/growth_acquisition_report/growth_acquisition_signal/growth_command_center/memo_reactions/my_struggle/qr_code_generator/real_world_danshari/revenue_forecaster/semantic_search/thought_interrupt_diagnosis/travel_itinerary_planner/quota_dashboard の20ページに認証ガードを追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
