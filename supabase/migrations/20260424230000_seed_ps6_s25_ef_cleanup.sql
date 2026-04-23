-- PS#6 S25: 9 dead EF source dirs deleted, Flutter pages migrated to hubs
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'EF ソース cleanup S15-S25 累計 38本',
  'PS#6 S25: DEAD_LIST∩functions/ 9本削除 + Flutter pages を hubs へ migrate (pomodoro→tools-hub / poll→tools-hub / invoice→app-hub / competitor→enterprise-hub) / agent pages placeholder化 / S15-S25累計 38 EF source dirs deleted',
  '2026-04-24'
)
ON CONFLICT DO NOTHING;
