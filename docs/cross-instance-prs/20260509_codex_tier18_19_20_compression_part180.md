# Codex Hand-off: Tier 1.8 / 1.9 / 2.0 Mandatory Per-Session Compression

**Source spec**: `docs/DISK_HYGIENE_RUNBOOK.md` §14 (= part 180 新設)
**期限**: 2026-05-23 | **Codex #2 完全案件** ([INSTANCE-ROLES] 5 質問 0/5 YES)

## Why now

**実測**: C: free part 178b 86.6 GB → part 180 71.1 GB = **-15.5 GB / 1 day** vs 既存 Tier 1-1.7 reclaim **0.5 MB / session** (= 捕捉率 0.003%).

**隠れ負債発見** (= part 180 PowerShell scan):
- `~\AppData\Local\Temp` recursive = **8.5 GB** (Tier 1 step 1 の 7-day filter で取り逃し)
- `~\AppData\Roaming\npm` = **2.0 GB** (完全未対象)
- `~\AppData\Local\pnpm` = **2.5 GB** (完全未対象)
- 合計約 **13 GB** が現状取り逃し → -15.5 GB / day と整合

User 要求 (= 2026-05-09): 「**毎回のセッションで必ず** メモリ + HDD を圧縮」.

## 実装スコープ

### A. `~\.claude\hooks\disk-cleanup.ps1` 拡張

**Step 1 拡張 (= Tier 1.9 Temp 深層 sweep)**:
```ps1
# 1.9.1 - サブディレクトリ単位の latest mtime > 14 day なら dir ごと削除
$tempDirs = Get-ChildItem $env:TEMP -Directory -Force -EA SilentlyContinue
foreach ($d in $tempDirs) {
    $latest = (Get-ChildItem $d.FullName -Recurse -Force -EA SilentlyContinue |
              Measure-Object LastWriteTime -Maximum).Maximum
    if ($latest -and $latest -lt (Get-Date).AddDays(-14)) {
        Remove-Item $d.FullName -Recurse -Force -EA SilentlyContinue
    }
}
# 1.9.2 - Temp 直下 *.tmp / *.log / *.etl / *.dmp は 7 day で削除
$totals['temp_subtree_14d_MB'] = <reclaim 値>
```

**Step 11 新設 (= Tier 1.8 Package manager cache)**:

| sub-step | command | filter |
|---|---|---|
| 11.1 pnpm | `pnpm store prune` (native) | size > 100 MB 時のみ実行 |
| 11.2 npm-cache | mtime > 30 day file 削除 | `~\AppData\Roaming\npm-cache\_cacache\content-v2\sha512\**` |
| 11.3 pub-cache | mtime > 30 day | `~\.pub-cache\hosted` |
| 11.4 pip cache | mtime > 14 day | `~\.cache\pip` |
| 11.5 yarn cache | mtime > 14 day | `~\AppData\Local\Yarn\Cache` |
| 11.6 gh cache | mtime > 7 day | `~\.cache\gh` |

各 sub-step は **`--max-runtime-sec=10` cap**, log key `tier_1_8_<name>_MB`.

### B. `~\.claude\hooks\memory-cleanup.ps1` 拡張

**Step 6 新設 (= RAM trim Phase 2 / 非 admin 動作可)**:

```ps1
$targets = Get-Process -EA SilentlyContinue | Where-Object {
    $_.Name -match '^(claude|code|node|electron|Code|Cursor)' -and
    $_.WorkingSet64 -gt 200MB -and
    ((Get-Date) - $_.StartTime).TotalMinutes -gt 10
}
foreach ($p in $targets) {
    try { [void]$p.MinWorkingSet; $p.MinWorkingSet = 1MB } catch {}
}
```

log: `ram_trim_count: <数>` / `ram_trim_total_mb_freed: <approx>`.

### C. `~\scripts\session_delta_tracker.ps1` 新設 (= Tier 2.0)

```ps1
# CSV append: ts,session_id,phase,c_free_gb,reclaim_mb_session,reclaim_mb_7d_median
# phase: start | end
# session_id: $env:CLAUDE_SESSION_ID or short-hash worktree dir name
# 7-day median: 過去 7 日 reclaim の median
```

`~\.claude\settings.json` SessionStart + SessionEnd hook に追加 (= 既存 disk-cleanup.ps1 直前).

### D. `~\scripts\cleanup_report_notify.ps1` 拡張 (= 警告 trigger)

| 条件 | action |
|---|---|
| 7-day median reclaim < 100 MB | `~\cleanup_reports\warning_<ts>.md` 生成 + Claude additionalContext |
| C: free 7-day delta < -3 GB | 同上 + `gh issue create --label disk-hygiene,auto-generated` |
| C: free < 30 GB | RED alert (= SessionStart 最優先 instruction) |

## 受け入れ条件

- [ ] `disk-cleanup.ps1` で `tier_1_8_pnpm_MB` / `tier_1_8_npm_MB` / `temp_subtree_14d_MB` log key 出力
- [ ] 7-day median reclaim ≥ 500 MB / session 達成 (= 1 week 観測後)
- [ ] `session-delta.csv` SessionStart + SessionEnd で append
- [ ] `memory-cleanup.ps1` step 6 で `ram_trim_count` log
- [ ] 警告閾値 trigger 動作確認 (= 模擬 free < 30 GB / 模擬 reclaim 0 で test)
- [ ] PR 内に 1-week dry-run 結果サマリ + 実 reclaim GB 数

## 参考

- `docs/DISK_HYGIENE_RUNBOOK.md` §14 (= 本 hand-off の正本)
- 既存 hooks: `~\.claude\hooks\disk-cleanup.ps1` + `~\.claude\hooks\memory-cleanup.ps1`
- 設定: `~\.claude\settings.json` `hooks.SessionStart` + `hooks.SessionEnd`
- 過去 hand-off pattern: part 178 Tier 1.6 / part 179 Tier 1.7 (= 同じ「既存 hook 拡張」pattern)

## Workdir 注意 ([WORKDIR-ISOLATION])

home dir (`~\.claude\hooks\` + `~\scripts\`) 編集は worktree 経由ではなく:
- Codex 直接編集 OK (= main repo + home file は分離 / WIP commit 不要)
- ただし `docs/` 編集は worktree (`.claude/worktrees/instance-codex`) 経由必須.
