# Win Codex hand-off: WBS Top 5 期限近順 batch + v13 SessionEnd mandatory fire spec (part 199)

> **作成**: 2026-05-11 月曜 / Win版 (Claude Code) part 199
> **宛先**: Win版 (Codex CLI) — 5/12 火曜以降 sprint 開始
> **trigger**: user explicit ask part 199 「WBS のタスクを期限が近いものから進めてください。2 インスタンス制も反映してください。」+ 「毎回 session で必ず memory + HDD 圧縮施策」
> **依存**: PR #2335 (part 199 ROADMAP) merge 後実装可
> **Win Claude 役割完了**: spec ship + hand-off 完了 / 実装 = Win Codex
> **Philosophy**: [INSTANCE-ROLES] = Win Claude architect / Win Codex 実装 / [SYNERGY-30] cross-instance-pr 7 原則

---

## Part A: WBS Top 5 期限近順 batch (= 5 task / 全 Win Codex 担当)

### A.1 期限近順 priority table

| # | issue | title | 期限 | T 値 (today=5/11) | recommended action | evidence |
|---|-------|-------|------|-------------------|-------------------|----------|
| 1 | [#2171](https://github.com/kanta13jp1/my_web_app/issues/2171) | WBS タスク重複 Phase 2 修正 (= dedup v2 + UNIQUE INDEX 強制再作成) | 5/22 | T+11 | 5/12 T+3 ping + Step 1 投稿 confirm | part 198 user 154 + codex 451 task / 9+ duplicate / migration 20260425203000 cartesian INSERT 原因 |
| 2 | [#2186](https://github.com/kanta13jp1/my_web_app/issues/2186) | dev_cache_cleanup --tier18 4 command Win 互換 fix (= dart/pip/npm/pnpm) | 5/23 | T+12 | 5/12 T+3 ping + priority bump | v11 §17.16 ship / v12 spec ship / 月内 3 例 consolidation = 27.35→9.90 KB / dev_cache wiring で disk 圧迫予防 |
| 3 | [#1741](https://github.com/kanta13jp1/my_web_app/issues/1741) | PWA self-touch widget | 5/23 | T+12 | merge confirmed `bb76bd83e` (part 194 verify) | ✅ DONE |
| 4 | v5 hook wiring 5 task (Tier A-E) | (= part 190-b spec ship) | 5/23-5/28 | T+12 to T+17 | 5/12 T+3 ping per Tier | v9 SessionStart 7 hook 配線済 (= -5.2pt 自走 RAM 軽減 / part 195 verify) / 残 Tier B/C/D/E 配線必要 |
| 5 | [#1124](https://github.com/kanta13jp1/my_web_app/issues/1124) | GPA Phase 1 PR | 5/30 | T+19 | 5/13 T+4 ping (= 1 day buffer) | Phase 4 完了済 / Phase 1 PR 残 |

### A.2 Codex action 5/12 T+3 fire (= 火曜 / 当日 batch ping)

```bash
# 火曜 5/12 JST 当日に Codex CLI 起動 + 以下順 fire:

# 1. #2171 WBS dedup Phase 2
gh issue comment 2171 --body "Codex sprint T+3 ping (= part 199 hand-off / 5/12 火曜).

Win Claude part 198 Finding A (MEMORY.md consolidation 第 3 例 = -63% trim) + part 199 verify-only minimal session 第 1 例 dogfood pattern 確立.

next step recommend (= Codex 担当):
1. dedup_v2 SQL migration drafting (= UNIQUE INDEX 強制再作成 / cartesian INSERT 修正)
2. Step 1 PR open (= scoped / docs-only label 適用 / 既存 cascade pattern 利用)
3. T+4 escalation = 5/13 (= 1 day buffer)

evidence: docs/cross-instance-prs/20260511_codex_wbs_top5_v13_session_end_part199.md (= 本 doc)"

# 2. #2186 dev_cache priority bump (= v11/v12 evidence)
gh issue comment 2186 --body "Codex sprint T+3 ping (= part 199 hand-off / 5/12 火曜) — priority bump justification:

Win Claude part 198 v12 spec + part 199 v13 spec (= 本 doc Part B) で SessionStart + SessionEnd 両層配線が必要.
v13 SessionEnd hook が dev_cache wiring (= #2186) 依存 = wrap-up 時 cleanup mandatory fire 不可能のまま.

evidence:
- part 197 v11 §17.16 (= 85% threshold lower / post-resume mandatory fire)
- part 198 v12 spec (= 3 Finding A consolidation + B memory_size_check.ps1 + C auto-label)
- part 199 v13 spec (= SessionEnd mandatory fire / 本 doc)
- 月内 3 例 consolidation burst rate (= part 162 / 194 / 198)

priority bump 推奨 = T+12 → T+5-7 (= 緊急度 up). 詳細: docs/cross-instance-prs/20260511_codex_wbs_top5_v13_session_end_part199.md"

# 3. v5 hook wiring (= 5 task / per Tier ping)
gh issue comment <Tier B issue#> --body "Codex sprint T+3 ping (= part 199 hand-off / 5/12 火曜).
Tier B/C/D/E 配線が v13 SessionEnd hook (= 本 doc Part B) の前提依存. Tier A (= memory_trim_phase2) 配線済 / 残 4 Tier 5/12-5/28 sprint 推進推奨."

# 4. #1124 GPA Phase 1 PR
# T+4 = 5/13 ping schedule (= 当日 skip)
```

### A.3 全 5 task Codex ownership confirmation

| task | Codex sprint owner | start date | sprint end |
|------|-------------------|------------|-----------|
| #2171 WBS dedup Phase 2 | Win Codex | 5/12 fire | 5/22 (= T+11 limit) |
| #2186 dev_cache 4 cmd | Win Codex | 5/12 fire | 5/23 (= T+12 limit / priority bump で T+5-7 推奨) |
| v5 hook Tier B-E | Win Codex | 5/12 fire | 5/28 (= T+17 limit) |
| #1124 GPA Phase 1 PR | Win Codex | 5/13 fire | 5/30 (= T+19 limit) |

→ 全 4 active task (= #1741 完了済除外) Win Codex sprint owner. Win Claude = monitor + verify-only.

---

## Part B: v13 SessionEnd mandatory fire spec (= 「毎回必ず圧縮」discipline)

### B.1 problem statement

User explicit ask part 199:
> 「今の開発フローだと、ローカル環境のメモリやハードディスク容量が必ず枯渇します。毎回のセッションで必ずメモリやハードディスク容量を圧縮する施策を検討してください。」

### B.2 既 layer audit (= part 162 → 199 累積)

| version | layer | trigger | scope | status |
|---------|-------|---------|-------|--------|
| v6 (part 191) | manual fire | mid-session user ask | RAM 1666 MB band | shipped |
| v7 (192-b) | immediate fire delta | user verify | RAM 946.7 MB | shipped |
| v8 (193) | RAM+C: 連動 | mid-session | RAM 1457.8 MB / C: 大量 | shipped |
| v9 (194-195) | SessionStart 7 hook | session 起動時 auto | -5.2pt 自走 RAM 軽減 | shipped + verified |
| v10 (196 phase 2) | mid-session 85%+ build-up | trigger reactive | 1686.9 MB peak | shipped |
| v11 (197) | 85% threshold lower + post-resume | post-resume mandatory | reactive | shipped + part 198/199 verified |
| v12 spec (198) | Finding A+B+C | (= consolidation + memory_size_check.ps1 + auto-label) | preventive | spec ship / Win Codex 5/30 |
| **v13 spec (199 / 本 doc)** | **SessionEnd mandatory** | **wrap-up 時 / Bash exit 時** | **0 件 missed session 保証** | **spec ship / Win Codex 5/30** |

### B.3 gap detection: SessionEnd fire 不在

現状 7 hook (= SessionStart 7) は**起動時のみ fire**. mid-session = 85% threshold reactive trigger だが session 終了直前に build-up した case で fire 不発. e.g.:

- session 直前 RAM 70% → mid-session 84% (= < 85% threshold) → wrap-up → 終了時 RAM 84% 維持 → 次 session 起動時 RAM 84% (= < 85% threshold) → fire skip → build-up が 90%+ になるまで fire 不発 = **2 session 跨ぎ漏れ**

→ **「毎回必ず」を保証するには SessionEnd hook 必須**.

### B.4 v13 spec (= SessionEnd mandatory fire)

#### B.4.1 hook 配線 (Win Codex 5/30 担当)

```json
// settings.json または settings.local.json に追記
{
  "hooks": {
    "SessionEnd": [
      {
        "type": "command",
        "command": "powershell -ExecutionPolicy Bypass -File \"C:\\Users\\kanta\\.claude\\hooks\\session_end_compression.ps1\"",
        "blocking": false,
        "timeout": 30000
      }
    ]
  }
}
```

#### B.4.2 `session_end_compression.ps1` 仕様

```powershell
# C:\Users\kanta\.claude\hooks\session_end_compression.ps1
# v13 spec / part 199 / Win Codex 5/30 implement

$ErrorActionPreference = 'Continue'
$logPath = "$env:USERPROFILE\.claude\logs\session_end.log"

# 1. RAM measure pre
$os = Get-CimInstance Win32_OperatingSystem
$ramPctPre = [math]::Round((1 - ($os.FreePhysicalMemory / $os.TotalVisibleMemorySize)) * 100, 2)
$cFreePre = [math]::Round((Get-PSDrive C).Free / 1GB, 2)

# 2. memory_trim_phase2 fire (= mandatory / threshold 不問)
& "$env:USERPROFILE\.claude\hooks\memory_trim_phase2.ps1" 2>&1 | Out-Null

# 3. RAM measure post
$os2 = Get-CimInstance Win32_OperatingSystem
$ramPctPost = [math]::Round((1 - ($os2.FreePhysicalMemory / $os2.TotalVisibleMemorySize)) * 100, 2)
$cFreePost = [math]::Round((Get-PSDrive C).Free / 1GB, 2)
$ramDelta = [math]::Round($ramPctPre - $ramPctPost, 2)
$cFreeDelta = [math]::Round($cFreePost - $cFreePre, 2)

# 4. log to session-delta.csv
$row = "{0},session_end,{1},{2},{3},{4},{5}" -f (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'), $ramPctPre, $ramPctPost, $ramDelta, $cFreePre, $cFreeDelta
Add-Content -Path "$env:USERPROFILE\.claude\logs\session-delta.csv" -Value $row -Encoding UTF8

# 5. exit success regardless (= non-blocking)
exit 0
```

#### B.4.3 `/wrap-up` skill Step 0 統合 (= 補助 layer)

```markdown
## Step 0 (新 / part 199 v13): mandatory pre-fire

wrap-up 開始時に **memory + HDD 圧縮を必ず先行 fire**:

1. PowerShell `~/.claude/hooks/memory_trim_phase2.ps1` 実行
2. RAM% + C: free 値 log
3. Step 1-7 続行
```

#### B.4.4 KPI (= part 200+ verify 用)

| metric | baseline (part 199 末尾) | v13 target | measurement |
|--------|------------------------|-----------|------|
| session 終了時 RAM% | 83.43% | < 85% (= v11 threshold) | session_end.log |
| session 終了時 C: free | 57.98 GB | > 50 GB | session_end.log |
| 終了-起動 RAM delta | (= 未測定) | < 5 pt | session-delta.csv `session_end` row |
| 「毎回必ず fire」compliance | 0/N (= 現状未配線) | N/N (= 100%) | session_end.log row count |

#### B.4.5 Bash exit fallback (= 補助 layer / Win Codex optional)

PowerShell hook 未対応 case 用に Bash session も同等 fire 可能:

```bash
# ~/.bashrc または session 終了 hook 経由
trap '~/.claude/hooks/memory_trim_phase2.sh' EXIT
```

(= Win 環境 Bash trap EXIT は cygwin / git-bash で動作 / 但し SessionEnd hook が primary)

### B.5 v13 acceptance criteria (= Win Codex deliverable)

- [ ] `~/.claude/hooks/session_end_compression.ps1` 配線 (= B.4.2 spec 準拠)
- [ ] `~/.claude/settings.json` SessionEnd hook 追加 (= B.4.1)
- [ ] `/wrap-up` skill Step 0 mandatory pre-fire 追記 (= B.4.3)
- [ ] `~/.claude/logs/session-delta.csv` `session_end` row 検証 (= part 200+ session 終了で 1+ row 追加)
- [ ] DISK_HYGIENE_RUNBOOK §17.18 v13 章追加 (= 既存 doc 章追加 pattern 第 12 例 / part 200 cascade post-merge ship)

### B.6 dependency

- v9 SessionStart 7 hook (= 配線済)
- v11 §17.16 spec (= PR #2328 BLOCKED / admin merge 待ち)
- v12 spec 3 Finding (= PR #2331 BLOCKED / admin merge 待ち)
- **v13 = v9 + v11 + v12 上に積層 / part 200 cascade post-merge 後実装推奨**

### B.7 risk

- **SessionEnd hook timeout**: 30s 以内に fire 必要 / `memory_trim_phase2.ps1` 実測 ~5-15s safe band
- **non-blocking 必須**: Bash 終了 block 回避 / `blocking: false` + `exit 0` ensure
- **log path 競合**: 複数 instance 並行 session で append race condition (= mutex 不要 / Add-Content atomic / Win NTFS guarantee)
- **wrap-up skill 既存 step 衝突**: Step 0 新規追加 (= step 番号 shift なし / 1-7 unchanged)

---

## Part C: Win Codex 5/12 sprint plan (= recommended)

### C.1 day 1 (= 5/12 火曜 / T+3)

- 9:00 JST: 起動時 v9 verify (= part 200 fresh start) + v11 85% threshold verify
- 10:00: #2171 WBS dedup Phase 2 Step 1 PR draft (= 既存 issue / Codex 担当 既決)
- 12:00: #2186 dev_cache 4 cmd Win 配線 PR (= priority bump justification with v11/v12/v13 evidence)
- 14:00: v5 hook Tier B 配線 PR (= 既 spec ship / 残 4 Tier 順次)
- 16:00: v13 SessionEnd hook 配線 PR (= 本 doc Part B 仕様準拠)

### C.2 day 2-7 (= 5/13-5/18 sprint)

- v5 hook Tier C/D/E sequential
- #1124 GPA Phase 1 PR review + merge
- DISK_HYGIENE §17.17 (v12) + §17.18 (v13) 既存 doc 章追加 cascade

### C.3 day 8-11 (= 5/19-5/22 buffer)

- #2171 deadline 5/22 final check
- 全 5 task ship verification

---

## Part D: Win Claude follow-up (= 5/12 part 200 fresh start)

### D.1 part 200 第 1 task

- cascade post-merge wave verify (= #2331 + #2328 + #2323 + #2335 全 admin merge 確認)
- ROADMAP part 196/197/198 batch backfill
- main HEAD §17.14 → §17.15 → §17.16 順序整合 verify
- 5/12 T+3 Codex ping batch fire (= 本 doc 経由 Codex 認知)

### D.2 part 200+ DISK_HYGIENE §17.18 v13 章追加 PR

- cascade post-merge 後実装
- 「既存 doc 章追加 pattern」第 12 例
- v6-v13 累積 8 KPI table

---

## Philosophy alignment

- [INSTANCE-ROLES] ✅ (= Win Claude architect / Win Codex 実装)
- [SYNERGY-30] 6/7 ✅ (= cross-instance-pr / handover / SLA / 5 正本 / 1 task 1 owner / dogfood)
- [PHILOSOPHY-22] 6/9 ✅ (= 4 mentor / 5 商品=価値 / 6 時間=資本 / 7 資産負債 / 8 KPI / 9 IPO)
- [VIBE-30] 6/7 ✅ (= verify-first / no-scope-creep / discipline)
- [BRAIN-32] 7/7 ✅ (= memory ship + cross-instance-pr + Karpathy 4 サイクル integration)
- [INDIE-29] 6/7 ✅ (= shipping discipline / dogfood / cumulative pattern / spec-first)

---

## next session 担当 boundary 明示

- **Win Claude part 200 (5/12+)**: monitor + cascade verify + ROADMAP backfill (= NOT 直接実装)
- **Win Codex 5/12+ sprint**: 全 4 active task implementation + v13 hook 配線 + DISK_HYGIENE 章追加 cascade
- **2-instance separation**: 維持 / cross-instance-pr 経由 hand-off discipline 厳守

---

> **Generated**: 2026-05-11 月曜 / Win版 (Claude Code) part 199 / verify-only minimal session 第 1 例 / 132 part 連続 dogfood
> **Co-Authored**: Claude Opus 4.7 (1M context)
