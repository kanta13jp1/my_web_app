# cross-instance-pr: part 203-b v17 mandatory per-session compression + WBS Top 5 hand-off

**date**: 2026-05-12 火曜 01:30 JST
**from**: Win Claude (= Win版#132 part 203-b / iterative ask 第 16 layer ship)
**to**: Win Codex (= sprint 5/22-5/30 in-flight + 5/30 deliverable / NEW v17 6 deliverable)
**priority**: P1 (= user iterative ask 累積 16 layer 第 1 例 / 過去最高 update from v15 14 → v16 15 → v17 16)
**iterative ask**: v3 (part 178b) → v4 (189) → v5 (190) → v6 (191) → v7 (192-b) → v8 (193) → v9 (194) → v9 verify (195) → v10 (196) → v11 (197) → v12 (198) → v13 (199-b) → v14 (200-b) → v15 (201-b) → v16 (202-b) → **v17 (203-b)** = 16 layer 累積

---

## Part A — Win Claude WBS Top 5 (= 2026-05-12 part 203-b query / 期限近順)

| # | id | title | end_date | status | recovery_plan |
|---|----|----|---|---|---|
| 1 | `f02d5e49` | [Issue #1950] ブログ/ニュース配信本番E2E + 完全自動化仕上げ | 5/11 過 | **in_progress** (= 5%) | **Codex 再 assign 推奨** (= EF + GHA = Codex realm) |
| 2 | `c6406237` | [Issue #1495] [P0][Mobile] iOS/Android アプリ同時リリース + 配布自動化 | 5/14 残 2 day ⚠️ | **in_progress** (= 5%) | **Codex 再 assign 部分担当** (= P1+P2 ビルド/配布 GHA = Codex / P3 UAT = Win Claude) |
| 3 | `9d9ea821` | ユーザー数 50 人達成 α版目標 | 5/28 | in_progress (= 8%) | growth = marketing = Codex/T-1 dispatch realm |
| 4 | `defe198f` | provider.chat 残 65 社段階実装 Phase 4 | 8/30 | in_progress (= 100% ✅) | impl 完了済 |
| 5 | `50fd622d` | ユーザー数 500 人達成 β版目標 | 5/28 | pending | growth = marketing realm |

**workload**: Win Claude open=2 / high=2 / Codex open=453 / high=58 (= 2 instance 不均衡)

→ Win Claude this session = v17 spec ship + 上位 2 件 triage + Codex hand-off / **全 5 件 Codex sprint 在りで Win Claude primary work は spec / verify / triage**

## Part B — Win Codex WBS Top 5 (= 期限近順 / 全 5/11 過)

| # | id | title | github | status |
|---|----|----|---|---|
| 1 | `fa58d460` | [Issue #1559] AI Tool Watch → Issue/WBS/PR drafts 完全自動 routing | #1559 OPEN | pending |
| 2 | `d6b52076` | [Issue #1724] notebooklm-video-pipeline 5 secrets 設定 | #1724 OPEN | pending |
| 3 | `78c7ee7e` | [Issue #2204] Google Calendar 段階導入 EPIC | #2204 OPEN | **in_progress (= 20%)** |
| 4 | `77f54e9c` | [Issue #1640] MVPスコープ凍結 + GA準備ゲート | #1640 OPEN | **in_progress (= 75%) ⚡** |
| 5 | `ae4e7a18` | [Issue #1787] AI Tool 2026-05 適用 (Claude v2.1.126 + Codex gpt-5.5 + Copilot + Gemini 2.5) | #1787 OPEN | pending |

→ Codex this session = #1640 (75%) clear-out priority + #1559 #1724 #1787 sprint pickup + #2204 (20%) continue

---

## Part C — v17 spec: mandatory per-session compression discipline (= iterative ask 第 16 layer)

### Finding (= part 203-b user observation)

> "今の開発フローだと、ローカル環境のメモリやハードディスク容量が必ず枯渇します。毎回のセッションで必ずメモリやハードディスク容量を圧縮する施策を検討してください。"

**translation**: Current dev flow inevitably exhausts local RAM/HDD. Need MANDATORY per-session compression measures.

**root cause analysis** (= v15 + v16 spec 後も解決していない理由):
- v15 + v16 = always-fire + fail-closed enforcement spec ship 済
- だが actual IMPL 未着手 (= Codex 5/30 期限 / 11 deliverable / 18 day 残)
- spec ship → impl の gap で「systemic exhaust」が継続
- **session 単位の observability + cross-session aggregate KPI が不足** = 個別 session の improvement は見えるが、N session 累積で baseline 上昇 (=「ratchet」) が検知されない

### v17 spec (= 5 new layer / cross-session observability + mandatory KPI logging)

#### Layer F: SessionStart KPI log mandatory (= observability-first)

- 既存 memory-cleanup.ps1 log に加え、**全 session で session-delta.csv に行追加 mandatory**
- 行内容: `session_id, started_at, pre_ram_pct, post_ram_pct, pre_c_free_gb, post_c_free_gb, ram_delta_mb, c_delta_gb, ram_trim_count, instance`
- 圧縮 result に関係なく row 必須 (= skip 不能 / 失敗時も failure row 必須)

#### Layer G: rolling 3-session aggregate KPI (= regression detection)

- session-delta.csv tail-3 で aggregate:
  - `avg_baseline_ram_pct` (= 3 session pre_ram_pct 平均)
  - `avg_post_ram_pct` (= 3 session post_ram_pct 平均)
  - `avg_freed_mb` (= 3 session ram_delta_mb 平均)
- 警報 condition (= 3 連続観測時 hard alert):
  - `avg_baseline_ram_pct > 80%` → escalate v18 / hard intervention
  - `avg_freed_mb < 500 MB` → fire pattern degradation / hook config audit 必要
  - `avg_post_ram_pct > 75%` → compression effectiveness 不足

#### Layer H: pre-task hygiene gate (= 70% threshold lowest)

- Bash / Edit / Write tool call 前に PreTool hook で RAM% check
- RAM > 70% → unconditional pre-task compression fire (= 既存 7 hook 補完)
- 70% = v11 85% / v17 lowest threshold = "always-on" 化

#### Layer I: cross-instance compression sync (= fleet-wide accountability)

- Win Claude + Win Codex 両 instance session-delta.csv を週次 cross-instance-pr doc 経由 sync
- fleet aggregate KPI table 生成 (= per-instance baseline / per-instance freed avg / regression detection)
- 「片方 instance だけ compression 効いている」状態を検知

#### Layer J: weekly compression audit GHA cron

- GHA cron Mon 06:00 JST trigger
- script: `scripts/weekly_compression_audit.py`
  - read session-delta.csv last 7 day
  - generate 7-day rolling KPI table
  - post comment to disk-hygiene tracking Issue (= 新規 Issue 起票 or 既存 Issue 利用 / [ISSUE-PRECHECK] 適用)
- 自動 escalate: 7-day avg breach → cross-instance-pr doc auto-create

### v17 累積 layer (= v15 3 + v16 5 + v17 5 = **13 layer**)

| Layer | Phase | Trigger | Fail-closed | Observability |
|-------|-------|---------|-------------|---------------|
| v15-1 | SessionStart | always-fire | ❌ | hook log |
| v15-2 | PostToolUse | 30 tool call OR 30min | ❌ | hook log |
| v15-3 | SessionEnd | /wrap-up 直前 | ❌ | hook log |
| v16-A | pre-session | nightly 04:00 cron | ✅ | cron log |
| v16-B | session-wide | 15min interval | ✅ | hook log |
| v16-C | /wrap-up 直前 | hard gate (DELTA<100 AND RAM>80) | ✅ | block log |
| v16-D | session-wide | RAM 95% OR C: 30 GB- | ✅ | toast log |
| v16-E | cross-session | ML predicted (= past 30 agg) | ✅ | ML log |
| **v17-F** | **SessionStart** | **mandatory KPI log** | **❌ row 必須** | **session-delta.csv** |
| **v17-G** | **post-Layer F** | **rolling 3-session aggregate** | **⚠️ alert if breach** | **session-delta-aggregate.csv** |
| **v17-H** | **PreTool** | **RAM > 70% pre-task fire** | **✅ fire-or-block** | **pre-task-fire.log** |
| **v17-I** | **weekly sync** | **cross-instance KPI merge** | **❌ informational** | **cross-instance-pr doc** |
| **v17-J** | **weekly cron** | **GHA Mon 06:00 audit** | **❌ informational** | **GitHub Issue comment** |

### session_kpi.py 拡張 (= v15 5 + v16 3 + v17 5 = **13 metric**)

- v15 (5): layer1_fired / layer1_delta_mb / layer2_fire_count / layer2_delta_total_mb / layer3_fired
- v16 (3): wall_clock_fire_count / threshold_breach_count / session_duration_min
- **v17 (5)**: 
  - `kpi_row_written` (bool / mandatory true)
  - `rolling_3_avg_baseline_ram_pct` (float)
  - `rolling_3_avg_freed_mb` (int)
  - `pre_task_fire_count` (int)
  - `weekly_audit_due` (bool / Mon 06:00 JST 以降 true)

### Codex impl 待ち (= 5/30 期限 / 6 deliverable NEW)

- [ ] `scripts/session_delta_writer.py` (= Layer F mandatory KPI log)
- [ ] `scripts/rolling_aggregate.py` (= Layer G 3-session regression detection)
- [ ] `.claude/hooks/pre-task-hygiene.ps1` (= Layer H PreTool hook 70% threshold)
- [ ] `scripts/cross_instance_compression_sync.py` (= Layer I weekly sync)
- [ ] `.github/workflows/weekly-compression-audit.yml` (= Layer J GHA cron)
- [ ] `scripts/weekly_compression_audit.py` (= Layer J audit script)

### PHILOSOPHY-22 alignment (= 7/9 ✅)

- 主要実装: v17 observability-first 圧縮 mandatory + cross-session regression detection + fleet-wide accountability
- 該当原則: #2 (mission = systemic problem evidence-based 解決) + #4 (mentor = Codex hand-off enrichment) + #5 (商品 = hygiene effectiveness) + #6 (時間 = 資本 = mandatory enforcement) + #7 (資産負債 = session-delta.csv KPI 蓄積) + #8 (KPI = 13 metric expansion) + #9 (IPO = audit-ready hygiene + weekly compliance report)
- 整合性スコア: 7/9 ✅ ([PHILOSOPHY-22] gate 通過)

---

## Part D — part 203-b dogfood pattern (= 第 N 例累積 / 134 part 連続)

**NEW (= 本 session 第 1 例)**:
- 「v17 mandatory per-session compression spec ship」第 1 例 (= 13 layer mandatory + cross-session observability)
- 「iterative ask 累積 16 layer」第 1 例 (= 過去最高 update from v15 14 → v16 15 → v17 16)
- 「2-instance hand-off batch」第 5 例累積 (= v13-v17 全 5 例 = 同一 user iterative ask 連鎖)
- 「post-wrap-up escalation」第 5 例累積 (= same-day same-session continuation)

**累積 update**:
- 「v15 Layer 1 functional verify」第 2 例 (= part 203 phase 1 ship 済)
- 「MEMORY consolidation」第 4 例 (= part 203 phase 1 ship 済 / -71%)
- 「[COMPACTION-RESUME] 90min discipline」第 8 例 (= 翌日 fresh start 復帰成功 + post-wrap-up 第 5 例累積)

---

## Part E — Codex 5/12-5/13 batch ping 6 件 (= v17 ack request)

| # | target | content | SLA |
|---|--------|---------|-----|
| 1 | Issue #2186 | dev_cache hygiene 進捗確認 + v17 evidence | 5/22 残 10 day |
| 2 | PR #2352 (merged) | v15 spec receipt ack + 着手判断 | 5/30 残 18 day |
| 3 | PR #2358 (merged) | v16 spec receipt ack + 着手判断 | 5/30 残 18 day |
| 4 | **NEW: 本 doc PR** | **v17 spec receipt ack + 着手判断** | 5/30 残 18 day |
| 5 | Issue #1559 + #1640 + #1724 + #1787 (= Codex top 5) | 期限近順 sprint pickup priority | 5/11 過 |
| 6 | Issue #1950 + #1495 (= 再 assign 候補) | Codex 再 assign 判断要求 (= cross-instance hand-off) | 5/14 ⚠️ 残 2 day |

---

## Part F — next session 推奨条件 (= part 204+)

1. **v15+v16+v17 Codex impl progress monitor** (= 11 + 6 = 17 deliverable / 5/30 残 18 day / Win Codex 完了率 track)
2. **#2186 dev_cache hygiene progress** (= SLA 5/22 残 10 day / Codex sprint pickup status confirm)
3. **#1495 Codex 再 assign 判断** (= 5/14 期限 残 2 day / 即 pickup or escalate)
4. **#1559 + #1640 + #1724 + #1787 sprint pickup** (= Codex top 5 / Win Codex 完了率 update)
5. **UI verify [UI-VERIFY] backlog 回収** (= 約 1 day 経過 / home/AI 大学/LP/ranking + mobile UAT)
6. **session-delta.csv first row write** (= v17 Layer F dogfood 第 1 例 / impl 完了後)

---

## Part G — 134 part 連続 dogfood maintenance

- Win版#132 part 70 → 203-b = 134 セッション連続 hygiene dogfood ship rate 100%
- Philosophy 7/9 ✅ 全 part 維持
- iterative ask 累積 16 layer = user-driven evolution 過去最高
- 2-instance fleet hand-off batch 第 5 例累積 = Codex sprint 認知 cost 削減 pattern 確立

cc @kanta13jp1
