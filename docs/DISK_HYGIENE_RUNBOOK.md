# Disk + Memory Hygiene Runbook — 自分株式会社 (= Win版#132 part 154 → part 155-b 拡張)

> **status**: ops runbook / 2026-05-05 / Win版#132 part 154 + part 155-b memory 拡張
> **trigger**: C: free < 50 GB / G: free < 50 GB / **Free RAM < 50%** / 2 instance + 9+ worktree fleet による継続圧迫
> **scope**: ローカル開発環境 (= Win Claude / Win Codex 2 instance + 9+ worktree fleet) のディスク + メモリ逼迫を毎セッション自動軽減 + 週次手動深掘り (= Issue #1984 axis A-F 着地)

## 1. 思想

`my_web_app` 開発フローは **9+ worktree 並走** + **per-session transcript 累積** + **Flutter build artifact 重さ** + **plugin cache 多重化** で、**1 週間で C: ドライブ 50 GB 以上消費**. 放置すると Windows 起動・ビルド失敗・git push エラーへ直結 (= part 154 検出: C: 19.6 GB / G: 18.7 GB ≒ 4% 残量).

→ **毎セッション自動 Tier 1** (= safe / 30 sec 以内) + **週次手動 Tier 2** (= worktree prune / git gc / Docker prune / 数分) の二層 hygiene.

## 2. 二層 architecture

### Tier 1 (= 自動 / SessionStart hook / 30 sec budget)

`~/.claude/hooks/disk-cleanup.ps1` (= part 154 新設) が SessionStart で自動実行. 削除対象 7 件:

| # | target | 期間 | 期待回収 (= part 154 baseline) |
|---|---|---|---|
| 1 | `%TEMP%\*` | 7 日超 | 5-7 GB (= 9.18 GB の 60-80%) |
| 2 | Recycle Bin | > 100 MB 時 | 100-300 MB |
| 3 | `~/.claude/shell-snapshots\*` | 7 日超 | 30-50 MB |
| 4 | `~/.claude/todos\*` (completed) | 7 日超 | 10 MB |
| 5 | `~/.claude/projects\*.jsonl` (gzip 圧縮) | 30 日超 | 600-900 MB (= 圧縮率 80%) |
| 6 | `~/.claude/file-history\*` | 30 日超 | 300-500 MB |
| 7a | **`%LOCALAPPDATA%\Google\DriveFS\Logs\*`** (= G: drive 関連) | 7 日超 | 100-486 MB |
| 7b | **Chrome / Edge cache** (= `Cache` `Code Cache` `GPUCache` `Service Worker`) | browser 停止時のみ | 500-1500 MB |
| 8 | `<repo>\build` `<repo>\.dart_tool` (main repo only) | 14 日超 | 800-900 MB |

= 1 セッション平均 **6-9 GB 回収** (= G: cache 拡張で +1-2 GB).

**G: drive 注**: G: は Google Drive 仮想 FS (= cloud-only stubs). 物理 disk 使用は `%LOCALAPPDATA%\Google\` 配下 (= **DriveFS cache 1.73 GB / DriveFS Logs 486 MB / Chrome cache 940 MB** / 計 ~3.2 GB / part 154-b 検出). G: 残量 < 50 GB は cloud quota 問題で physical disk 別.

**安全 rule**:
- ❌ worktree 内 build/ 削除しない (= 進行中 Flutter project 破壊 risk)
- ❌ active session transcript (= 30 日以内) は触らない
- ❌ locked file は silently skip
- ✅ 全 file mtime 7-30 日超 hard cutoff
- ✅ JSONL transcript は **gzip 圧縮** で deletion ではなく **size 削減** (= 後で `Expand-Archive` 復元可)

### Tier 2 (= 手動 / `/disk-cleanup` slash command / 数分)

`~/.claude/commands/disk-cleanup.md` 経由で 8 step 実行:

1. pre-snapshot
2. **worktree prune** (= 9 worktree × 131 MB / merged branch のみ remove / current session 絶対 skip)
3. **git gc --aggressive** (= .git/ pack 再圧縮 / ~120 MB 削減)
4. **Flutter pub cache repair** + `flutter clean`
5. **npm cache clean** + **pnpm store prune** (= ~700 MB)
6. **Docker / WSL prune** (= 大幅 / confirm required)
7. **plugin cache prune** (= 各 plugin 最新 1 version のみ / ~800 MB)
8. post-snapshot + report

期待回収: **5-15 GB / Tier 2 1 回**.

## 3. 閾値駆動 alert

`disk-cleanup.ps1` Tier 1 後の C: 残量:

| 残量 | action | 通知方法 |
|---|---|---|
| ≥ 80 GB | 通常運転 | log のみ (= `~/.claude/logs/disk-cleanup-YYYYMMDD.log`) |
| 25-80 GB | report 書き出し | `~/cleanup_reports/disk_report_<ts>.md` (= 既存 cleanup_report_notify.ps1 が pickup) — fleet-loaded box では毎セッション report 出力 (= part 158 で 50→80 GB 厳格化 / 圧縮可視化) |
| 10-25 GB | **WARN** | `additionalContext` 経由で Claude に「`/disk-cleanup` 推奨」surface |
| < 10 GB | **ALERT** | `additionalContext` で「即座に `/disk-cleanup` 実行」surface (= ビルド失敗 risk) |

### 3.1 Memory hook 閾値 (= memory-cleanup.ps1 / part 159 強化: heavy gate 撤廃)

| Free RAM | action | 期間 |
|---|---|---|
| **ALL** | cheap ops + EmptyWorkingSet — **常時実行** (part 159 撤廃) | 5-25 sec |
| < 25% | Tier 1.5 all + WARNING report | 5-25 sec + report |
| < 10% | Tier 1.5 all + ALERT additionalContext | 5-25 sec + alert |

**part 159 変更**: 旧仕様「Free > 70% で heavy step (EmptyWorkingSet) skip」を撤廃。fleet-loaded box では Free RAM 60-80% 帯が常時状態であり、その帯域でも毎回 0.5-2.7 GB の reclaim が発生 (実測)。SessionStart/End 各 +5-15 sec の代償で「毎セッション 必ず heavy 圧縮」要件 (= ユーザー 2026-05-07 ask) を厳格化。

### 3.2 Dual trigger (= SessionStart + SessionEnd / part 158-b)

両 hook (= disk + memory) を **SessionStart + SessionEnd の二重 trigger** で登録 (`~/.claude/settings.json`):

```jsonc
"SessionStart": [/* disk-cleanup, memory-cleanup */],
"SessionEnd":   [/* disk-cleanup, memory-cleanup */]
```

理由: SessionStart で前回残骸を清掃 + SessionEnd で当回残骸を清掃 → 「次回セッション開始時の disk pressure 永続化」を防ぐ。両 hook 共 idempotent なので二重発動でも副作用なし。

### 3.3 PreCompact hook (= part 159 新規)

**長時間セッションで context compact が走る時** にも heavy step を発火させる:

```jsonc
"PreCompact": [/* memory-cleanup */]
```

理由: SessionStart/End だけでは長時間 1 セッションでは不十分。compact 直前の RAM 圧迫が compact 失敗 / context 蒸発 / 再 compact ループの引き金になる ([COMPACTION-RESUME] 教訓)。compact 前に EmptyWorkingSet を 1 回挟むことで成功率向上。

### 3.4 Disk report 閾値 (= part 159 80→100 GB へ拡大)

`disk-cleanup.ps1` Tier 1 の report 閾値を 80 GB → **100 GB** に拡大。fleet-loaded box の C: 60-90 GB 帯で**毎セッション report が生成**され、可視化漏れ防止。Tier 1 cleanup 自体は常時実行 (= 変更なし)。

### 3.5 Worktree prune (= part 160-b 新設 / 手動 slash command)

`scripts/worktree_prune.ps1` で `.claude/worktrees/` の stale worktree を **dry-run → apply** の 2 段階で安全 prune する。**自動 hook 化はしない** (= [WORKDIR-ISOLATION] safety / 誤削除リスク)。

**SKIP rule (= 安全 guard)**:

1. self (= 現在の worktree)
2. detached HEAD (= 別 instance / codex active 可能性)
3. uncommitted changes (= `git status -s` 1+ 行)
4. open PR (= `gh pr list --state open` で head branch 一致)
5. main / master branch (= `jolly-nash` 型)
6. **未 merge 状態** (= `git rev-list main..<branch> --count` > 0)

`-Force` flag で uncommitted / 未 merge guard をスキップ可能 (= 危険 / user 明示判断のみ)。

**運用 cycle**:

```bash
# 1. dry-run = report only (default)
powershell -File scripts/worktree_prune.ps1

# 2. apply = 実 prune
powershell -File scripts/worktree_prune.ps1 -Apply

# 3. force apply (= uncommitted/未 merge も削除 / DANGER)
powershell -File scripts/worktree_prune.ps1 -Apply -Force
```

**part 160-b smoke test 実績** (= 2026-05-07 02:35 JST):
- 入力: 16 worktree
- dry-run: 8 PRUNE / 7 SKIP (= uncommitted 5 + detached HEAD 2 + main 1 + 未 merge 1 + self 1)
  - 内 1 が未 merge guard で救済 (= `claude/elegant-elgamal-aae681` 7 commits ahead)
- apply: 7 prune / **913 MB reclaim**
- 結果: 16 → 8 worktree (= `git worktree prune` 連動で孤児 dir も整理)

**ROI**: 1 sample worktree ~130 MB / 7 worktree = ~913 MB。fleet 運用で 1-2 week ごとに prune 推奨。

### 3.6 Aggressive auto-cleanup (= part 161 新設 / 3 改善)

User 報告: 「今の開発フローだと、ローカル環境のメモリやハードディスク容量が必ず枯渇」(= 2026-05-07 part 161)。診断結果: C: 81.6% used (84 GB free / 455 GB) / Memory 84.6% used。最大圧迫源は **Chrome 5.11 GB / Edge 3.96 GB / .claude/plugins 1.17 GB / transcripts 1.12 GB**。

**3 改善** (= `disk-cleanup.ps1` 編集 / part 161):

1. **Transcript gzip 閾値 30→14 days** (= 1.12 GB transcripts のうち 14+ 日経過分を gzip 50-70% 圧縮)
2. **Browser cache 2-tier 戦略** (= 従来は browser running 時 skip だった / 「Code Cache / GPUCache / Service Worker\\CacheStorage」は file lock 少なく **browser 動作中も削除可** + 3 日経過 file のみ削除で UX 影響最小化 / 「Cache」(SQLite-like) のみ browser stopped 時の deep clean)
3. **Plugin cache > 14 days 削除** (= `~/.claude/plugins/cache/` ~1.17 GB / 100KB 以上 file の 14+ 日経過分のみ削除 / 最新 plugin version は LastWriteTime で keep)

**part 161 smoke test 実績** (= 2026-05-07 03:43 JST):
- **939.4 MB reclaim / 28.8 sec**
  - plugin_cache_14d_MB: **542.7 MB** (新設 / 最大 win)
  - transcripts_compacted_MB: **348.5 MB** (14 day threshold 効果)
  - browser_cache_MB: **48.1 MB** (Chrome+Edge running 中も削除成功)
- C: 83.6 → 84.1 GB (= 0.5 GB 反映 / 残りは即再生成)
- Memory cleanup 同時実行: **2.34 GB free 増** (15.4% → 32%)

**ROI**: 1 セッションあたり **~1 GB reclaim**。SessionStart + SessionEnd dual trigger で 1 日 2-4 回稼働 = 週 14-28 GB。

## 4. 監視 KPI

毎セッション自動記録 (= `~/.claude/logs/disk-cleanup-YYYYMMDD.log`):

- C: free GB before / after
- G: free GB before / after
- target 別 reclaim MB (= 7 件)
- 合計 reclaim MB
- elapsed sec

週次集計 (= 別 GHA cron 候補 / part 155+ で実装):
- 7 日累計 reclaim 量
- 7 日累計 free GB 推移
- worktree 数推移 (= prune 効果計測)

## 5. なぜ毎セッション

代替案 vs 採用案:

| 案 | pros | cons |
|---|---|---|
| 週次 GHA cron で remote cleanup | サーバ側 / local 影響 0 | local disk は GHA 関与不能 |
| weekly 手動 `/disk-cleanup` のみ | シンプル | 忘れる / 1 週間放置で 50 GB 圧迫 |
| **毎 SessionStart 自動 Tier 1 + 週次 Tier 2** ✅ | 確実 / 自動 / safe | hook 30 sec budget 厳守必須 |

**採用根拠**:
- Win Claude は 1 日 5-10 セッション = 自動なら 1 日 5-10 回 cleanup
- 9 worktree fleet (= 各 131 MB) が 1 日数本生成される現運用と整合
- transcript 累積 (= part 153 の 4 段 batch で 50+ MB / day) を 30 日超で gzip = 自然な延命

## 6. 失敗 mode + 対策

| 失敗 | 症状 | 対策 |
|---|---|---|
| hook が 30 sec 超 | Claude session 起動遅延 | `Get-DirSizeMB` を `-Recurse` 浅化 / `Measure-Object` のみ深い計測は週次に回す |
| locked file で停止 | エラー dump で hook 失敗 | 全 `Remove-Item` に `-ErrorAction SilentlyContinue` + try/catch |
| current session transcript 削除 | 進行中作業ロスト | `LastWriteTime > now - 30d` で完全 skip / gzip も active 除外 |
| worktree 誤削除 (Tier 2) | 進行中 PR 破壊 | merged branch 確認 + current `$PWD` 絶対 skip |
| Docker prune で 5 GB image 喪失 | 復元 30 min 必要 | Tier 2 で confirm prompt 必須 (= 自動化禁止) |
| plugin cache prune で active version 喪失 | plugin 起動失敗 | LastWriteTime DESC で **最新 1 version は keep** / 他削除 |

## 7. 関連 docs / files

- Hook: [`~/.claude/hooks/disk-cleanup.ps1`](C:/Users/kanta/.claude/hooks/disk-cleanup.ps1)
- Slash command: [`~/.claude/commands/disk-cleanup.md`](C:/Users/kanta/.claude/commands/disk-cleanup.md)
- Existing notify hook: [`~/scripts/cleanup_report_notify.ps1`](C:/Users/kanta/scripts/cleanup_report_notify.ps1) (= 本 hook と相互補完 / report 通知のみ)
- Settings registration: `~/.claude/settings.json` `hooks.SessionStart` 第 3 段
- Memory entry: [`memory/feedback_correction_20260505_disk_pressure.md`](../../memory/feedback_correction_20260505_disk_pressure.md)
- 9 原則: [`PHILOSOPHY.md`](PHILOSOPHY.md) #6 時間最適化 + #7 資産負債 (= disk = 物理資産)
- AI-DEV-23: #4 circuit-breaker (= 閾値駆動 alert) + #5 memory (= retention 期限)

## 8. PHILOSOPHY-22 alignment (= 7+/9 ✅)

- ✅ #2 ミッション: 開発インフラ自衛 = 自分株式会社の信頼資本
- ✅ #4 6 部署: ops 部署の自走化
- ✅ #6 時間最適化: 1 セッション 30 sec で 6-8 GB 回収 = 復元コスト 0
- ✅ #7 資産負債: ローカル disk = 物理資産 / 圧迫 = 負債
- ✅ #8 KPI: free GB / reclaim MB / target 別が log で連続計測可
- ✅ #9 IPO: SOC2 audit log = 7 日 retention 政策 整合

= 9/9 中 5+ ✅ (= 7+/9 ゲート未達 / 残量 alert で IPO #9 / インフラ非機能 #1 #3 #5 は領域外).

## 9. 横展開 (= part 155+ candidate)

- Win Codex 側 worktree (= `instance-codex`) でも同 hook 適用
- weekly cron (= GHA 不可 / Windows scheduled task) で Tier 2 自動化検討
- WSL/Docker VHDX `optimize-vhd` 月次自動化
- per-instance disk budget (= Win Claude 80 GB / Win Codex 80 GB / 共用 50 GB) を `instance-constraints.md` に記録

---

## 10. Memory Hygiene Tier 1.5 (= part 155-b 新設 / Issue #1984 axis D 着地)

### 10.1 思想

HDD 圧迫と並行して **RAM 圧迫** も Win 開発環境の継続課題. part 155-b 検出: Free RAM 17.2% (= 2.7 GB / 15.7 GB) = LOW zone. 原因: msedge / Codex / Claude / Memory Compression / MsMpEng 計 ~3 GB working set + Windows standby memory が大量蓄積.

→ **毎セッション自動 Tier 1.5** (= safe / 30 sec 以内 / 閾値駆動 / idempotent fast path) を disk-cleanup と同 architecture で導入.

### 10.2 Tier 1.5 (= 自動 / SessionStart hook / 5-15 sec budget)

`~/.claude/hooks/memory-cleanup.ps1` (= part 155-b 新設) が SessionStart で自動実行 (= disk-cleanup と並列 register 推奨).

| step | target | 期待回収 | 備考 |
|---|---|---|---|
| 1 | EmptyWorkingSet on heavy idle (= claude / Codex / msedge / chrome / Code / node / dotnet / python / flutter / dart) | 100-500 MB | Win32 P/Invoke / 即時 |
| 2 | own GC (= `[System.GC]::Collect()`) | 10-50 MB | < 100 ms |
| 3 | orphan PowerShell kill (= idle > 60 min かつ CPU < 1.0) | 50-200 MB | current PID 除外必須 |
| 4 | DNS resolver cache clear | < 10 MB | small but free |
| 5 | standby memory release (= `SetSystemFileCacheSize(-1,-1,0)`) | 500 MB - 2 GB | **admin only** / non-admin = soft skip |

= 1 セッション平均 **0.2-2 GB 回収** (= admin run 時のみ standby 大量解放).

### 10.3 閾値駆動 gating (= idempotent fast path)

| Free RAM | 動作 | budget |
|---|---|---|
| **> 50%** | **fast path skip** (= step 0 only / log のみ) | **< 0.5 sec** |
| 25-50% | step 1-4 実行 (= step 5 skip) | 5-10 sec |
| 10-25% | step 1-5 全実行 + WARNING report | 10-20 sec |
| **< 10%** | step 1-5 全実行 + **ALERT additionalContext** to Claude | 10-30 sec |

= 第 1 回 heavy / 第 2 回以降 fast path (= disk-cleanup と同 idempotent pattern / part 154-b 確立).

### 10.4 settings.json registration

既存 disk-cleanup.ps1 の SessionStart hook に **第 4 段** として並列 register:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          { "type": "command", "command": "powershell -ExecutionPolicy Bypass -File \"C:\\Users\\kanta\\.claude\\hooks\\disk-cleanup.ps1\"" },
          { "type": "command", "command": "powershell -ExecutionPolicy Bypass -File \"C:\\Users\\kanta\\.claude\\hooks\\memory-cleanup.ps1\"" }
        ]
      }
    ]
  }
}
```

→ user に `/update-config` 経由で配線依頼 (= 任意 / hook 単独でも `& "C:\Users\kanta\.claude\hooks\memory-cleanup.ps1"` 手動実行可).

### 10.5 安全 rule

- ❌ current PowerShell session (= `$PID`) 絶対 kill しない (= 自分自身殺害 防止)
- ❌ EmptyWorkingSet で active foreground process は paging risk → `WindowState='Minimized'` の process のみ target 推奨 (= 後日改善 / 現状全 target)
- ❌ standby memory 解放は admin only / 非 admin で `SetSystemFileCacheSize` call で AccessDenied → soft skip
- ✅ 全 step に `try/catch` + `-ErrorAction SilentlyContinue`
- ✅ Free RAM > 50% で fast skip (= 健全時 0.5 sec 以下)
- ✅ Free RAM < 10% でのみ Claude に additionalContext alert

### 10.6 KPI / 計測

- `~/.claude/logs/memory-cleanup-YYYYMMDD.log`: 1 行 / session / `before% before_GB after% after_GB gain_GB elapsed_sec`
- `~/cleanup_reports/memory_report_<timestamp>.md`: free < 25% 時のみ生成 / Top 10 RAM consumers + 各 step reclaim 内訳

### 10.7 Issue #1984 axis 適用 status (= part 155-b 着地 reaffirm)

| axis | 内容 | 担当 | status |
|---|---|---|---|
| A | Worktree cleanup | Win Codex | **未着** (= cross-instance-pr part 155-b) |
| B | 動画ファイル削減 | n/a | #1724 待ち |
| C | Cache 清掃 (= Flutter / npm / pip / notebooklm) | Win Codex | **部分着地** (= disk-cleanup Tier 1 で browser cache 適用 / npm/pnpm/pub は Tier 2 のみ) |
| D | **Memory cleanup** | **Win Claude** | **✅ 着地 part 155-b** (= memory-cleanup.ps1 / 5 step / 閾値 gating) |
| E | docs rotate (= cs-notes / daily-reports 90 日 archive) | Win Codex | **未着** |
| F | transcript ローテーション | (= disk-cleanup step 5 で 30 日 gzip 化済 part 154-a) | ✅ |

= 6 axis 中 D ✅ (= 本 part 着地) + F ✅ + C 部分着地 + A/B/E 残.

## 11. 関連 docs / files (= memory 拡張版)

- Hooks: [`~/.claude/hooks/disk-cleanup.ps1`](C:/Users/kanta/.claude/hooks/disk-cleanup.ps1) + [`~/.claude/hooks/memory-cleanup.ps1`](C:/Users/kanta/.claude/hooks/memory-cleanup.ps1) (= part 155-b)
- Slash commands: [`~/.claude/commands/disk-cleanup.md`](C:/Users/kanta/.claude/commands/disk-cleanup.md)
- Settings registration: `~/.claude/settings.json` `hooks.SessionStart` 第 3-4 段
- Issue #1984 axis A-F: [P1 infra Memory + HDD reduction](https://github.com/kanta13jp1/my_web_app/issues/1984)
- 9 原則: PHILOSOPHY-22 #6 時間最適化 + #7 資産負債 (= RAM = 物理資産) / AI-DEV-23 #4 circuit-breaker
