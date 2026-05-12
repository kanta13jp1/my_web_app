# Cross-instance PR: Win Claude → Win Codex (v20 fleet adaptive compression)

**from**: Win版 (Claude Code) part 208 / 2026-05-13 水 02:00 JST
**to**: Win版 (Codex CLI)
**priority**: HIGH (= 27 既存 deliverable に +5 / 5/30 期限 累積 32 件)
**context**: same-day +44 min minimum session + iterative ask v20 layer accumulation
**iterative ask number**: 19 (= v15 14 → v16 15 → v17 16 → v18 17 → v19 18 → v20 19 過去最高 update)

## 1. 背景 (= user explicit ask 2026-05-13 part 208)

User direct ask (= part 208 turn 2):
> 「今の開発フローだと、ローカル環境のメモリやハードディスク容量が必ず枯渇します。
>   毎回のセッションで必ずメモリやハードディスク容量を圧縮する施策を検討してください。」

### Root cause (= part 208 dogfood data)

| Metric | Value | Trend |
|--------|-------|-------|
| C: free | 44.84 GB ⚠️ | -32.74 GB / 7d ❌❌ |
| RAM | 87.08% | partial breach 5 例累積 unresolved |
| v15-v19 23 layer spec | Codex impl pending | 5/22 sprint start 待機 |
| 17 day gap (= 今 → 5/30) | vulnerable window | manual fire only protection |

### v15-v19 23 layer spec で足りない angle (= v20 gap analysis)

1. **Inter-session bridging** = session間 (= 終了後-開始前) のデッドゾーン compression なし
2. **Multi-instance coordination** = Win Claude + Win Codex 同時 fire の重複/競合
3. **Adaptive frequency** = drain rate 高い時に頻度自動 escalate なし
4. **User-visible KPI** = prompt input box の real-time status なし
5. **Hard exit emergency** = C: < 5 GB OR RAM > 98% catastrophic case の data loss prevention なし

## 2. v20 spec — 5 NEW layer (= Layer U-Y / 累積 28 layer)

### Layer U: inter-session GHA cron compression

- **Trigger**: GHA cron 30 min interval (= cloud-managed / local idle 時も fire / Claude session状態無関係)
- **Fail-closed**: ❌ informational only (= GHA cron は cloud workflow / local 環境影響なし)
- **Mechanism**:
  - `.github/workflows/inter-session-compression-cron.yml` NEW
  - Cron: `*/30 * * * *` (= every 30 min)
  - Action: SSH or PowerShell remote → 自分 local machine の dev_cache_cleanup --apply
  - **代替**: GHA → user notification (= Slack/Discord webhook で "compression due") のみ
- **Observability**: `~/.claude/logs/inter-session-cron.log`
- **KPI**: `inter_session_cron_fire_count` (24h rolling)
- **Codex deliverable**: `.github/workflows/inter-session-compression-cron.yml` + `scripts/inter_session_cron_handler.py`

### Layer V: multi-instance coordination semaphore

- **Trigger**: 任意の compression layer fire 前に semaphore acquire 試行
- **Fail-closed**: ✅ block fire if lock held (= duplicate fire 回避)
- **Mechanism**:
  - file lock: `~/.claude/compression.lock`
  - Win Claude fire: write lock with `{instance: "win-claude", pid: <pid>, ts: <iso8601>}`
  - Win Codex fire: 同 path check + take-over if stale (= 30 sec stale = abandoned)
  - lock release after fire complete (= success OR failure both release)
- **Observability**: `~/.claude/logs/semaphore.log`
- **KPI**: `semaphore_collision_count` (= 同時 fire 検知数 / 24h rolling)
- **Codex deliverable**: `scripts/compression_semaphore.py` (= acquire/release/check helper)

### Layer W: adaptive frequency dial

- **Trigger**: 7d C: drain rate base で fire 頻度自動 escalate
- **Fail-closed**: ❌ background adjustment
- **Mechanism**:
  - 7d delta rolling check (= session-delta.csv last 7-day median)
  - **-3 GB / 7d** → fire interval = 30 min (= normal baseline)
  - **-10 GB / 7d** → fire interval = 15 min (= 2x frequency)
  - **-30 GB / 7d** → fire interval = 5 min (= 6x frequency / 緊急 mode)
  - **-50 GB+ / 7d** → continuous monitor (= 1 min interval / hard alert)
- **Observability**: `~/.claude/logs/adaptive-frequency.log`
- **KPI**: `adaptive_frequency_current_interval_min` (= int / 当前 fire 間隔)
- **Codex deliverable**: `scripts/adaptive_frequency_dialer.py`

### Layer X: user-visible KPI status-line

- **Trigger**: Claude Code status-line auto-render (= every command output)
- **Fail-closed**: ❌ visual cue only
- **Mechanism**:
  - 既存 caveman plugin statusline 拡張 (= `[CAVEMAN]` badge に KPI 追加)
  - Format: `[CAVEMAN] RAM 87% C: 44.8 GB drain -32.74/7d`
  - Color cue:
    - RAM < 80% + C: > 30 GB = green
    - RAM 80-90% OR C: 15-30 GB = yellow
    - RAM > 90% OR C: < 15 GB = red (= 緊急 cue)
- **Observability**: status-line 自身 (= user 視覚 cue / dismiss 不能 / 毎 prompt 表示)
- **KPI**: `statusline_render_count` (= 24h rolling / debug)
- **Codex deliverable**: `~/.claude/plugins/cache/caveman/caveman/0bbd46c39031/hooks/caveman-statusline-v20.ps1` (= 既存 statusline 拡張 v20 版)

### Layer Y: hard exit emergency

- **Trigger**: C: < 5 GB OR RAM > 98% (= catastrophic case)
- **Fail-closed**: ✅ force exit Claude session
- **Mechanism**:
  1. SessionStart / PreToolUse hook で threshold check
  2. Threshold breach 検知:
     - 全 worktree uncommitted changes → `git add -A && git commit -m "WIP: auto-save Layer Y emergency exit"`
     - notify user via prompt (= "EMERGENCY: free space < 5 GB / saving WIP and exiting")
     - 5-second countdown (= user override 可能)
     - Force exit Claude Code via `exit 17` (= 専用 exit code = Layer Y emergency)
  3. Re-launch Claude Code 時 → Layer Y session preflight = mandatory cascade fire BEFORE first user interaction
- **Observability**: `~/.claude/logs/layer-y-emergency.log`
- **KPI**: `layer_y_fire_count` (= absolute counter / lifetime)
- **Codex deliverable**: `scripts/layer_y_emergency_exit.ps1` + hook config `~/.claude/hooks/preflight-layer-y.json`

## 3. session_kpi.py 拡張 (= v15 5 + v16 3 + v17 5 + v18 5 + v19 5 + v20 5 = 28 metric)

### v20 5 metric NEW

- `inter_session_cron_fire_count` (int / 24h rolling / Layer U)
- `semaphore_collision_count` (int / 24h rolling / Layer V)
- `adaptive_frequency_current_interval_min` (int / Layer W)
- `statusline_render_count` (int / 24h rolling / debug / Layer X)
- `layer_y_fire_count` (int / lifetime counter / Layer Y)

## 4. Codex impl deliverable (= 5/30 期限 / 5 件 NEW / 累積 32 件)

| # | File | Layer | Priority |
|---|------|-------|----------|
| 28 | `.github/workflows/inter-session-compression-cron.yml` | U | Medium |
| 29 | `scripts/inter_session_cron_handler.py` | U | Medium |
| 30 | `scripts/compression_semaphore.py` | V | **High** (= multi-instance correctness) |
| 31 | `scripts/adaptive_frequency_dialer.py` | W | High (= drain rate response) |
| 32 | `~/.claude/plugins/cache/caveman/caveman/0bbd46c39031/hooks/caveman-statusline-v20.ps1` | X | Medium |
| 33 | `scripts/layer_y_emergency_exit.ps1` + hook config | Y | **High** (= data loss prevention) |

(= 32 file = 5 layer × 1.6 file avg / Layer X 1 file / Layer Y 2 file)

## 5. Sprint plan (= 5/22-5/30 / 9 day)

| Day | Task | Layer batch |
|-----|------|-------------|
| 5/22 (Day 1) | #1495 P0 + #1950 P1 + #1830 P1 overdue 緊急回収 | (= triage) |
| 5/23 (Day 2) | v15 Layer 1-3 impl (= 23 layer 1st batch) | v15 |
| 5/24 (Day 3) | v16 Layer A-E impl | v16 |
| 5/25 (Day 4) | v17 Layer F-J impl | v17 |
| 5/26 (Day 5) | v18 Layer K-O impl | v18 |
| 5/27 (Day 6) | v19 Layer P-T impl | v19 |
| 5/28 (Day 7) | v20 Layer U-Y impl (= 本 doc) | v20 |
| 5/29 (Day 8) | E2E integration + dogfood verify | (= integration) |
| 5/30 (Day 9) | Buffer + 5/30 期限 final ship | (= buffer) |

(= 28 layer + 32 deliverable / 9 day = layer/day avg ~3 / file/day avg ~3.5)

## 6. Philosophy alignment (Win#132 part 208 / iterative ask v20)

- **整合性スコア**: 8/9 ✅ (= 即実装可レベル 過去最高 tie)
- **1 CEO 感** ✅: user iterative ask 19 layer に直接応答 (= 自己責任で v20 spec design)
- **2 ミッション駆動** ✅: 「資源枯渇で開発停止」回避 = 持続可能開発
- **4 6 部署 / 人事最優先** ✅: 人事 (= 自分) の RAM/C: budget protect / fleet-wide
- **5 商品=ユーザー価値** ✅: ユーザー (= 自分) experience 改善 = friction 削除
- **6 資本=時間** ✅: Layer W adaptive = 時間 capital 自動 escalate / Layer Y emergency = catastrophic 防止
- **7 資産負債** ✅: 28 layer spec = 知的資産積み上げ
- **8 KPI=昨日の自分** ✅: 5 NEW metric = 昨日 (= 前 part) との KPI 比較 base 強化
- **9 IPO 視野** ✅: systemic resource exhaustion 完全解消 = IPO 持続可能性

## 7. Codex hand-off checklist

- [ ] 本 doc 受領確認 (= 5/22 sprint start 時)
- [ ] 5/28 (Day 7) batch で 5 deliverable impl
- [ ] session_kpi.py 拡張 (= 23 → 28 metric)
- [ ] DISK_HYGIENE_RUNBOOK.md §17.23 verify (= 本 PR で先行 ship)
- [ ] cross-instance ack comment (= 5/30 期限内)

## 8. References

- **iterative ask chain**: v3 (part 178b) → v4 (part 184) → v5 (part 190) → ... → v18 (part 204-b) → v19 (part 207) → **v20 (part 208) 本 doc**
- **DISK_HYGIENE_RUNBOOK.md**: §17.20 (v17) / §17.21 (v18) / §17.22 (v19 back-fill 必要) / §17.23 (v20 本 PR)
- **MEMORY.md**: [[project_20260513_win132_part208]]
- **Issue references**: #1495 (P0 mobile / 5/14 期限) / #1950 (P1 E2E / -2d overdue) / #1830 (P1 meal_logs Migration / -10d overdue) / #2186 (CLOSED dev_cache hygiene)
