# Codex pickup ping — v22 compression effectiveness measurement + auto-tuning (= part 211-b / 5/22 sprint pickup)

**作成**: Win Claude #132 part 211-b (= 2026-05-13 水 10:14-11:00 JST same-day turn 2 user direct ask 第 3 例累積)
**宛先**: Win Codex #1 (= instance-codex worktree)
**期限**: 5/30 (= 残 ~17 day / 5/22 sprint start から 9 day)
**priority**: medium (= v15-v21 累積 33 layer 上の measurement layer / non-blocking enhancement / 但し fatigue → cascade trigger = 緊急性 medium-high)

## 背景

part 211 (= 2026-05-13 10:14 JST same-day +11 min minimum session 第 4 例 過去最短 update) 同 session turn 2 で user direct ask:

> 「今の開発フローだと、ローカル環境のメモリやハードディスク容量が必ず枯渇します。毎回のセッションで必ずメモリやハードディスク容量を圧縮する施策を検討してください。」

v15-v21 累積 33 layer = **ALL preventive / structural enforcement**. **measurement + auto-tuning は欠如**.

→ **v22 = preventive → adaptive 移行 (= data-driven measurement + auto-reaction)**.

## v22 spec (= 5 layer EE-II / 累積 38 layer)

### Layer EE: PRE/POST paired-row per compression fire
- 対象 file: `scripts/per_fire_kpi_writer.py` (= **NEW** / `session_delta_tracker.py` extend)
- spec:
  - session-delta.csv schema 拡張 (= `fire_id` column 追加)
  - 各 compression fire で `start_row` (= pre-fire state) + `end_row` (= post-fire state) pair write
  - `fire_id` = UUID4 / 単一 fire identifier
  - `reclaim_mb_fire` = end.c_free_gb - start.c_free_gb (= MB conversion)
  - `ram_delta_pt_fire` = end.ram_pct - start.ram_pct
  - CLI: `python scripts/per_fire_kpi_writer.py --fire-id <uuid> --phase {pre|post}`
- migration: 旧 row (= fire_id 列無し) は `fire_id = "_session_legacy"` で backfill (= reader 互換)
- test: `tests/test_per_fire_kpi_writer.py` で start+end pair → reclaim 計算 verify

### Layer FF: 7-day rolling effectiveness dashboard
- 対象 file: `scripts/compression_effectiveness_dashboard.py` (= **NEW**)
- spec:
  - read `~/.claude/logs/session-delta.csv`
  - aggregate last 7 days (= ts column)
  - emit Markdown to `docs/compression-effectiveness.md`:
    - `median_reclaim_mb_fire` (= per-fire reclaim median)
    - `median_ram_delta_pt_fire`
    - `total_fire_count_7d`
    - `quota_pass_rate_pct` (= v19-R quota base / +500 MB OR -5pt OR +0.5 GB)
    - `top_5_high_yield_fires` (= reclaim_mb_fire desc / fire_id + ts)
    - `top_5_low_yield_fires` (= reclaim_mb_fire asc / fatigue candidate)
  - daily GHA cron: `.github/workflows/compression-effectiveness-dashboard.yml` (= 09:00 JST / 00:00 UTC)
- test: `tests/test_compression_effectiveness_dashboard.py` で fixture CSV → md output verify

### Layer GG: auto-tune compression freq based on effectiveness
- 対象 file: `~/.claude/hooks/adaptive-compression-tuner.ps1` (= **NEW**)
- spec:
  - hook trigger: PostToolUse after every 3 compression fires
  - read last 3 fire `reclaim_mb_fire` from session-delta.csv
  - **5-stage scale**:
    - stage 1 = hourly (= low priority)
    - stage 2 = every 30 min (= **default**)
    - stage 3 = every 15 min
    - stage 4 = every 5 min
    - stage 5 = continuous (= every PostToolUse)
  - decision:
    - last 3 fires median < 200 MB → stage +1 (= freq UP / 圧縮 効果不足 → 頻度増)
    - last 3 fires median > 1 GB → stage -1 (= freq DOWN / 過剰 fire / battery save)
    - else → keep stage
  - write to `~/.claude/state/compression_freq_stage.txt`
  - PostToolUse hook reads stage → conditional fire
- test: PowerShell pester test で 3 fire 平均 → stage transition verify

### Layer HH: compression yield anomaly detection
- 対象 file: `~/.claude/hooks/compression-anomaly-detector.ps1` (= **NEW**)
- spec:
  - hook trigger: PostToolUse after each compression fire
  - read last fire `reclaim_mb_fire` + `ram_delta_pt_fire`
  - **DEGRADED conditions** (= ANY):
    - `reclaim_mb_fire < -500` (= disk が逆に減少)
    - `ram_delta_pt_fire > +3` (= RAM が逆に増加)
  - if DEGRADED:
    - append to `~/.claude/logs/compression_anomaly.log` (= ts + fire_id + metric + cause hint)
    - stdout: `[COMPRESSION ANOMALY] fire_id <uuid> reclaim=<X> MB ram_delta=<Y> pt — DEGRADED — check anomaly.log`
  - daily GHA: `.github/workflows/compression-anomaly-summarize.yml` → `docs/compression-anomaly-report.md`
- test: anomaly fixture (= reclaim=-600) → DEGRADED log write verify

### Layer II: cross-session compression "fatigue" tracking
- 対象 file: `scripts/compression_fatigue_monitor.py` (= **NEW**)
- spec:
  - read session-delta.csv last 3 fire reclaim_mb_fire
  - **FATIGUE state** = ALL 3 consecutive < 100 MB reclaim
  - if FATIGUE:
    - trigger `~/.claude/hooks/disk_hygiene_cascade.ps1` (= v18 Layer K / **mandatory**)
    - write `~/.claude/state/compression_fatigue_state.json` (= ts + last 3 fires + cascade triggered)
    - reset counter on high-yield fire (= > 500 MB)
  - PostToolUse hook integration: after each fire → fatigue check → cascade trigger if needed
- test: 3x low-yield fixture → cascade trigger verify

## 期待効果 (= preventive → adaptive 移行)

| 課題 | v15-v21 status | v22 解決 |
|------|----------------|---------|
| 圧縮が「効いているか」不明 | fire_count しか分からない | Layer EE per-fire reclaim_mb capture |
| 圧縮 freq が固定 | adaptive 不可 | Layer GG 5-stage auto-tune |
| 低 yield fire 反復 | 検知不可 | Layer II fatigue → cascade auto-trigger |
| 異常 fire (= 逆に disk 増 / RAM 増) | 検知不可 | Layer HH DEGRADED warn |
| 7-day trend 不可視 | 個別 session のみ | Layer FF dashboard markdown daily |

## Codex sprint 5/22-5/30 plan (= 残 9 day / 累積 42 deliverable / 平均 4.7 件/day)

| Day | 主要 deliverable |
|-----|------------------|
| 5/22 | v15 5 件 (= always-fire 3 layer + KPI 2) |
| 5/23 | v16 6 件 (= proactive enforcement 5 + dogfood 1) |
| 5/24 | v17 6 件 (= mandatory per-session 5 + audit 1) |
| 5/25 | v18 5 件 (= disk hygiene cascade 5) |
| 5/26 | v19 5 件 (= per-session contract 5) |
| 5/27 | v20 5 件 (= fleet adaptive 5) |
| 5/28 | v21 5 件 (= structural prevention 5) |
| 5/29 | **v22 5 件 (= effectiveness measurement 5)** ← **NEW** |
| 5/30 | integration test + dashboard validation |

## WBS top 5 priority:high (= 期限近順 / 2-instance assignment)

1. **#1495 P0 Mobile iOS/Android day-of**: 期限 5/14 24:00 JST 残 ~37h / Win Claude triage 済 (= part 210 FINAL FINAL ping) / **15:00 JST + 22:00 JST ping** waiting natural trigger (= part 211-b 同 session で fire 不要)
2. **#2204 P1 Calendar EPIC**: design / Win Claude (= calendar UX) / 期限なし / **defer**
3. **#1950 P1 ブログ E2E**: Codex slice MERGED (= part 210 ack) / 残 polish = **Win Codex** / 5/22 sprint pickup with v15-v22
4. **#1962 P1 VSCode dormant**: 2-instance 体制 deprecated label / 期限なし / **skip**
5. **#1787 P1 AI Tool 2026-05**: AI tool watch / Win Claude (= competitive) / 期限なし / **defer**

## Codex 振分 5 質問 evaluation (v22 = 5 deliverable)

| 質問 | 回答 | 結果 |
|------|------|------|
| 1. 新規 file 作成必要? | YES (= 5 new file + 2 GHA workflow) | implementation = Codex |
| 2. SQL / EF / Deno work? | NO | — |
| 3. GHA workflow work? | YES (= 2 new daily cron) | implementation = Codex |
| 4. PR ベース? | YES (= 各 deliverable で別 PR / 5/22-5/30 順次) | implementation = Codex |
| 5. policy / design / review? | NO (= 設計 = Win Claude / impl = Codex) | — |

→ **全 NO は 1 / 4 YES = Codex 担当 confirm**.

## 完了基準

- [ ] `scripts/per_fire_kpi_writer.py` + test + session-delta.csv schema migration
- [ ] `scripts/compression_effectiveness_dashboard.py` + test + GHA cron workflow
- [ ] `~/.claude/hooks/adaptive-compression-tuner.ps1` + 5-stage state file
- [ ] `~/.claude/hooks/compression-anomaly-detector.ps1` + anomaly log + GHA summarize
- [ ] `scripts/compression_fatigue_monitor.py` + fatigue state json + cascade integration
- [ ] session_kpi.py 5 new metric (= 33 → 38)
- [ ] DISK_HYGIENE_RUNBOOK.md §17.25 後追記 commit hash 埋込
- [ ] v22 5/29 sprint end までに 5 deliverable 全 ship + integration test PASS