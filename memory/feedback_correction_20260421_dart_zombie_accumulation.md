---
name: dart zombie プロセス蓄積 → analyze hang 連鎖
description: dart/flutter analyze が 0 bytes 無限 hang したら analysis-server zombie 疑い — 4h+ 経過 dart process を kill で復旧
type: feedback
---

**Rule**: `dart analyze` / `flutter analyze` が 0 bytes で無限 hang したら、まず **dart zombie プロセス** を疑う。

**Why**: 2026-04-21 07:15 VSCode版 S-recovery にて、セッションが 7h+ 進行不能に陥った。調査で判明:
- dart PID 48896 (2026-04-20 15:39 起動 = 15h+) が dart analysis-server の file lock を占有
- 新規 `dart analyze` は lock 取得待ちで永久 block (出力 0 bytes / CPU 使用率 ~0%)
- 合計 11 本の dart zombie (最古: 2026-04-19 18:46 = 36h+) が累積していた
- 同時に Claude プロセス 2 本 (PID 10880 CPU 9732s / PID 63232 CPU 7642s) も暴走

**How to apply**:
1. `dart analyze` hang 検知 → `Get-Process dart | Select-Object Id,StartTime,CPU` で一覧
2. StartTime が 4h 以上前の dart プロセスを全 kill:
   ```powershell
   Get-Process dart | Where-Object {$_.StartTime -lt (Get-Date).AddHours(-4)} | Stop-Process -Force
   ```
3. `.claude/scheduled_tasks.lock` が stale (PID が既に死んでいる or 1h+ 古い) なら削除
4. 復旧後 `dart analyze <file>` を絶対パス + no pipe で実行 (pipe hang は別 rule [DART-FORMAT])

**副次予防策** (session-start-check への組込み候補):
- セッション冒頭で `Get-Process dart | Where StartTime -lt (Now.AddHours(-4))` を count
- 4h+ zombie が存在 → 警告表示 or 自動 kill
- 並行インスタンス (VSCode + Win + PS6) の重複起動で zombie 累積しやすい
