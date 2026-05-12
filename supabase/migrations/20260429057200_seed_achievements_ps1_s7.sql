-- PS#1 S7: migration timestamp collision fix (057000→057100)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#1 S7: migration timestamp collision 修正 (20260429057000)',
  'Migration Timestamp Collision Check 失敗 (run 25090460724) 検知。'
  '20260429057000 に ps4_s138 + ps5_s97 の 2 ファイル競合。'
  'git mv で ps5_s97 → 20260429057100 にリネーム → push (139513e4c)。'
  'CI Migration Timestamp Collision Check 次回 success 期待。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
