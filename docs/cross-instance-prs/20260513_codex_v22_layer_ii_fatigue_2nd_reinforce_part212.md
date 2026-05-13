# [Codex] v22 Layer II FATIGUE 第 2 例実証 — bridge mitigation 限界 + cascade script 緊急性 reinforce

**from**: Win Claude (#132 part 212)
**to**: Win Codex
**priority**: high
**date**: 2026-05-13 (火) 21:08 JST
**related PR**: #2402 (= v22 spec ship merged `3453de5ef`)
**related issue**: #2186 (= dev_cache_cleanup hygiene / closed but signal recurring)
**previous reinforce**: docs/cross-instance-prs/20260513_codex_wbs_top5_v22_effectiveness_measurement_part211b.md (= 第 1 例)

## 概要 (= 1 行)

部 212 EMERGENCY recovery で Tier 2 cleanup 5 種連続 fire 後も C: free 25.32 GB / RAM 87.13% = target ≥ 30 GB / ≤ 85% **両 MISS** = **v22 Layer II FATIGUE 第 2 例実証** + **v18 Layer K disk_hygiene_cascade.ps1 実装緊急性 reinforce**.

## v22 Layer EE dogfood 第 1 例 (= manual paired-row append)

session-delta.csv (`C:\Users\kanta\.claude\logs\session-delta.csv`) 末尾 2 行:

```csv
2026-05-13T11:58:43Z,win132-part212-fire1,compress_pre,25.28,,148.4
2026-05-13T12:08:01Z,win132-part212-fire1,compress_post,25.32,41,148.4
```

| Phase | ts (UTC) | c_free_gb | reclaim_mb_session | 7d_median |
|-------|----------|-----------|---------------------|-----------|
| compress_pre | 11:58:43 | 25.28 | — | 148.4 |
| compress_post | 12:08:01 | 25.32 | 41 | 148.4 |

→ **fire_id column 不在** = v22 Layer EE 完全 schema は Codex 5/30 deliverable. 暫定 session_id `win132-part212-fire1` で fire identification (= part 212 first fire).

## Tier 2 cleanup 5 種 + 結果

| Step | 種類 | 結果 | freed_mb | Notes |
|------|------|------|----------|-------|
| 1 | worktree prune | 0 candidates | 0 | startup hook dry-run 確認 (= 26 worktree 全 SKIP) |
| 2 | git gc --aggressive | 143s 完了 | 計測不能 | .git pack 再圧縮 / measurable C: delta 不在 |
| 3 | npm cache clean | 0 freed | 0 | cache 既空 |
| 4 | pnpm store prune | 0 freed | 0 | 2389 MB store 不変 |
| 5 | plugin cache prune | 0 freed | 0 | 7.4 MB only / 既 trim 済 |
| 6 | dev_cache_cleanup --apply | 352.5 MB script reported | 427.6 MB measured | **pub_command 296.8 MB 主貢献** / 1 task failed |

**Aggregate**:
- script 報告 reclaim: 352.5 MB
- drive 計測 reclaim: 427.6 MB (= dev_cache 単独)
- session 全体 net delta: **+41 MB only** (= dev_cache 386 MB 分が 10min 内 system burndown で吸収)

## v22 Layer II FATIGUE 第 2 例実証

| 観点 | 部 211-b 第 1 例 | 部 212 第 2 例 |
|------|------------------|----------------|
| Trigger | 6.5h idle gap 後 | EMERGENCY recovery directive |
| Fire 試行 | 3x consecutive < 100 MB | 5x Tier 2 (pub cache のみ ≥ 100 MB) |
| 結果 | -10 MB cumulative | +41 MB net (dev_cache 386 MB 吸収) |
| Cascade script | 不在 | 不在 (= v18 Layer K 5/22 sprint 待ち) |
| Target met | ❌ (= v22 Layer II 条件 met) | ❌ (= 第 2 例 累積 / pattern 強化) |

→ **2 sessions 連続で同じ pattern (= cascade fire 必要性) を実証**.
→ **v18 Layer K disk_hygiene_cascade.ps1 を Codex 5/22 sprint で 最優先 implement 推奨**.

## Codex 緊急 ask (= 5/22 sprint kickoff まで)

### 最優先 (= P0 / 5/22 sprint 第 1 候補)

**v18 Layer K**: `~/.claude/hooks/disk_hygiene_cascade.ps1` 実装

```powershell
# 想定設計:
# 1. Trigger: PostToolUse hook で c_free < 26 GB OR reclaim < 100 MB 検出
# 2. Cascade: Tier 1 (temp/recycle) → Tier 2 (dev_cache --apply) → Tier 3 (git gc + flutter clean) 順次 fire
# 3. KPI snapshot: 各 tier の per-fire reclaim を session-delta.csv に append
# 4. Cap: 1 session 3 fire 上限 (= v22 Layer II FATIGUE detection で stop)
# 5. Fail-closed: target c_free ≥ 28 GB met or 3 fire exhausted で exit
```

### P0 / 5/22 sprint 第 2 候補

**v22 Layer EE**: session-delta.csv schema 拡張

```sql
-- 追加 column:
-- fire_id        TEXT    (= 'manual_part212_emergency' 等)
-- ram_pct        FLOAT   (= POST snapshot RAM%)
-- delta_disk_mb  INT     (= measured drive delta)
-- delta_ram_pt   FLOAT   (= POST - PRE RAM)
-- pre_c_free_gb  FLOAT   (= compress_pre row への back-ref / paired-row 識別用)
```

### P0 / 5/22 sprint 第 3 候補

**v22 Layer II**: `scripts/compression_fatigue_monitor.py`

```python
# 想定設計:
# 1. Read 直近 3 fires from session-delta.csv (= per fire_id)
# 2. If all 3 fires reclaim < 500 MB (= FATIGUE threshold) AND ram delta < -2 pt
#    → emit 'cascade_required' signal to disk_hygiene_cascade.ps1
# 3. Daily GHA cron で fatigue 検出 + Slack/Discord notify
```

## 7d C: delta -32.74 GB signal 累積記録

| 検出 | session | C: delta over 7d | 評価 |
|------|---------|-------------------|------|
| 第 1 検出 | 部 206 (5/12 23:39) | -30.96 GB | threshold -3 GB の 10x breach |
| 第 1 実現 | 部 211-b (5/13 17:05) | -32.88 GB session 内 | 6.5h で実現 = signal 強化 |
| 部 212 baseline | 部 212 (5/13 21:08) | 17.71 → 25.32 (+7.61) | 自然 recovery + Tier 2 後も -7.4 GB 短期 trend は反転せず |

→ **7d signal pattern は固定** = cascade auto-fire 不在の限界.

## バッヂ更新 ([SYNERGY-30] / [INDIE-29])

- **2-instance hand-off 第 9 例累積** (= v13-v22 全 7 例 + 部 212 第 2 例 reinforce + 第 1 例 = 9)
- **既存 doc 章追加 第 21 例累積** (= DISK_HYGIENE §17.26 v22 第 2 例 reinforce 追加 候補 / 部 212 で write)
- **iterative ask v22 完了 / v23 候補 4 件** (= per part 212 spec)

## 担当 + 期限

- **Codex**: v18 Layer K + v22 Layer EE schema + v22 Layer II 3 件 / 5/22 sprint kickoff から 8 day = 5/30 期限
- **Win Claude**: bridge mitigation 継続 (= 各 session manual disk-cleanup invoke / part 213-220 9 session)

cc: @kanta13jp1 (= 5/22 sprint kickoff GO/NO-GO 判断)
