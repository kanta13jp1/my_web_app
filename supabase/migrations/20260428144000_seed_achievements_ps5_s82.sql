-- PS#5 S82: SQLSTATE 23514 再発解消 — time-relative migration fix
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#5 S82: SQLSTATE 23514 再発解消 — wbs_tasks recovery_plan 直接 fix',
  'task 714ee4a4 (deadline 2026-04-27) の recovery_plan NULL が SQLSTATE 23514 を連発。'
  '20260426090000 の backfill が CURRENT_DATE 比較で "未来日" としてスキップされた time-relative '
  'non-determinism が根本原因。20260426095000 に新 migration を挿入して 100000 より前に '
  'recovery_plan をセット。CI deploy ブロック 3 件を解消。'
  'また cross-instance-pr (20260428_flutter_vm_test_js_interop_fix_win.md) を起票し '
  'dart:js_interop conditional imports を Win版/VSCode版に handoff。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
