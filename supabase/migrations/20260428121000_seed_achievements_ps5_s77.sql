-- PS#5 S77: test @TestOn fix + 24EF audit PR done + anon guard cleanup
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'anon guard 31ページ完了 + flutter test @TestOn fix (PS#5 S76+S77)',
  'S76: anon guard 11ページ追加(ai_secretary/edge_llm_playground等) + return型不一致修正 + _GanttTimelineTabState スコープ修正。S77: admin_analytics_page_test に @TestOn(browser) 追加でPR#860 dart:js_interop CI ブロッカー解消。24EF audit cross-instance-PR → done/ 移動。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
