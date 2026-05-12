-- PS#1 S17-S18: CI triage 10件クローズ + migration collision 3件fix (PS#6 S139-S141) + equal_keys_in_map検出
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#1 S17-S18: CI triage 10件 + migration collision 3件fix',
  'S17: 7件クローズ(#1081/#1101/#1102/#1055/#1054/#1049/#1033). S18: 10件クローズ(#1114-#1122/#1104/#1103) + PS#6 S139/S140/S141 migration timestamp collision fix (113000→113100/114500→114800/116000→116100) + equal_keys_in_map noom/15five/360learning検出',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
