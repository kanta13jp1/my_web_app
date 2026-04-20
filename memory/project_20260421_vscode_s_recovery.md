---
name: VSCode版 S-recovery 2026-04-21 07:15
description: 7h+ セッション異常の root cause = dart zombie 11 本 + claude 暴走 2 本 → 15 min で cleanup + VSCode handoff PR resolved
type: project
---

**Fact**: 2026-04-21 07:15 VSCode版でユーザー報告「7h以上セッションが続いています。異常」→ cleanup で復旧。

**Why**: ユーザーの時間 (Philosophy 原則 6 = 資本=時間) を 7h+ 無駄にしていた。
- dart zombie 11 本 (最古 36h+) が analysis-server lock 占有 → `dart analyze` 連続 hang
- Claude プロセス 22 本並列 (暴走 2 本含む) で CPU 圧迫
- stale `.claude/scheduled_tasks.lock` (PID 61856 / 15.5h 保持)

**How to apply**:
- 将来、session 起動から 3h+ 経過で dart 関連コマンドが hang していたら本 memory 参照
- cleanup template は `memory/feedback_correction_20260421_dart_zombie_accumulation.md` を reuse
- VSCode/Win/PS 並行インスタンスは dart zombie を共有するので、単独インスタンスで cleanup しても全体に効く

**本セッション成果**:
- **0c729cc4** docs: VSCode handoff PR archive (20260420_wbs_gantt_ui_filter_vscode → done/)
- **4f93860f** feat: WBS tab hideCompleted checkbox + 開始予定/完了予定 label (auto-commit)
- PS#2 S17 handoff task 1/3 (未完了 filter + date relabel) 消化

**残課題 (別セッション)**:
- PS#2 S17 handoff task 2 (fetch 経路確認 Network tab) / task 3 (planned label は完了済)
- dart zombie auto-cleanup hook (session-start-check 拡張 or PreToolUse on Bash)
