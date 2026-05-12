# 2026-05-13 Win Codex 担当: v19 mandatory per-session compression CONTRACT (= 5 deliverable / 累積 27 件 5/30 期限)

## 概要

Win版 (Claude Code) part 207 (2026-05-13 水曜 00:51 JST) で **v19 mandatory per-session compression CONTRACT** 仕様 ship 完了. user 直接 ask に基づき v15-v18 18 layer 既 ship + manual 4 fire (2349 MB 累積解放) でも C: 4.4 GB/day drop が続いている問題に対し, **quota contract gate** を中核とする 5 layer (P-T) を追加.

Codex impl 担当: Win Codex CLI (= Win版 Codex CLI 担当 / 2-instance 制) / 既 22 件 (= v17 17 + v18 5) に対し追加 5 件 = **累積 27 deliverable / 5/30 期限**.

## v19 仕様 source

[`docs/DISK_HYGIENE_RUNBOOK.md`](../DISK_HYGIENE_RUNBOOK.md) §17.22 全 6 sub-section (= 17.22.1 ~ 17.22.6).

## 5 deliverable (= Layer P-T)

### 1. `.claude/hooks/session_start_pre_metric.ps1` + `.claude/settings.json` 更新 (= Layer P)

- SessionStart hook 登録
- PRE RAM% + C: free GB capture 必須
- session-delta.csv start row 強制 write
- RAM > 90% 検出時 exit 1 (= fail-closed)
- output: stdout に PRE metric + warnings

```powershell
# scaffold (= Codex impl)
$ram = Get-CimInstance Win32_OperatingSystem
$pct = (1 - $ram.FreePhysicalMemory / $ram.TotalVisibleMemorySize) * 100
if ($pct -gt 90) { exit 1 }
# session-delta.csv start row write
python scripts/session_delta_tracker.py --phase start --session-id $env:SESSION_ID
```

### 2. `scripts/mid_session_auto_fire.ps1` + Win Task Scheduler PT30M (= Layer Q)

- wall-clock 30min cron
- RAM > 85% 検出時 dev_cache_cleanup --apply --tier18 auto fire
- mid-fire.log append (= timestamp / PRE/POST metric / reclaim_mb)
- block tool call 1 turn while running

### 3. `scripts/wrap_up_contract_gate.py` + `.claude/hooks/session_end_contract.ps1` (= Layer R / 中核)

- session-delta.csv 末尾 end row 読込
- quota check OR condition:
  - (a) reclaim_mb_session ≥ +500 MB
  - (b) RAM delta ≤ -5.0 pt
  - (c) C: free delta ≥ +0.5 GB
- quota miss → exit 1 + warning_<date>.md + flag for next session PRE force fire
- contract.log append

```python
# scaffold
def check_quota(session_id):
    rows = read_csv(session_id)
    reclaim = rows.end.reclaim_mb
    ram_delta = rows.start.ram_pct - rows.end.ram_pct
    c_delta = rows.end.c_free_gb - rows.start.c_free_gb
    if reclaim >= 500 or ram_delta >= 5.0 or c_delta >= 0.5:
        return True
    return False
```

### 4. `scripts/memory_md_auto_rotate.py` + Win Task Scheduler daily 03:00 (= Layer S)

- `~/.claude/projects/.../memory/MEMORY.md` size check
- 20 KB threshold → archive split to MEMORY_<YYYYMM>_archive.md
- 30 KB block memory write (= fail-closed)
- rotation.log append

### 5. `scripts/worktree_max_enforce.py` (= Layer T / 既存 worktree_cleanup.py 拡張)

- 新 worktree 作成時 active worktree count check
- > 5 active → stale prune force (= --apply mandatory)
- block create if still > 5 after prune
- worktree-prune.log append

## session_kpi.py 拡張 (= 5 metric NEW / 累積 23)

```python
# v19 5 metric NEW
{
  "pre_metric_captured": bool,
  "mid_session_fired_count": int,
  "quota_contract_met": bool,  # 必須 wrap-up gate
  "memory_rotation_count": int,
  "worktree_active_count": int,
}
```

## 期限

- 全 5 deliverable: **2026-05-30 (金)**
- 累積 27 件 (= v17 17 + v18 5 + v19 5)
- 残 17 day

## 検証 (= Win Claude 担当)

Win Claude part 208 以降で:
1. `quota_contract_met` 数値 verify (= rolling 7-session average)
2. Layer R wrap-up gate exit 1 動作確認 (= deliberate quota miss test)
3. Layer Q mid-session fire trigger 動作確認 (= RAM > 85% deliberate state)
4. Layer S MEMORY.md rotation 動作確認 (= 20 KB threshold test)

## 2-instance flow

- **Win Claude (= 本 doc author)**: architect / spec ship / triage / 検証
- **Win Codex CLI**: 5 deliverable impl / GHA + Win Task Scheduler 設定 / 単体 test

## 関連

- 既 22 件: `docs/cross-instance-prs/20260512_codex_wbs_top5_v18_disk_hygiene_cascade_part204b.md` (= v17 17 + v18 5)
- 7d critical signal: Issue #2186 (= 7d -30.96 GB / threshold 10x breach)
- v19 spec source: `docs/DISK_HYGIENE_RUNBOOK.md` §17.22
