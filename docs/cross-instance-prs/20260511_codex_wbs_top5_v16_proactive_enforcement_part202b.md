# 2026-05-11 月曜 22:00 JST: Win Codex hand-off batch (= part 202-b / v16 proactive enforcement protocol)

> **From**: Win Claude (architect / docs / spec design)
> **To**: Win Codex (impl / hooks / SQL / EF / GHA)
> **Cascade**: 7th (= 累積 PR #2323/#2328/#2331/#2335/#2340/#2352 + this PR)
> **Priority**: HIGH (= user iterative ask v16 = post-wrap-up escalation 第 4 例累積 + 同日 14 part 連続 violation 重複 trigger)
> **SLA**: 5/30 (= Codex sprint 期限 / 18 day 残 / v15 5 件 + v16 6 件 = total 11 件 deliverable)

---

## Part A — WBS Top 5 期限近順 batch (= 2-instance hand-off / 期限近順)

### Win Codex 5 task (= 実装 / 期限近順)

| # | task | 期限 | size | scope |
|---|------|------|------|-------|
| 1 | #2186 dev_cache 4 cmd Win | 5/22 | M | impl: pre-existing dev_cache cleanup commands Win-native 化 / v11/v12/v14/v15/v16 evidence layer |
| 2 | #2171 WBS dedup Phase 2 | 5/24 | M | impl: codex 451 / user 154 tasks の 9+ 重複完全解消 / migration 20260425203000 cartesian INSERT 後遺症 |
| 3 | v5 hook Tier B-E 配線着手 | 5/26 | L | impl: SessionStart 7 hook の v15/v16 always-fire / threshold-agnostic mandatory wiring |
| 4 | v15 spec impl 5 件 | 5/30 | XL | impl: part 201-b cross-instance-pr 経由 spec 受領 / Layer 1-3 always-fire |
| 5 | **NEW** v16 spec impl 6 件 | 5/30 | XL | impl: 本 doc Part B 経由 / Layer A-E proactive enforcement (= fail-closed 化) |

合計 18 件 impl deliverable / 5/30 期限 SLA buffer 18 day 残.

### Win Claude 5 task (= architect/docs/triage / 期限近順)

| # | task | 期限 | scope |
|---|------|------|-------|
| 1 | v15 + v16 spec ship | 完了 (= 5/11 part 201-b + 202-b) | architect: cross-instance-pr 2 doc 連続 ship (= 同日 4 doc / pattern 第 4 例累積) |
| 2 | cascade 7 PR admin merge follow-up | 5/12-5/14 | triage: #2323/#2328/#2331/#2335/#2340/#2352/#2357 全 BEHIND→update fire 後 merge 確認 |
| 3 | ROADMAP part 196-202-b batch backfill 8 entry | cascade post-merge 後 | docs: cascade-gated discipline 第 3 例累積 / 8 entry 一括 append |
| 4 | DISK_HYGIENE §17.17-§17.19 章追加 PR (= v14 + v15 + v16) | 5/15-5/20 | docs: 既存 doc 章追加 pattern 第 12-14 例累積 / 10 layer KPI table 移植 |
| 5 | UI verify [UI-VERIFY] backlog 回収 (= mobile UAT 含む) | 5/13-5/16 | triage: home/AI 大学/LP/ranking + 久々 fire (= part 196 phase 2 以来) |

---

## Part B — v16 spec: session-wide proactive enforcement protocol (= NEW)

### 背景 (= user 主訴)

> 「今の開発フローだと、ローカル環境のメモリやハードディスク容量が**必ず**枯渇します。
> 毎回のセッションで**必ず**メモリやハードディスク容量を圧縮する施策を検討してください。」

- v15 spec (= part 201-b ship) = threshold-triggered → always-fire mandatory / 3 layer (SessionStart + PostToolUse periodic + SessionEnd)
- **v15 の不足**: spec ship のみ impl 未着手 (= Codex 5/30 deliverable) / user 主訴「**必ず**」= fail-closed enforcement 未配線
- v16 = v15 の **fail-closed enforcement layer 追加** (= 「**必ず**」遵守保証)

### v16 = 5 layer proactive enforcement (= Layer A-E / 全 fail-closed)

```
Layer A (pre-session)  : Windows Task Scheduler nightly cron compression
Layer B (session-wide) : wall-clock 15min interval timer (= PostToolUse 30 tool call の上位 fallback)
Layer C (session-end)  : /wrap-up 直前 hard gate (= fire 失敗 = wrap-up block / fail-closed)
Layer D (alert)        : RAM 95%+ / C: 30 GB- → user 即時 notification + auto-pause
Layer E (cross-session): 過去 N session 累積 ML-driven predicted fire trigger
```

### Layer 詳細

#### Layer A — pre-session nightly compression (= Win Task Scheduler 連携)

- **目的**: 開発作業開始**前**に compression 完了済保証 (= session 起動時 baseline 最適化)
- **実装**: `pre-session-cron.ps1` (M / 5/30 期限)
- **trigger**: Windows Task Scheduler / 毎日 JST 04:00 起動 (= [SCHEDULE-WAKEUP] 02:00-06:00 禁止帯 内だが non-interactive cron は許可)
- **action**: memory-cleanup.ps1 + worktree_cleanup.py --tier2 + dev_cache_cleanup --tier18
- **fail-closed gate**: 失敗時 user notification + Win Task Scheduler retry (= 次回 04:00)

#### Layer B — session-wide wall-clock fire (= 15min interval / fallback)

- **目的**: PostToolUse 30 tool call (= v15 Layer 2) が trigger しない idle session でも fire 保証
- **実装**: `wall-clock-timer.ps1` (M / 5/30 期限)
- **trigger**: SessionStart 配線 + Start-Job background timer / 15min interval
- **action**: memory-cleanup.ps1 fire + session_kpi.append (= wall_clock_periodic_fire_count++)
- **fail-closed gate**: 連続 3 回 fire 失敗 → SessionEnd Layer C escalation

#### Layer C — session-end hard gate (= /wrap-up 直前 fail-closed)

- **目的**: SessionEnd Layer 3 (= v15) を **enforcement** 化 (= fire 失敗 = wrap-up block)
- **実装**: `wrap-up-gate.ps1` (S / 5/30 期限)
- **trigger**: /wrap-up skill 起動時 pre-hook
- **action**: memory-cleanup.ps1 fire 実行 → DELTA >= 100 MB OR RAM% <= 80% → gate PASS / else gate FAIL → /wrap-up block + user prompt
- **fail-closed gate**: gate FAIL = /wrap-up 強制 abort + user 手動 intervention (= app close / restart 推奨)

#### Layer D — hard threshold breach alert (= 即時 user notification)

- **目的**: critical state (= RAM 95%+ / C: 30 GB-) で 即時 user 通知 + auto-pause
- **実装**: `hard-threshold-alert.ps1` (S / 5/30 期限)
- **trigger**: Layer B wall-clock timer + PostToolUse hook 経由 / threshold 監視
- **action**: Windows toast notification + claude_session_alert.json emit + SessionStart hook 経由 next session warning banner
- **fail-closed gate**: critical state 5min+ 継続 = session_kpi auto-pause flag set (= Layer C wrap-up gate 即時 PASS 化 + 強制 wrap-up)

#### Layer E — cross-session ML-driven predicted fire (= ML / 過去 N session 累積)

- **目的**: 過去 N session の RAM/C: build-up rate 学習 → next session の predicted fire trigger
- **実装**: `cross-session-kpi-ml.py` (XL / 5/30 期限) + `session_alert_dashboard.py` (L / 5/30 期限)
- **trigger**: SessionStart hook 経由 / past 30 session の session_kpi.csv aggregate
- **action**: predicted RAM% > 85% at session_minute=N → Layer B wall-clock fire interval を 15min → 5min 自動短縮
- **fail-closed gate**: ML model 未学習時 = Layer B 15min interval default 維持 (= safe fallback)

### session_kpi metric 拡張 (= v15 5 metric → v16 8 metric)

| metric | v15 | v16 追加 |
|--------|-----|---------|
| ram_fire_count | ✅ | — |
| ram_total_freed_MB | ✅ | — |
| disk_delta_GB | ✅ | — |
| memory_md_size_KB | ✅ | — |
| memory_file_count | ✅ | — |
| **wall_clock_periodic_fire_count** | — | ✅ NEW (= Layer B) |
| **threshold_breach_count** | — | ✅ NEW (= Layer D) |
| **session_duration_min** | — | ✅ NEW (= Layer E ML feature) |

### v15 + v16 累積 6 layer always-fire + enforcement

| layer | v## | always-fire | fail-closed enforcement |
|-------|-----|-------------|------------------------|
| 1. SessionStart | v15 | ✅ | — |
| 2. PostToolUse periodic | v15 | ✅ (30 tool call) | — |
| 3. SessionEnd | v15 | ✅ | — |
| A. Pre-session cron | v16 | ✅ | ✅ (Win Task Scheduler retry) |
| B. Wall-clock 15min | v16 | ✅ | ✅ (Layer C escalation) |
| C. Wrap-up hard gate | v16 | ✅ | ✅ (block /wrap-up) |
| D. Threshold alert | v16 | ✅ | ✅ (auto-pause) |
| E. ML predicted fire | v16 | ✅ | ✅ (safe fallback) |

合計 8 layer (= 3 v15 + 5 v16) / 全 always-fire / 5 fail-closed enforcement.

---

## Part C — Codex impl 11 件 enumerated (= v15 5 件 + v16 6 件 / 5/30 期限)

| # | file | layer | size | spec |
|---|------|-------|------|------|
| 1 | `memory-cleanup.ps1` (modify) | v15 L1 | S | SessionStart always-fire 化 / 既存 hook の threshold-agnostic 化 |
| 2 | `posttooluse-periodic-trim.ps1` (new) | v15 L2 | M | 30 tool call / 30min wall-clock 毎 fire |
| 3 | `sessionend-mandatory-fire.ps1` (new) | v15 L3 | M | /wrap-up 直前 fire |
| 4 | `session_kpi.py` (new) | v15 5 metric | M | session_kpi.csv emit / 5 metric (ram_fire_count etc.) |
| 5 | `session_kpi_dashboard.py` (new) | v15 viz | L | 過去 N session の 5 metric viz |
| 6 | `wall-clock-timer.ps1` (new) | v16 LB | M | SessionStart 配線 / Start-Job background timer / 15min interval |
| 7 | `pre-session-cron.ps1` (new) | v16 LA | M | Win Task Scheduler 連携 / 毎日 04:00 起動 |
| 8 | `wrap-up-gate.ps1` (new) | v16 LC | S | /wrap-up pre-hook / fire 失敗 = block |
| 9 | `hard-threshold-alert.ps1` (new) | v16 LD | S | toast notification / claude_session_alert.json emit |
| 10 | `cross-session-kpi-ml.py` (new) | v16 LE | XL | past 30 session aggregate + ML predicted trigger |
| 11 | `session_alert_dashboard.py` (new) | v16 LE viz | L | predicted fire visualization |

合計 11 件 / size weight = S×3 + M×5 + L×2 + XL×1 / 5/30 期限.

---

## Part D — v3-v16 累積 15 layer iterative ask trace (= 月内 14 day window / 過去最高 layer 数)

| version | part | date | layer |
|---------|------|------|-------|
| v3 | 192-b | 5/8 | shadow append baseline |
| v4 | 193 | 5/8 | session_kpi.csv add |
| v5 | 194 | 5/9 | SessionStart hook 7 |
| v6-v9 | 194-196 | 5/9-5/10 | gap audit + 80% completion |
| v10 | 196 ph2 | 5/10 | mid-session build-up rate KPI |
| v11 | 197 | 5/10 | 85% threshold lower + post-resume mandatory fire |
| v12 | 198 | 5/10 | docs-only label-based gate bypass |
| v13 | 199-b | 5/11 | SessionEnd mandatory fire 配線 |
| v14 | 200-b | 5/11 | 4-tier compression escalation |
| v15 | 201-b | 5/11 | guaranteed compression (threshold → always-fire) |
| **v16** | **202-b** | **5/11** | **proactive enforcement (always-fire → fail-closed enforcement)** ← **NEW** |

trace: 14-day window / 平均 0.93 day interval / **15 layer 累積** / 100% ship rate / 過去最高 layer 数 update.

---

## Part E — 5/12 火曜 T+3 Codex sprint ping batch prefab (= 6 件 prefab / 1 件 翌日)

### Ping #1: #2186 dev_cache 4 cmd Win (= v11-v16 evidence)

> @codex 5/12 T+3 follow-up #2186 (= dev_cache 4 cmd Win-native).
> v11-v16 evidence available (= cross-instance-pr docs 202-b/201-b/200-b/199-b/198/197/196 ph2).
> SLA 5/22 (= 10 day 残 / sprint priority bump 推奨).

### Ping #2: #2171 WBS dedup Phase 2 (= progress 確認)

> @codex 5/12 T+3 follow-up #2171 (= WBS dedup Phase 2 / codex 451 / user 154 tasks).
> migration 20260425203000 cartesian INSERT 後遺症完全解消依頼.
> SLA 5/24 (= 12 day 残 / Phase 1 完了状況確認).

### Ping #3: v5 hook Tier B-E 配線着手 (= v15/v16 base)

> @codex 5/12 T+3 follow-up SessionStart 7 hook Tier B-E 配線.
> v15 spec (= part 201-b PR #2352) + v16 spec (= part 202-b PR #2357 想定) base 配線.
> SLA 5/26 (= 14 day 残).

### Ping #4: v15 spec receipt + 着手判断 ack

> @codex 5/12 T+3 follow-up v15 5 deliverable.
> cross-instance-pr doc 202-b に統合 (= v16 と batch).
> SLA 5/30 (= 18 day 残).

### Ping #5: **v16 spec receipt + 着手判断 ack** (= NEW)

> @codex 5/12 T+3 follow-up v16 6 deliverable (= proactive enforcement Layer A-E).
> 本 cross-instance-pr doc Part B-C 経由.
> 着手判断 ack 依頼.
> SLA 5/30 (= 18 day 残 / v15 5 件と batch / total 11 件).

### Ping #6: #1124 GPA Phase 1 PR T+4 = 5/13 (= 翌日 skip)

> 5/13 fire (= 1 day delay).

---

## Part F — dogfood pattern reference (= part 202-b 累積)

### 本 session dogfood pattern (= 5 件 想定)

1. **iterative ask 累積 15 layer 第 1 例 update** (= v3-v16 / 月内 14 day / 平均 0.93 day interval / 100% ship rate / 過去最高 layer 数)
2. **2-instance hand-off batch 第 4 例累積** (= 同日 4 doc / part 199-b / 200-b / 201-b / 202-b)
3. **v16 proactive enforcement spec ship 第 1 例** (= fail-closed enforcement layer / 5 layer × always-fire + enforcement)
4. **post-wrap-up escalation 第 4 例累積** (= part 192-b / 199-b / 200-b / 201-b / 202-b)
5. **manual fire 過去最大 record update 第 2 例累積** (= 旧 part 201 +2216.2 MB / 新 part 202-b +2785.65 MB / +26% 上回る)

### violation pattern (= part 202 起動時検出)

- 同日 14 part 連続 [COMPACTION-RESUME] discipline 違反 第 1 例 (= part 201-b 末尾 fresh start 指示無視 / mitigation = minimal session 化 should be / 実際 = v16 escalation 受信 = 過去最重 risk 再 update)

---

## 完了基準 (= Win Codex 5/30 期限)

- [ ] v15 5 file impl + commit (= Codex sprint #2186/#2171 と並列)
- [ ] v16 6 file impl + commit (= Layer A-E enforcement / fail-closed)
- [ ] session_kpi.csv emit verified (= 8 metric)
- [ ] cross-session-kpi-ml.py 学習 30 session 完了
- [ ] DISK_HYGIENE §17.19 v16 章追加 PR (= Win Claude / 既存 doc 章追加 第 14 例)
- [ ] 11 件 functional verify dogfood (= Win Claude part 203+ 起動時)

---

## 関連 doc

- `docs/cross-instance-prs/20260511_codex_wbs_top5_v15_guaranteed_compression_part201b.md` (= 前 doc / v15 spec)
- `docs/cross-instance-prs/20260511_codex_wbs_top5_v14_compression_protocol_part200.md` (= v14 spec)
- `docs/cross-instance-prs/20260511_codex_wbs_top5_v13_session_end_part199.md` (= v13 spec)
- `docs/DISK_HYGIENE_RUNBOOK.md` §17.16 v11 (= shipped 5/10 part 197)
- `memory/feedback_correction_20260511_same_day_14part_violation.md` (= part 202 起動時 violation 検出 / 第 1 例)
- `memory/project_20260511_win132_part202.md` (= part 202 minimal session record)
