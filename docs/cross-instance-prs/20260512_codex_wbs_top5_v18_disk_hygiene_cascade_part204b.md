# cross-instance-pr: Codex sprint 5/22-5/30 — WBS Top 5 + v18 disk hygiene cascade (part 204-b)

**From**: Win Claude (architect / triage / spec)
**To**: Win Codex (impl / sprint 5/22-5/30 / 5/30 期限)
**Date**: 2026-05-12 火曜 12:45 JST (part 204-b mid-session escalation)
**Priority**: 🔴 high (= 期限近順 + partial recovery 問題直接回答)
**Iterative ask**: 累積 17 layer 過去最高 update (= v3 part 178b → v18 part 204-b)
**Post-wrap-up escalation**: 第 6 例累積 (= part 199-b, 200-b, 201-b, 202-b, 203-b, 204-b)

---

## Part A: 期限近順 WBS Top 5 triage (= 2 instance 配分)

| # | Issue | priority | 期限 | 残 day | 担当案 |
|---|-------|----------|------|--------|--------|
| 1 | [#1495](https://github.com/kanta13jp1/my_web_app/issues/1495) iOS/Android 同時リリース準備 | P0 | 2026-05-14 | 2 day ⚠️ | **Win Codex 再 assign 緊急** (= 既 part 203-b 推奨 / 未 pickup) |
| 2 | [#1950](https://github.com/kanta13jp1/my_web_app/issues/1950) ブログ/ニュース E2E 完全自動化 | P1 | 2026-05-11 過 | -1 day | **Win Codex 再 assign 緊急** (= 既 part 203-b 推奨 / 未 pickup) |
| 3 | [#2186](https://github.com/kanta13jp1/my_web_app/issues/2186) dev_cache hygiene 4 cmd Win 互換 fix | P2 | 2026-05-22 | 10 day | Win Codex sprint 5/22-5/30 |
| 4 | [#2204](https://github.com/kanta13jp1/my_web_app/issues/2204) Google Calendar EPIC | P1 | TBD | TBD | Win Codex sprint pickup |
| 5 | [#1963](https://github.com/kanta13jp1/my_web_app/issues/1963) NotebookLM list 差分 Issue 化 | P-med | TBD | TBD | Win Codex sprint pickup |

### Win Claude (= architect / no-impl) responsibility

- triage + spec ship + escalate (= 本 doc)
- #1495 + #1950 緊急 escalate (= 残 2 day + 過ぎ / Codex 即 pickup 必要)
- 5/13 T+4 Codex ping 予定 (= 本 doc + #1495/#1950 status check)

### Win Codex (= impl) sprint plan

```
sprint window: 2026-05-22 to 2026-05-30 (= 9 day / 22 deliverable)

day 1-2 (5/22-5/23):
- #1495 iOS/Android 配布自動化 (= 期限超過後緊急回収)
- #1950 ブログ/ニュース E2E 完全自動化 (= 期限超過後緊急回収)

day 3-5 (5/24-5/26):
- v18 5 layer impl (= disk_hygiene_cascade + pre_commit_hard_gate + hourly_forced_compression + post_pr_merge_cleanup + cross_session_ram_dashboard)
- v15 5 deliverable (= memory-cleanup.ps1 / posttooluse-periodic-trim.ps1 / sessionend-mandatory-fire.ps1 / session_kpi.py / session_kpi_dashboard.py)

day 6-8 (5/27-5/29):
- v16 6 deliverable (= wall-clock-timer.ps1 / pre-session-cron.ps1 / wrap-up-gate.ps1 / hard-threshold-alert.ps1 / cross-session-kpi-ml.py / session_alert_dashboard.py)
- v17 6 deliverable (= session_delta_writer.py / rolling_aggregate.py / pre-task-hygiene.ps1 / cross_instance_compression_sync.py / weekly-compression-audit.yml / weekly_compression_audit.py)

day 9 (5/30):
- #2186 dev_cache 4 cmd Win 互換 fix
- #2204 Google Calendar 第 1 phase
- #1963 NotebookLM Issue 化 GHA cron
```

---

## Part B: v18 spec — disk hygiene cascade (= 5 new layer K-O / 累積 18 layer)

### 背景 (= part 204 functional verify 発見)

part 204 v15 Layer 1 manual fire 第 3 例累積:
- PRE 91.37% → POST 87.06% / DELTA +1140 MB
- **partial recovery 87% > 85% 残存** = v15 Layer 1 単独では full recovery 不能
- v15+v16+v17 (= 累積 13 layer) では「85% threshold 超過時 manual fire」のみ / cascade なし

**v18 = partial recovery 問題への直接回答** (= 5 layer cascade).

### Layer K: disk hygiene cascade (= v18 main)

**spec**:

v15 Layer 1 (= memory-cleanup.ps1) fire 後の POST RAM% > 85% なら automatic cascade:

```powershell
# pseudo: $POST_RAM_PCT = (measure)
if ($POST_RAM_PCT -gt 85) {
    # Step 1: worktree cleanup
    & python scripts/worktree_cleanup.py --tier2 --apply

    # Step 2: dev cache sweep
    & python scripts/dev_cache_cleanup.py --tier18 --aggressive-cache-sweep --apply

    # Step 3: re-measure
    $POST_CASCADE_RAM_PCT = (measure)

    if ($POST_CASCADE_RAM_PCT -gt 85) {
        # Step 4: last resort interactive prompt
        Write-Warning "RAM%>85 after cascade — close browser tabs / Codex / dormant editors. Run /disk-cleanup if HDD also low."
    }
}
```

**Codex deliverable**: `scripts/disk_hygiene_cascade.ps1` (= 5/30 期限 day 3-5)

### Layer L: pre-commit hard gate

**spec**:

git commit / push 前 hook で資源枯渇 block:

```bash
# .git/hooks/pre-commit (= installed via git config core.hooksPath)
RAM_PCT=$(...measure...)
C_FREE_GB=$(...measure...)

if [ "$RAM_PCT" -gt 80 ] || [ "$C_FREE_GB" -lt 10 ]; then
    echo "❌ pre-commit hard gate: RAM=${RAM_PCT}% / C=${C_FREE_GB}GB"
    echo "   Layer K cascade fire 必須 → bash scripts/disk_hygiene_cascade.ps1"
    exit 1
fi
```

**Codex deliverable**: `.git/hooks/pre-commit` + `scripts/pre_commit_hard_gate.ps1` (= 5/30 期限 day 3-5)

### Layer M: hourly forced compression (= Win Task Scheduler)

**spec**:

Win Task Scheduler で hourly fire / interactive session 中でも実行:

```xml
<Task>
  <Triggers>
    <CalendarTrigger>
      <Repetition>
        <Interval>PT1H</Interval>
      </Repetition>
    </CalendarTrigger>
  </Triggers>
  <Actions>
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-File C:\Users\kanta\.claude\hooks\memory-cleanup.ps1 -Silent</Arguments>
    </Exec>
  </Actions>
</Task>
```

これで「+16 pt / 3 min build-up を hourly で 回収」可能 (= part 204 measured drift).

**Codex deliverable**: `scripts/hourly_forced_compression.ps1` + `scripts/install_hourly_task.ps1` (= Task Scheduler XML install) (= 5/30 期限 day 3-5)

### Layer N: post-PR-merge cleanup hook (= GHA workflow)

**spec**:

PR merge 直後 GHA workflow fire / merged branch + worktree + dev_cache 自動 cleanup:

```yaml
# .github/workflows/post-pr-merge-cleanup.yml
name: post-pr-merge-cleanup
on:
  pull_request:
    types: [closed]
jobs:
  cleanup:
    if: github.event.pull_request.merged == true
    runs-on: ubuntu-latest
    steps:
      - run: gh api -X DELETE repos/$GH_REPO/git/refs/heads/${{ github.event.pull_request.head.ref }}
      # local worktree cleanup は self-hosted runner で実行
```

これで PR cascade (= 5-7 PR/day) による disk pressure 増加防止.

**Codex deliverable**: `.github/workflows/post-pr-merge-cleanup.yml` (= 5/30 期限 day 3-5)

### Layer O: cross-session RAM trend dashboard

**spec**:

session-delta.csv (= v17 Layer F dogfood 第 1 例 / part 204 first row write) 7-day rolling chart:

- Weekly GHA cron (= Mon 06:00 JST / v17 Layer J 既 spec ship 済)
- session-delta.csv → 7-day rolling avg/max/min chart
- regression detection (= 累積 KPI deterioration alert / Slack post)

```python
# scripts/cross_session_ram_dashboard.py
import csv, statistics, pathlib

csv_path = pathlib.Path("memory/session-delta.csv")
rows = list(csv.DictReader(csv_path.open()))[-21:]  # last 21 sessions (~7 days * 3 session/day)
pre_ram_avg = statistics.mean(float(r["pre_ram_pct"]) for r in rows)
freed_mb_total = sum(float(r["ram_delta_mb"]) for r in rows)

# emit dashboard markdown to docs/dashboards/ram_trend_<date>.md
```

**Codex deliverable**: `scripts/cross_session_ram_dashboard.py` (= 5/30 期限 day 3-5)

---

## Part C: 累積 layer 数

| spec | layer 数 | part | merge commit |
|------|---------|------|--------------|
| v15 guaranteed compression | 3 | part 201-b | `877341580` |
| v16 proactive enforcement | 5 | part 202-b | `8b439788d` |
| v17 mandatory per-session compression | 5 | part 203-b | `644be5051` |
| **v18 disk hygiene cascade** | **5** | **part 204-b** | **(本 PR)** |
| **累積** | **18** | | |

## Part D: Codex deliverable 累積

| spec | deliverable 数 | 期限 |
|------|---------------|------|
| v15 | 5 | 5/30 |
| v16 | 6 | 5/30 |
| v17 | 6 | 5/30 |
| **v18** | **5** | **5/30** |
| **累積** | **22** | |

## Part E: iterative ask 累積 17 layer 過去最高 update

| v | part | date | layer 追加数 | 累積 |
|---|------|------|-------------|------|
| v3 | part 178b | 2026-05-04 | 1 | 1 |
| ... | ... | ... | ... | ... |
| v15 | part 201-b | 2026-05-11 18:40 | 3 | 14 |
| v16 | part 202-b | 2026-05-11 22:00 | 5 | 15 |
| v17 | part 203-b | 2026-05-12 00:53 | 5 | 16 |
| **v18** | **part 204-b** | **2026-05-12 12:45** | **5** | **17** |

過去最高 update record:
- v15 14 → v16 15 → v17 16 → **v18 17**
- 月内 14 day window (= 5/4-5/12 currently)
- 平均 interval 0.82 day (= 14 / 17)
- 100% ship rate

## Part F: 2-instance hand-off batch 第 6 例累積

| 例 | part | doc | spec |
|----|------|-----|------|
| 第 1 例 | part 199-b | v13 SessionEnd | 1 layer |
| 第 2 例 | part 200-b | v14 compression | 4 layer |
| 第 3 例 | part 201-b | v15 guaranteed | 3 layer |
| 第 4 例 | part 202-b | v16 proactive | 5 layer |
| 第 5 例 | part 203-b | v17 mandatory | 5 layer |
| **第 6 例** | **part 204-b** | **v18 disk hygiene cascade** | **5 layer** |

## Part G: ack expectation

- Codex 5/13 T+4 ping 予定 (= Win Claude 主導)
- 5/22 sprint start 経過監視 (= 22 deliverable PR open 監視)
- 5/30 期限着地 confirm
