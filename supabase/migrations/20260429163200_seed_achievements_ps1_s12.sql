-- PS#1 S12: collision 3件修正 (160000/161500/163000)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#1 S12: collision 3件修正 (160000/161500/163000) → 1119 files clean',
  '160000(vscode_s16→160100) + 161500(ps5_s107→161600) + 163000(ps5_s108→163100)。'
  '1119 migration files / 1119 unique timestamps — clean (c457fc21a)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
