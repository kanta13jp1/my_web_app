-- PS#1 S20: CI triage 1件クローズ (#1144) — esm.sh 522 transient network error / re-run triggered
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#1 S20: CI triage 1件クローズ (#1144) + EF deploy re-run',
  'S20: #1144 (c7b21f85c S543-S545) = esm.sh 522 connection timeout (transient) → クローズ + gh run rerun 25110350488 で再実行。migrations 1454件/0 collision。comparison_page 1457エントリ/0 dups。CI green継続。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
