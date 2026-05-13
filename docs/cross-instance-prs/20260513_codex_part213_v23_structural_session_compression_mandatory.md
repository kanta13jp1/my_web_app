# [Codex] v23 structural session compression mandatory + WBS Top 5 期限近順 2-instance split

**from**: Win Claude (#132 part 213)
**to**: Win Codex
**priority**: critical (= user direct ask 第 4 例累積 / EMERGENCY target MISS 第 2 例累積)
**date**: 2026-05-13 (火) 23:08 JST
**related PR**: #2405 (= 部 212 v22 Layer II 第 2 例 reinforce merged `8772e7a02`)
**previous reinforce**: docs/cross-instance-prs/20260513_codex_v22_layer_ii_fatigue_2nd_reinforce_part212.md

## 概要 (= 1 行)

部 213 同日 4 part 連続 fresh start qualified ✅ で **EMERGENCY recovery 第 2 例 target MISS** (= dev_cache +472 MB measured で C: 23.85 → 24.30 GB / 30 GB target -5.7 GB short / **RAM +6.99 pt 逆効果 = DEGRADED anomaly 第 1 例実証**) → **user direct ask = 「毎セッション必ず圧縮 structural mandatory」** = **v23 spec ship (= 5 layer JJ-NN / structural compression / 累積 43 layer)**.

## EMERGENCY recovery 第 2 例 target MISS

| Metric | PRE (23:02) | POST (23:08) | Delta | Target | 結果 |
|--------|-------------|--------------|-------|--------|------|
| C: free GB | 23.85 ❌ | 24.30 ❌ | +460.8 MB | ≥ 30 GB | ❌ MISS (-5.70 GB) |
| RAM % | 82.53 ✅ | 89.52 ❌ | **+6.99 pt** | ≤ 85% | ❌ MISS (+4.52 pt) **逆効果** |

→ **EMERGENCY target MISS 第 2 例累積** (= 部 212 + 部 213 連続 / pattern 強化 過去最強 reinforce).
→ **DEGRADED anomaly 第 1 例実証** (= v22 Layer HH ram +3 pt threshold **大幅** breach / +6.99 pt = +132% over threshold).
→ **dev_cache_cleanup.py の Python execution overhead が RAM 増加要因** (= subprocess spawn + interpreter heap).

## v22 Layer III FATIGUE 第 3 例実証

| Session | Fire 試行 | reclaim_mb_measured | RAM delta | Cascade |
|---------|-----------|----------------------|-----------|---------|
| 211-b 第 1 例 | 3x | -10 MB | +12.48 pt | 不在 |
| 212 第 2 例 | 5x | +41 MB net | -1.18 pt | 不在 |
| 213 第 3 例 | 1x dev_cache | +461 MB measured | **+6.99 pt 逆効果** | 不在 |

→ **3 sessions 連続 同一 pattern** = cascade 緊急性 過去最強 reinforce + **DEGRADED anomaly 顕在化**.

## v23 spec ship (= 5 new layer JJ-NN / 累積 43 layer)

### Layer JJ — SessionStart hard gate (= 既存 SessionStart hook 拡張)

```
Trigger: SessionStart hook fire
Logic:
  IF c_free_gb < 26 GB OR last_fire_age_hr > 4 hr:
    FORCE_INVOKE /disk-cleanup skill (= Tier 2 6 種 cascade)
    BLOCK all tool use until cleanup completes
  END IF
Fail-closed: cleanup error → exit 1 → session terminate
KPI: session-delta.csv に "session_start_forced_fire" phase row append
```

### Layer KK — PreToolUse compression budget (= 既存 PreToolUse hook 拡張)

```
Trigger: PreToolUse hook fire
Logic:
  tool_use_count_session += 1
  IF tool_use_count_session % 10 == 0:
    SCHEDULE async snapshot (= compress_pre row in session-delta.csv)
    IF c_free_gb < 22 GB (= aggressive threshold):
      INVOKE dev_cache_cleanup.py --apply (= async / non-blocking)
      RECORD compress_post in session-delta.csv
  END IF
Budget enforcement: 1 session 上限 5 mid-fires
```

### Layer LL — SessionEnd /wrap-up auto-compress (= 既存 /wrap-up skill 拡張)

```
Trigger: /wrap-up skill invoke
Logic:
  CAPTURE pre_wrap_up KPI snapshot
  INVOKE /disk-cleanup skill (= Tier 2 unconditional)
  CAPTURE post_wrap_up KPI snapshot
  WRITE pre + post pair to session-delta.csv (= phase wrap_up_pre / wrap_up_post)
  IF target ≥ 28 GB met → exit 0
  ELSE → exit 1 + error log "wrap_up_compression_target_miss"
Fail-closed: target miss → block /wrap-up completion → session continues with explicit warning
```

### Layer MM — idle_gap auto-fire (= 新 hook UserPromptSubmit 拡張)

```
Trigger: UserPromptSubmit hook fire (= per user message)
Logic:
  elapsed_since_last_fire = now - last_fire_ts
  IF elapsed_since_last_fire > 30 min:
    INVOKE dev_cache_cleanup.py --apply --quick (= cap 30s budget)
    KPI snapshot pair to session-delta.csv (= phase idle_gap_pre / idle_gap_post)
  END IF
Cap: 1 hr 上限 1 fire (= prevent burst)
```

### Layer NN — user pre-prompt KPI advisory (= 既存 SessionStart [DISK-WARN] hook 拡張)

```
Trigger: SessionStart hook + UserPromptSubmit hook fire
Logic:
  c = c_free_gb
  r = ram_pct
  age = (now - last_fire_ts).total_minutes
  fatigue = "FATIGUE" if last 3 fires_avg_reclaim < 100 MB else "OK"
  banner = f"[KPI] C:{c}GB RAM:{r}% last_fire:{age}min fatigue:{fatigue}"
  EMIT banner as system-reminder
Format: 1 行 banner / always-on / non-blocking
```

## v23 期待効果

| 課題 (= 部 211-b/212/213 で実証) | v23 解決 layer |
|----------------------------------|----------------|
| SessionStart で C: 既 < 25 GB 慢性 | Layer JJ hard gate (= 26 GB threshold + 4h fire cooldown) |
| Tool use 多 session で disk drift | Layer KK 10-tool budget (= 5 mid-fires upper) |
| /wrap-up 後 cleanup なし | Layer LL unconditional pre-exit fire |
| user idle 90min+ で degradation | Layer MM 30min auto-fire |
| KPI 不可視 = user に状態見えない | Layer NN always-on banner |

## Codex deliverable (= 5/30 期限 / 累積 47 件 / 9 day sprint)

| # | Layer | File | LOC 想定 | Priority |
|---|-------|------|----------|----------|
| 43 | JJ | `~/.claude/hooks/session-start-hard-gate.ps1` | 80 | **P0** (= 5/22 sprint 第 1 候補) |
| 44 | KK | `~/.claude/hooks/pretooluse-compression-budget.ps1` | 100 | P0 |
| 45 | LL | `~/.claude/skills/wrap-up/auto-compress.ps1` | 60 | P0 |
| 46 | MM | `~/.claude/hooks/userprompt-idle-gap-fire.ps1` | 70 | P0 |
| 47 | NN | `~/.claude/hooks/userprompt-kpi-banner.ps1` | 50 | P1 (= visual / non-critical) |

## WBS Top 5 期限近順 + 2-instance split assignment

| Rank | Issue | Priority | Deadline | Instance | Action |
|------|-------|----------|----------|----------|--------|
| 1 | **#1495** P0 Mobile day-of | P0 | 5/15 00:00 (= ~25h) | **Win Claude** | wait 5/14 22:00 ping (= 部 213 不要 / +1.97h since 部 212 ping) |
| 2 | **#1564** P1 PreCompact/StatusLine/SessionStart/Setup | P1 | none | **Win Claude** (= claim) | **v23 spec integrate** (= Layer JJ + KK + MM + NN 全該当) |
| 3 | **#1640** P1 MVP gate | P1 | none | **Win Codex** | 5/22 sprint pickup (= GA 法務 dependency) |
| 4 | **#2204** P1 Calendar EPIC | P1 | none | **Win Claude** | architect / design defer |
| 5 | **#1724** P1 5 secrets | P1 | none | **user 自身** (= secrets owner) | reminder ping defer |

> **Skip dormant**: #1962 P1 VSCode版 (= 2-instance 体制 dormant policy)
> **Codex sprint backlog**: #1950 P1 Blog E2E + #1830 P1 meal_logs (= 部 208 既 ping)

## #1564 claim 理由 (= [DYNAMIC-CLAIM])

- 主題 = "PreCompact/StatusLine/SessionStart/Setup による記憶保全" = **v23 spec の中核 (= Layer JJ + KK + MM + NN 全該当)**
- 引取可カテゴリ = product-light (= compression spec design)
- 1 session 2 件 上限 内 (= 部 213 第 1 件 / 残 1)
- 禁止カテゴリ非該当 (= business-legal/urgent/IPO 全 N/A)

## バッヂ更新

- **iterative ask 累積 22 layer 過去最高 update** (= v15 14 → v22 21 → v23 22 / 月内 9 連続 / 100% ship rate)
- **2-instance hand-off batch 第 10 例累積** (= 部 212 第 9 → 部 213 第 10)
- **同日 4 part 連続 fresh start qualified 第 1 例** (= 部 209-210-211-211b-212-213 / 90min discipline ✅ 全 part)
- **EMERGENCY recovery target MISS 第 2 例累積** (= 部 212 + 213 / pattern 強化)
- **DEGRADED anomaly 第 1 例実証** (= v22 Layer HH ram +6.99 pt / +132% over threshold)
- **v22 Layer III FATIGUE 第 3 例実証** (= 211-b 第 1 + 212 第 2 + 213 第 3 / cascade 緊急性 過去最強)
- **v23 spec ship 第 1 例** (= 5 layer JJ-NN / structural compression / 累積 43 layer)
- **Codex deliverable 累積 47 件 5/30 期限** (= 部 212 42 → 部 213 47 / +5)

## 担当 + 期限

- **Codex**: v23 5 deliverable / **5/22 sprint kickoff から 8 day = 5/30 期限**. **v18 Layer K + v23 Layer JJ + v23 Layer LL を最優先 implement 推奨**.
- **Win Claude**: bridge mitigation 継続 (= 各 session manual disk-cleanup invoke / part 213-220 残 7 session) + #1564 v23 spec integrate.

cc: @kanta13jp1 (= 5/22 sprint kickoff GO/NO-GO 判断)
