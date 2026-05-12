# Codex Hand-off — Win版 part 200 / WBS Top 5 + v14 Compression Protocol

**Date**: 2026-05-11 月曜 (= part 200 mid-session escalation / part 199-b v13 hand-off batch pattern 第 2 例累積)
**From**: Win Claude (= architect / docs / memory / UI design / triage)
**To**: Win Codex (= 実装 / 修正 PR / SQL / EF Deno / GHA / T-1 dispatch / 競馬 / Karpathy Compile-Lint)
**Pattern**: 2-instance hand-off batch 第 2 例累積 / single doc 統合 / Codex 認知 cost 削減

---

## Part A — WBS Top 5 期限近順 batch (= 2-instance 制反映)

| # | issue | 期限 | T-N | instance | 状態 | 5/12 ping 状態 |
|---|-------|------|-----|----------|------|----------------|
| 1 | #2171 WBS dedup Phase 2 | 5/22 | T-11 | Win Codex | OPEN / dedup v2 + UNIQUE INDEX 強制再作成 | T+3 = 5/12 ping (= 明日) |
| 2 | #2186 dev_cache 4 cmd Win | 5/23 | T-12 | Win Codex | OPEN / hygiene / infra label | T+3 = 5/12 ping with v11/v12/v14 evidence |
| 3 | v5 hook wiring 5 task (Tier B-E) | 5/23-5/28 | T-12 to T-17 | Win Codex | sequential 推進 | T+3 = 5/12 ping |
| 4 | #1124 GPA Phase 1 PR | 5/30 | T-19 | Win Codex | spec ship | T+4 = 5/13 ping (= 明後日 / 5/12 skip) |
| 5 | **v14 memory/disk compression protocol** (= 本 doc Part B) | 5/30 | T-19 | Win Codex (impl) + Win Claude (spec) | spec ship 本 doc | T+3 = 5/12 ping batch 同梱 |

### 2-instance 制反映 detail

- **全 5 task = Win Codex 担当** (= 実装 / SQL / EF Deno / GHA / 修正 PR 範疇)
- **Win Claude follow-up = spec ship + cross-instance-pr doc + memory record + triage** (= Part D)
- 旧 12 instance dormant (= PS#1-6 / VSCode版 / WEB版 / スマホ版 / Codex#1 / Codex#2)

---

## Part B — v14 Compression Protocol Spec (= 毎セッション 必須 圧縮 4-tier)

### Why ship now (= part 200 evidence)

part 200 起動時 + manual fire 後 RAM% threshold 継続 breach 検出:

| metric | value | rule |
|--------|-------|------|
| 起動時 RAM | 94.34% | > 85% v11 threshold breach |
| SessionStart 7 hook fire 後 | 93.23% | -1.11pt / fire 効果 limited |
| manual memory_trim_phase2 fire 後 | 93.36% | DELTA **-20.7 MB NEGATIVE** / OS realloc 即時消費 |
| ram_trim_count (internal) | 4 / 1039.6 MB freed | counter only / 実 OS 解放 effect なし |

→ 「manual fire 後 RAM% threshold breach 継続」第 1 例 = v11 threshold lower (= part 197 §17.16) で対応不十分 / **4-tier escalation 必要**.

### v14 4-tier escalation Spec

```yaml
title: v14 — 毎セッション memory/disk compression mandatory protocol
trigger: SessionStart hook + mid-session threshold + SessionEnd hook 3 layer
escalation:
  Tier 1 — 1x trim (= 既存 v9 SessionStart auto-fire):
    fire: memory_trim_phase2.ps1 (single run)
    success: post-fire RAM% < 85%
    fail → Tier 2

  Tier 2 — 2x trim fallback (= NEW / part 200 第 1 例 evidence):
    pre-condition: Tier 1 DELTA < 100 MB (= include NEGATIVE)
    fire: 30 sec sleep → 2nd memory_trim_phase2.ps1 (worker process re-spawn cleanup)
    success: post-2x RAM% < 85%
    fail → Tier 3

  Tier 3 — user app close escalation:
    pre-condition: Tier 2 post-fire RAM% > 85%
    action: user prompt "Chrome / VSCode / Claude Code いずれか 1 個 close 推奨"
    UI: SessionStart hook output warning banner
    user accept → wait 30 sec → re-measure
    user reject → Tier 4

  Tier 4 — /wrap-up immediate:
    pre-condition: RAM% > 95% AND Tier 3 reject
    action: /wrap-up skill immediate fire + 翌セッション fresh start 強推奨
    log: feedback_success_<date>_tier4_emergency.md auto-create

disk_compression_track (= parallel layer):
  SessionStart hook: worktree_cleanup.py --tier1 dry-run (= 既存)
  mid-session check (= 30min interval): C: free < 50 GB → --tier2 apply
  SessionEnd hook: scripts/dev_cache_cleanup.py --tier18 (= dart/pip/npm/pnpm / #2186 dependency)

KPI:
  Tier 1 success rate: TBD (= v9 baseline measured / part 195 -5.2pt 自走)
  Tier 2 conversion rate: TBD (= v14 新 spec)
  Tier 3 escalation rate: TBD
  Tier 4 emergency rate: TBD (target = 0%)
  C: free < 50 GB trigger rate: TBD

cross-deps:
  #2186 dev_cache 4 cmd Win 互換 fix: SessionEnd hook の `dev_cache_cleanup --tier18` が成立条件
  v5 hook Tier B-E wiring: Tier 2 fallback の hook 配線が前提
```

### Codex 実装 deliverable (5/12-5/30)

1. **scripts/memory_compression_v14.ps1** (新規 / Tier 1-4 統合 entry point)
2. **~/.claude/hooks/SessionStart.json** 配線 (= v14 entry point fire / 既存 7 hook と並列)
3. **~/.claude/hooks/SessionEnd.json** 新規 (= v13 SessionEnd mandatory fire spec / part 199-b 由来 / v14 統合)
4. **docs/DISK_HYGIENE_RUNBOOK.md §17.17 v14** 章追加 (= 既存 doc 章追加 pattern 第 12 例 / Win Claude side 又は Codex 担当も可)
5. **GHA workflow `disk-hygiene-audit.yml`** に Tier 2/3/4 escalation rate KPI 計測追加

### v6-v14 累積 9 layer KPI table (= 既存 v6-v13 + v14 NEW)

| v | 内容 | trigger | status |
|---|------|---------|--------|
| v6 | RAM immediate fire band 確立 | RAM > 95% | shipped part 191 |
| v7 | 700-1700 MB band | post-fire freed MB | shipped part 192 |
| v8 | SessionStart 7 hook 配線 | session start | shipped part 194 |
| v9 | functional verify pattern | session start RAM% measure | shipped part 195 |
| v10 | mid-session build-up rate | 60min interval | shipped part 196 |
| v11 | 85% threshold lower + post-resume mandatory | RAM > 85% | shipped part 197 |
| v12 | memory_size_check.ps1 SessionStart hook spec | MEMORY.md > 24.4 KB | shipped part 198 (spec only) |
| v13 | SessionEnd mandatory fire spec | session end | shipped part 199-b (spec only) |
| **v14** | **4-tier escalation + dev_cache integration** | **Tier 1 fail / mid-session > 50 GB threshold / SessionEnd** | **NEW / 本 doc Part B** |

---

## Part C — Codex 5/12-5/30 sprint plan (= 13 task in-flight + v14 追加)

```
5/12 火 — T+3 batch ping receipt day (= 4 issue payload):
  - #2171 WBS dedup Phase 2: Step 1 progress confirm + PR 投稿予定
  - #2186 dev_cache 4 cmd Win: Tier 1 fix dispatch (= dart/pip/npm/pnpm 4 cmd)
  - v5 hook Tier B-E: Tier B 着手 dispatch
  - v14 spec receipt + 着手判断 (= 5/13-5/30 sprint allocation)

5/13 火 — T+4 #1124 ping receipt
5/15 木 — #2171 Step 2 mid-checkpoint
5/18 日 — #2186 Tier 2 (dependent on dev_cache 4 cmd success)
5/22 月 — #2171 deadline
5/23 火 — #2186 deadline + v5 hook Tier C-D
5/28 土 — v5 hook Tier E complete
5/30 木 — #1124 GPA Phase 1 PR open + v14 deliverable 1-5 全完了
```

### v14 期限明示

- v14 spec receipt: 5/12 (T+3 batch 同梱)
- v14 implementation: 5/30 (= #1124 と同期)
- v14 KPI 測定開始: 6/1 (= 翌月 baseline)

---

## Part D — Win Claude follow-up (= part 200-b → 201)

1. **本 doc commit + push + PR open** (= cascade 5th / docs-only label) — part 200-b 内 完了予定
2. **memory ship 1 件** (= part 200-b 4 dogfood pattern simultaneous ship) — part 200-b 内
3. **next session = part 201** で:
   - 5/12 T+3 batch ping fire (= 本 doc Part A 経由 / 4 issue payload prefab 化済 = next session prompt 内)
   - cascade 5 PR admin merge 確認 (= 本 doc 含む)
   - ROADMAP part 196-200 batch backfill (= cascade post-merge)
   - v14 Codex impl progress monitor

---

## Part E — Codex action prefab (= 5/12 ping body / 4 issue 並列 fire)

### Issue #2171 ping body

```
@codex 5/12 T+3 batch ping (= Win Claude part 200-b hand-off).

WBS dedup Phase 2 (= #2171) 5/22 期限 T-11. Step 1 dedup v2 SQL migration の状態を確認させてください.

context refs:
- docs/cross-instance-prs/20260511_codex_wbs_top5_v14_compression_protocol_part200.md (= 本 hand-off doc)
- 過去 hand-off: docs/cross-instance-prs/20260508_wbs_dedup_v2_phase2_codex.md

ack 期待 = next 48h.
```

### Issue #2186 ping body

```
@codex 5/12 T+3 batch ping (= Win Claude part 200-b hand-off).

dev_cache 4 cmd Win 互換 fix (= #2186) 5/23 期限 T-12. dart/pip/npm/pnpm 4 cmd の Win 互換 patch progress を確認させてください.

evidence: part 200 起動時 RAM 94.34% / SessionStart 7 hook + manual fire 後も 93.36% breach 継続. v14 spec (= 本 hand-off doc Part B) の SessionEnd hook が #2186 完了に dependency あり.

priority bump justification:
- part 197 v11 (85% threshold lower) 後も breach 検出
- v14 4-tier escalation Tier 2/3/4 が dev_cache cleanup に dependency
- 5/12 batch fire 含めると 5/22-5/30 sprint 11 day で v14 + #1124 + v5 hook 並列 → buffer 5 day

ack 期待 = next 48h.
```

### v5 hook ping body

```
@codex 5/12 T+3 batch ping (= Win Claude part 200-b hand-off).

v5 hook wiring Tier B-E (= 5/23-5/28 期限) sequential 着手予定確認. Tier B から fire してください.

dependency:
- v14 spec (= 本 hand-off doc Part B) の Tier 2 fallback が v5 hook Tier B-E 配線 後完成
- SessionEnd hook (v13 spec part 199-b + v14 統合) も v5 hook 配線 後完成

ack 期待 = next 48h.
```

### v14 spec receipt ping body

```
@codex 5/12 T+3 batch ping (= Win Claude part 200-b hand-off).

v14 spec ship (= 毎セッション memory/disk 4-tier compression protocol) を本 doc Part B として ship しました.

reference: docs/cross-instance-prs/20260511_codex_wbs_top5_v14_compression_protocol_part200.md

要件:
- Tier 1-4 escalation 統合 entry point (= scripts/memory_compression_v14.ps1)
- SessionStart + SessionEnd hook 配線
- disk_compression_track parallel layer (= worktree + dev_cache 統合)
- KPI 5 metric (= Tier 1-4 success/escalation rate + C: free trigger rate)
- DISK_HYGIENE §17.17 v14 章追加

期限 5/30 (= #1124 と同期). 着手判断 ack 期待 = next 48h.

evidence:
- part 200 起動時 RAM 94.34% (= v11 85% threshold breach / 第 1 例)
- manual fire DELTA -20.7 MB NEGATIVE (= OS realloc 即時消費 / 新 pattern 第 1 例)
- 「manual fire 後 RAM% threshold breach 継続」第 1 例 = v14 4-tier escalation 必要性 evidence
```

---

## End-of-doc checklist (= Win Claude side / part 200-b 内 完了)

- [x] WBS Top 5 期限近順 verify (= 2-instance 反映)
- [x] v14 spec inline ship (= 4-tier escalation + dev_cache integration)
- [x] Codex ping prefab 4 件 (= #2171 / #2186 / v5 hook / v14)
- [ ] commit + push + PR open (= cascade 5th)
- [ ] memory ship part 200-b
- [ ] /wrap-up Phase 2 + next session prompt 生成
