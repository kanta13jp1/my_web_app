-- PS#5 S94: equal_keys CI fix + collision patrol 3件
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#5 S94: comparison_page 重複マップキー8件削除 + collision patrol 3件解消',
  'hubspot/miro/linear/n8n が _competitorData+categoryOf 両方で重複登録。'
  '_CompetitorInfo 4ブロック+const map 4行削除。flutter analyze No issues found (29.5s)。'
  '042500 autogen→042600 / 033000 ps5_s91→033100 / 030000 ps6_s103→030100。'
  '939 timestamps 全 unique。CI失敗 equal_keys_in_const_map 根本解消。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
