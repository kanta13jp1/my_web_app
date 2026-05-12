# Codex Hand-off — Win版 part 201-b / WBS Top 5 + v15 Guaranteed Compression Protocol

**Date**: 2026-05-11 月曜 (= part 201-b mid-session escalation / part 200-b v14 hand-off batch pattern 第 3 例累積 / 同日 3 doc 連続 hand-off)
**From**: Win Claude (= architect / docs / memory / UI design / triage)
**To**: Win Codex (= 実装 / 修正 PR / SQL / EF Deno / GHA / T-1 dispatch / 競馬 / Karpathy Compile-Lint)
**Pattern**: 2-instance hand-off batch 第 3 例累積 / single doc 統合 / iterative ask v3-v14 累積 14 layer trace
**Trigger**: user ask 「ローカル RAM/HDD 必ず枯渇 / 毎セッション圧縮施策」+ 「WBS 期限近順 + 2 instance 反映」

---

## Part A — WBS Top 5 期限近順 batch (= 2-instance 制反映 / 5/12 火曜 = T+3 当日)

| # | issue | 期限 | T-N | instance | 状態 | 5/12 ping action |
|---|-------|------|-----|----------|------|------------------|
| 1 | #2171 WBS dedup Phase 2 (= 9+ duplicate cleanup) | 5/22 | T-11 | Win Codex | OPEN / dedup v2 + UNIQUE INDEX 強制再作成 | T+3 = 5/12 ping (= 翌日 当日) |
| 2 | #2186 dev_cache 4 cmd Win (= dart/pip/npm/pnpm) | 5/23 | T-12 | Win Codex | OPEN / hygiene / infra label / v14 dependency | T+3 = 5/12 ping with v11/v12/v14/**v15** evidence |
| 3 | v5 hook wiring 5 task (Tier B-E) | 5/23-5/28 | T-12 to T-17 | Win Codex | sequential 推進 | T+3 = 5/12 ping with v15 SessionStart+End hook spec |
| 4 | #1124 GPA Phase 1 PR | 5/30 | T-19 | Win Codex | spec ship | T+4 = 5/13 ping (= 5/12 skip) |
| 5 | **v15 guaranteed per-session compression** (= 本 doc Part B) | **5/30** | T-19 | Win Codex (impl) + Win Claude (spec) | spec ship 本 doc | T+3 = 5/12 batch 同梱 |

### Win Claude 側 cascade (= 期限近順 / 5 dogfood from part 201)

| # | task | 期限 | role |
|---|------|------|------|
| 1 | 5/12 T+3 Codex sprint ping batch fire 当日 (= 4 prefab) | 5/12 | Win Claude architect |
| 2 | PR cascade 5+ PR admin merge 確認 + ROADMAP backfill | 5/12-5/14 | Win Claude architect |
| 3 | DISK_HYGIENE §17.17 v14 + §17.18 v15 章追加 PR | 5/14-5/15 | Win Claude docs |
| 4 | v15 Tier 1 baseline update (= part 201 +2216.2 MB record) | 5/14 | Win Claude memory |
| 5 | UI verify 4 page (= [UI-VERIFY] backlog 回収) | 5/12-5/15 | Win Claude UI design |

### 2-instance 制反映 detail (= part 130-201 不変)

- **Win Codex 担当** = 5 task (= v15 impl / v14 impl / WBS dedup / dev_cache / v5 hook / GPA / 全 SQL+EF+GHA)
- **Win Claude 担当** = 5 task (= spec / docs / memory / triage / UI verify)
- 旧 12 instance dormant (= PS#1-6 / VSCode版 / WEB版 / スマホ版 / Codex#1 / Codex#2)

---

## Part B — v15 Guaranteed Compression Protocol Spec (= 毎セッション RAM/HDD 必ず圧縮)

### Why ship now (= part 201 + 201-b cumulative evidence + user ask)

**user ask**: 「今の開発フローだと、ローカル環境のメモリやハードディスク容量が必ず枯渇します。毎回のセッションで必ずメモリやハードディスク容量を圧縮する施策を検討してください。」

**v14 limit**: v14 = **threshold-triggered** (= RAM > 85% で初めて Tier 1 fire). user の懸念 = threshold 未達でも徐々に枯渇する.

**v15 delta**: **GUARANTEED per-session compression** = threshold 関係なく毎セッション必ず fire. 「user の懸念 = certainty 不足」を spec で保証.

### part 201 evidence (= 同日 12 part 連続 12 measurement)

| part | 起動 RAM% | fire 後 RAM% | freed MB | C: GB | MEMORY KB | 備考 |
|------|-----------|--------------|----------|-------|-----------|------|
| 194 | 95.8% | 84.4% | +1457.8 | TBD | 36→19 | RAM 95% band immediate fire 第 1 例 |
| 195 | 92.9% | 87.7% | TBD | TBD | TBD | v9 auto-fire functional verify |
| 196 ph2 | 79.43→92.17% | TBD | +1686.9 | 71.81→52.76 | TBD | 60min build-up critical / 旧 record |
| 197 | 92.64% | 87.53% | (post-resume gap) | TBD | TBD | v9 verify FAIL |
| 198 | 81.72% | (skip) | 0 | TBD | TBD | v11 verify SUCCESS 第 1 例 / skip |
| 199 | 83.43% | (skip) | 0 | TBD | TBD | v11 verify SUCCESS 第 2 例 / skip |
| 200 | 94.34% | 93.36% | **-20.7 NEGATIVE** | TBD | TBD | manual fire breach 第 1 例 / OS realloc 即時消費 |
| 200-b | TBD | TBD | TBD | 62.4 | TBD | v14 spec ship (= mid-session) |
| **201** | **85.04%** | **74.22%** | **+2216.2** | **53.37→53.33** | **14.92→16.85** | **過去最大 record update / +31% vs 旧 record** |

**finding 1**: v11 threshold (= 85%) **未達でも MEMORY.md 14.92 KB / C: 53.37 GB 残** = 徐々に drift 蓄積.
**finding 2**: v11 verify SUCCESS でも fire skip (= 第 1, 第 2 例) → **drift mitigation 機会 loss**.
**finding 3**: 起動時 85.04% (= 第 7 例) = v11 threshold 直上 ± 1pt band で fire vs skip flip-flop = certainty なし.

**結論**: threshold-triggered protocol では「毎セッション必ず圧縮」のユーザー要求 = **保証不可能**. v15 = guaranteed mandatory fire 必須.

### v15 Spec body

```yaml
title: v15 — 毎セッション GUARANTEED memory/disk compression
mandatory: true (= regardless of threshold / regardless of state)
trigger: SessionStart + PostToolUse N-interval + SessionEnd 3 layer × always-fire
parent: extends v14 (= threshold-triggered 4-tier) with always-fire guarantee

memory_compression_track:
  Layer 1 — SessionStart mandatory fire (= 既存 v9 + always-fire NEW):
    fire: memory-cleanup.ps1 (= regardless of RAM%)
    timing: hook 起動直後 5 sec 以内
    log: ram_trim_count++ + freed_MB delta
    KPI: 100% session で fire count >= 1

  Layer 2 — PostToolUse periodic trim (= NEW v15):
    fire: memory-cleanup.ps1 every N tool calls (= N=30 default)
    OR: every 30 min wall-clock since last fire
    skip_condition: fire 後 5 min 未経過 (= duplicate fire 抑制)
    KPI: session 90min 内 fire count >= 2

  Layer 3 — SessionEnd mandatory fire (= NEW v15 / v13 spec 拡張):
    fire: memory-cleanup.ps1 (= regardless of RAM%)
    timing: /wrap-up skill 実行直後
    log: session_delta.csv に final_freed_MB record
    KPI: 100% session で final fire 記録

  Layer 4 — v14 4-tier escalation (= existing fallback):
    trigger: any Layer 1-3 fire 後 RAM > 85%
    behavior: v14 spec (= Tier 1 → 2 → 3 → 4 escalation)

disk_compression_track:
  Layer 1 — SessionStart mandatory worktree_cleanup --tier1 dry-run (= 既存):
    fire: 起動直後 + warning if candidates > 0
    KPI: 100% session で report log

  Layer 2 — PostToolUse periodic worktree audit (= NEW v15):
    fire: every 60 min wall-clock
    action: worktree_cleanup --tier1 apply (= merged + 0 uncommitted only)
    KPI: 自動 worktree 削減 per session

  Layer 3 — SessionEnd mandatory tier2 fire (= NEW v15):
    fire: /wrap-up 直前
    action: worktree_cleanup --tier2 apply (= aggressive / merged worktree 全削除)
    + scripts/dev_cache_cleanup.py --tier18 (= dart/pip/npm/pnpm cache)
    KPI: session 終了時 disk delta >= 0 (= 増加禁止)

memory_file_compression_track:
  Layer 1 — SessionEnd MEMORY.md size check (= NEW v15):
    threshold: 20 KB
    action: consolidate-memory skill auto-trigger if > threshold
    KPI: MEMORY.md size <= 24 KB 維持

  Layer 2 — Monthly cleanup (= 既存 / Win Claude rotation):
    timing: 月初 1 回 manual /consolidate-memory
    action: 30+ day reference 0 entry → MEMORY_<period>.md archive
    KPI: memory/ directory file count 線形成長 < 200

session_kpi (= every session 必須 record):
  - ram_fire_count (>= 2 target / Layer 1 + Layer 3 + Layer 2 periodic)
  - ram_total_freed_MB (>= 200 MB target)
  - disk_delta_GB (>= 0 target / net free 増加 OR 不変)
  - memory_md_size_KB (<= 24 KB target)
  - memory_file_count (= MEMORY.md entry count / drift monitor)

KPI dashboard (= v15 deliverable):
  - /tmp/session_kpi.csv per-session row append
  - weekly visualization via scripts/session_kpi_dashboard.py
```

### v14 → v15 delta table

| layer | v14 | v15 |
|-------|-----|-----|
| SessionStart | threshold-triggered Tier 1 | **mandatory always-fire** Layer 1 |
| Mid-session | threshold check + 4-tier | **periodic N-interval fire** NEW Layer 2 |
| SessionEnd | (not specified) | **mandatory always-fire** NEW Layer 3 |
| Disk SessionEnd | dry-run only | **--tier2 apply mandatory** NEW |
| MEMORY.md | manual monthly | **SessionEnd auto-trigger** NEW |
| KPI | TBD | **5 metric per-session record** NEW |
| Escalation | 4-tier (= primary path) | 4-tier (= fallback only) |

---

## Part C — Codex impl 5 deliverable (= 5/30 期限)

| # | deliverable | scope | est |
|---|-------------|-------|-----|
| 1 | `~/.claude/hooks/memory-cleanup.ps1` 既存 hook を SessionStart **always-fire** 化 (= v15 Layer 1 / threshold skip 除去) | hooks/settings.json | S |
| 2 | `~/.claude/hooks/posttooluse-periodic-trim.ps1` 新規 (= v15 Layer 2 / N=30 tool call OR 30min wall-clock) | hooks/ NEW | M |
| 3 | `~/.claude/hooks/sessionend-mandatory-fire.ps1` 新規 (= v15 Layer 3 / always-fire on /wrap-up) | hooks/ NEW | M |
| 4 | `scripts/session_kpi.py` 新規 (= per-session 5 metric record + /tmp/session_kpi.csv append) | scripts/ NEW | M |
| 5 | `scripts/session_kpi_dashboard.py` 新規 (= weekly visualization / matplotlib OR plotly) | scripts/ NEW | L |

### dependencies

- #2186 dev_cache 4 cmd Win (= dart/pip/npm/pnpm cache) = v15 Layer 3 disk track 前提
- v5 hook wiring Tier B-E = v15 hook 配線 base
- v14 4-tier escalation = v15 fallback path

---

## Part D — KPI table (= v6-v15 累積 10 layer)

| version | layer focus | trigger | delta from prev | ship date | status |
|---------|-------------|---------|------------------|-----------|--------|
| v6 | initial RAM trim | threshold 90% | baseline | part 192-b | shipped |
| v7 | post-fire delta KPI | threshold 90% | + delta record | part 193 | shipped |
| v8 | 60min build-up rate | threshold 90% | + rate measurement | part 195 | shipped |
| v9 | SessionStart auto-fire | threshold 90% | + functional verify | part 194 | shipped |
| v10 | mid-session build-up | threshold 90% | + 60min interval | part 196 ph2 | shipped |
| v11 | 85% threshold lower | threshold **85%** ↓ | + post-resume mandatory | part 197 | shipped |
| v12 | MEMORY.md size + docs-only label | threshold 85% | + memory size hook spec + GHA spec | part 198 (199-b 第 1 例) | shipped |
| v13 | SessionEnd mandatory fire | threshold 85% | + N/N compliance target | part 199-b | shipped |
| v14 | 4-tier escalation | threshold 85% | + Tier 2-4 fallback | part 200-b | shipped |
| **v15** | **guaranteed per-session compression** | **always-fire (= regardless of threshold)** | + Layer 1-4 mandatory + KPI dashboard | part 201-b | **本 doc ship** |

### iterative ask v3-v14 累積 14 layer trace

| ask | session | date | ship gap | trigger |
|-----|---------|------|----------|---------|
| v3 | part 192-b | 2026-04-27 | baseline | initial RAM concern |
| v4 | part 193 | 2026-04-28 | 1 day | delta KPI |
| v5 | part 194 | 2026-05-09 | 11 day | hook wiring |
| v6-v7 | part 192-193 | 2026-04-27-28 | 0-1 day | initial layer |
| v8-v9 | part 194-195 | 2026-05-09-10 | 0-1 day | functional verify |
| v10 | part 196 ph2 | 2026-05-10 | 0 day | mid-session escalation |
| v11 | part 197 | 2026-05-10 | 0 day | post-resume cycle |
| v12 | part 198 | 2026-05-10 | 0 day | docs-only bypass |
| v13 | part 199-b | 2026-05-11 早朝 | 0 day | SessionEnd hand-off |
| v14 | part 200-b | 2026-05-11 03:12 | 0 day | manual fire breach |
| **v15** | **part 201-b** | **2026-05-11 18:40** | **0 day** | **user 「必ず枯渇」 ask** |

**iterative ask burst rate**: 月内 14 day で 14 layer = 平均 1.0 day interval / **100% ship rate** 維持.

---

## Part E — 5/12 T+3 Codex sprint ping batch (= 当日 fire prefab / 5 prefab)

### Prefab 1: #2171 WBS dedup Phase 2 ping

```
@codex T+3 (5/12 火曜) ping — #2171 WBS dedup Phase 2 progress 確認.
dedup v2 + UNIQUE INDEX 強制再作成 status?
ETA: 5/22 (= T-11 残). evidence: docs/cross-instance-prs/20260511_codex_wbs_top5_v15_guaranteed_compression_part201b.md Part A.
```

### Prefab 2: #2186 dev_cache 4 cmd Win ping (= v11/v12/v14/v15 evidence)

```
@codex T+3 (5/12 火曜) ping — #2186 dev_cache 4 cmd Win progress.
v11/v12/v14/v15 evidence: part 201 RAM 85.04% threshold breach + manual fire +2216.2 MB record + v15 Layer 3 dependency.
ETA: 5/23 (= T-12 残). dart/pip/npm/pnpm cache scope confirm?
evidence: 本 doc Part B disk_compression_track.
```

### Prefab 3: v5 hook Tier B-E 着手 ping (= v15 spec wiring base)

```
@codex T+3 (5/12 火曜) ping — v5 hook wiring Tier B-E 着手 status?
v15 SessionStart always-fire + PostToolUse periodic + SessionEnd mandatory = 本 hook base 必要.
ETA: 5/23-5/28 (= T-12 to T-17). evidence: 本 doc Part C deliverable 1-3.
```

### Prefab 4: v15 spec receipt ping (= 着手判断 ack)

```
@codex T+3 (5/12 火曜) ping — v15 guaranteed compression spec receipt 確認.
docs/cross-instance-prs/20260511_codex_wbs_top5_v15_guaranteed_compression_part201b.md
5 deliverable / 5/30 期限. 着手判断 ack 願う.
evidence: 本 doc Part C.
```

### Prefab 5 (= 5/13 T+4 / 翌日 skip): #1124 GPA Phase 1 PR ping

```
@codex T+4 (5/13 水曜) ping — #1124 GPA Phase 1 PR spec ship status?
ETA: 5/30 (= T-19 残). 5/12 skip → 5/13 fire.
```

---

## Part F — Win Claude follow-up checklist (= part 202 開始時 第 1 task)

1. ✅ v15 spec ship (= 本 doc / part 201-b commit)
2. ✅ memory ship part 201-b dogfood (= feedback_success_20260511_part201b_v15_guaranteed_compression.md)
3. 5/12 T+3 Codex batch ping fire (= 当日 / Part E prefab 1-4 / 翌日)
4. PR cascade 6 PR admin merge 確認 (= #2323-#2340 + 本 doc PR)
5. ROADMAP part 196-201-b batch backfill (= cascade post-merge)
6. DISK_HYGIENE §17.18 v15 章追加 PR (= 既存 doc 章追加 第 13 例累積想定)
7. v15 Tier 1 baseline update (= part 201 +2216.2 MB record)
8. UI verify 4 page (= [UI-VERIFY] backlog)

---

**End of hand-off doc** — Win Claude part 201-b → Win Codex / 5/30 deliverable / 14-day buffer 11 day 残 / 0 false fire 保護維持.
