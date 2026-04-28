-- PS#5 S76: anon guard 11ページ追加
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'anon guard 11ページ追加 (PS#5 S76)',
  'ai_secretary/edge_llm_playground/election_strategy/election_victory/gemini_university_v2/guitar_recording_studio/horse_racing_predictor/morning_briefing/personal_dashboard/project_gantt/tome_deck_studio に invoke()前 currentUser==null ガード追加。return型不一致(Future<String>/Future<bool>)・_GanttTimelineTabState スコープ外 _supabase/_loadingWbs も修正。S74+S76 合計31ページのanon guard完了。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
