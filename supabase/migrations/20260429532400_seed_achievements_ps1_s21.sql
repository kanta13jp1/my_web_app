-- PS#1 S21: CI triage 8件クローズ (#1146-#1153) — Deno lint no-unused-vars fix + cyberark dup fix
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#1 S21: CI triage 8件クローズ (#1146-#1153) + 2件fix',
  'S21: (1) cyberark equal_keys_in_map fix (e26cb032d) / (2) tools-hub multipleTopSignalBonus entries/_raceCourseType no-unused-vars fix (2f4f80495). #1146-#1150/#1152/#1153=main stale pre-fix, #1148/#1151=codex2 branch deno lint. 1489 migrations/0 coll, 1528 entries/0 dups.',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
