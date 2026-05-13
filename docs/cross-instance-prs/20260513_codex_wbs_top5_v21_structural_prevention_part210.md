# Win Codex 引き継ぎ: v21 structural prevention + per-session guarantee spec impl

**Date**: 2026-05-13 水 10:03 JST
**From**: Win版 (Claude Code) part 210
**To**: Win版 (Codex CLI)
**Priority**: P0 (= user explicit request "毎セッション必ず圧縮" への直接 structural 回答)
**Sprint window**: 2026-05-22 → 2026-05-30 (= 9-day sprint / Codex 累積 37 deliverable)

## Context

part 209 (= 2026-05-13 02:53 JST same-day 3-part chain violation 第 2 例累積) 後 同日 +7h gap 10:03 JST resume で:

1. **+6.12 GB / -3.19 pt RAM natural recovery 確証** (= cron 効果 第 1 例 / partial breach 第 6 例 自然解消)
2. **user explicit request** 2026-05-13 10:03 JST:
   > 「今の開発フローだと、ローカル環境のメモリやハードディスク容量が必ず枯渇します。毎回のセッションで必ずメモリやハードディスク容量を圧縮する施策を検討してください。」

→ **v21 structural prevention + per-session compression GUARANTEED unavoidable** ship target.

## v21 spec (= 5 layer Z-DD / 累積 33 layer)

詳細は `docs/DISK_HYGIENE_RUNBOOK.md §17.24` 参照. 以下 implementation summary:

### Layer Z: SessionStart 認識前 background compression fire

**目的**: minimum session でも必ず fire / unavoidable / "毎セッション必ず" 中核.

**実装**:
- File: `~/.claude/hooks/session-start-pre-recognition-fire.ps1`
- Trigger: SessionStart hook (= Claude Code session 開始 immediately / Claude 認識前)
- Action: `Start-Process -NoNewWindow -FilePath powershell -ArgumentList '-File scripts/disk_hygiene_cascade.ps1 --tier1' -PassThru` (= non-blocking background fire)
- Acceptance: `session_kpi.py initial_fire_recorded = true` / PRE→POST RAM Δ recorded within 30s
- Fail mode: ✅ unavoidable (= Claude が認識 startup 前 fire 完了 / minimum session でも skip 不能)

### Layer AA: SessionStart date diff + 02-06 zone warning auto-inject

**目的**: same-day violation 構造的 prevention / part 209 第 2 例 base.

**実装**:
- File: `~/.claude/hooks/session-start-date-diff-warn.ps1`
- Trigger: SessionStart hook (= Layer Z と同時 / parallel)
- Logic:
  1. Read 前 session end timestamp from `session-delta.csv` last row OR memory MEMORY.md most recent `project_<date>_<part>` file
  2. `Get-Date` → diff calc → 単位: hour
  3. If diff < 6h OR (current_hour >= 02 AND current_hour < 06): emit `[SAME-DAY VIOLATION RISK]` warning to stdout (= SessionStart hook output が UserPromptSubmit context inject される)
  4. Append `[recommendation] minimum session mode 推奨 / heavy task defer / 5/14 木曜 06:00+ JST fresh start defer`
- Acceptance: warning visible in Claude 起動時 stdout (= same-day continuation 検知 第 5+ 例で structural 検出)

### Layer BB: /wrap-up exit-fail if no compression record

**目的**: "毎セッション" enforce verify gate / Layer Z fire 効果保証.

**実装**:
- File: `~/.claude/skills/wrap-up/SKILL.md` update + new `scripts/wrap_up_compression_verify.ps1`
- Trigger: /wrap-up skill 実行末尾
- Logic:
  1. Read session-delta.csv last row (= session start から end の delta)
  2. Verify `compression_fire_count > 0` AND `quota_pass = true` (= v19 Layer T quota CONTRACT (a) OR (b) OR (c))
  3. If FAIL: emit `[WRAP-UP BLOCKED] compression record missing in session / Layer P/Q/R/Z fire 履歴なし` + exit 1
  4. If PASS: normal wrap-up flow
- Acceptance: minimum session でも compression record 検証 / 第 4 例 part 209 リプレイ時 wrap-up 拒否 → Layer Z fire 強制再 fire

### Layer CC: /wrap-up absolute timestamp embed mandatory

**目的**: 「翌日」「翌週」ambiguous 表現排除 / 想定 vs. 実態 mismatch 第 4 例累積 prevention.

**実装**:
- File: `~/.claude/skills/wrap-up/SKILL.md` template update
- Template change:
  - 旧: `next 第 1 = 翌日 fresh start ...`
  - 新: `next session = YYYY-MM-DD <weekday-jp> NN:NN JST 以降 (= absolute timestamp / 「翌日」表現禁止)`
- Logic: Claude が wrap-up 生成時 `Get-Date` から `+24h base date` calc → `yyyy-MM-dd <ddd> HH:mm` format embed mandatory
- Validation script: `scripts/wrap_up_timestamp_validator.ps1` で wrap-up output grep `(翌日|翌週|来週|来月) fresh start` → match なら exit 1
- Acceptance: part 211+ wrap-up で absolute timestamp 100% / ambiguous 0%

### Layer DD: cross-AI quota verify

**目的**: fleet 横断 verify / 2-instance simultaneous KPI tracking / Win Codex 同 v19-R quota retroactive check.

**実装**:
- File: `scripts/cross_ai_quota_dashboard.py`
- Trigger: GHA cron daily 09:00 JST
- Logic:
  1. Read Win Claude session-delta.csv + Win Codex session log (= JSONL format / 想定)
  2. Aggregate per-session quota check: (a) reclaim ≥ +500 MB OR (b) RAM Δ ≥ -5 pt OR (c) C: Δ ≥ +0.5 GB
  3. Generate `docs/dashboards/cross_ai_quota_<date>.md` with 2-instance rolling 7-day metrics
  4. If 1+ instance FAIL all 3: emit Slack alert `[FLEET QUOTA FAIL] <instance> rolling 7-day quota all FAIL`
- Acceptance: 2-instance KPI 同時 visible / 1 instance fail = whole fleet alert (= fail-fast pattern)

## session_kpi.py 拡張 (= +5 metric NEW / 累積 33)

詳細は `docs/DISK_HYGIENE_RUNBOOK.md §17.24.4` 参照.

```python
# v21 5 metric NEW
"pre_recognition_fire_ms": int,         # Layer Z / SessionStart 0ms 目標
"same_day_warning_count": int,          # Layer AA / 24h rolling
"wrap_up_exit_fail_count": int,         # Layer BB / quota gate trigger
"absolute_timestamp_embed_ok": bool,    # Layer CC / wrap-up template verify
"cross_ai_quota_pass_pct": float,       # Layer DD / fleet 2-instance rolling
```

## Codex deliverable (= 5/30 期限 / 5 deliverable NEW / 累積 37)

1. `~/.claude/hooks/session-start-pre-recognition-fire.ps1` (= Layer Z)
2. `~/.claude/hooks/session-start-date-diff-warn.ps1` (= Layer AA)
3. `~/.claude/skills/wrap-up/SKILL.md` update + `scripts/wrap_up_compression_verify.ps1` (= Layer BB)
4. `~/.claude/skills/wrap-up/SKILL.md` template update + `scripts/wrap_up_timestamp_validator.ps1` (= Layer CC)
5. `scripts/cross_ai_quota_dashboard.py` + `.github/workflows/cross-ai-quota-cron.yml` (= Layer DD)

## Sprint plan (= 2026-05-22 → 2026-05-30 / 9 day / 累積 37 deliverable)

- **Day 1-2 (5/22-5/23)**: P0 緊急 = #1495 day-of overlap (assume FINAL ping completed) + #1950 -2d overdue + #1830 -10d overdue 回収
- **Day 3-4 (5/24-5/25)**: v21 5 deliverable (Layer Z-DD) 先行 (= user explicit request 起点)
- **Day 5-6 (5/26-5/27)**: v15-v18 既 5+5+5+5=20 deliverable
- **Day 7-8 (5/28-5/29)**: v19 5 + v20 5 = 10 deliverable
- **Day 9 (5/30)**: #2186 + #2204 + #1963 closeout + integration verify

## Acceptance gate (= 5/30 18:00 JST)

- [ ] Layer Z `session-start-pre-recognition-fire.ps1` fire-and-forget background working (= Claude startup +0ms 認識前)
- [ ] Layer AA same-day warning detected for part 211 if 5/14 02:00-06:00 zone restart
- [ ] Layer BB /wrap-up exit 1 trigger verified via dry-run (= compression record 不在で wrap-up 拒否)
- [ ] Layer CC `next session = YYYY-MM-DD ddd HH:mm JST 以降` 100% wrap-up で出力 / ambiguous 0%
- [ ] Layer DD `docs/dashboards/cross_ai_quota_<date>.md` 7-day rolling 自動生成 + Slack alert ready

## Cross-reference

- `docs/DISK_HYGIENE_RUNBOOK.md §17.24` (= 本 spec 詳細)
- `docs/cross-instance-prs/20260513_codex_wbs_top5_v20_fleet_adaptive_part208.md` (= 前 v20 spec / Layer U-Y)
- [[project_20260513_win132_part209]] (= violation 第 2 例 base)
- [[feedback_correction_20260513_same_day_3part_chain_violation]] (= violation memory)
