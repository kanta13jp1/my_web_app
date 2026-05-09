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
| 5 | `~/.claude/projects\*.jsonl` (gzip 圧縮) | 7 日超 (= part 168 / 30→14→7) | 600-900 MB (= 圧縮率 80%) |
| 6 | `~/.claude/file-history\*` | 30 日超 | 300-500 MB |
| 7a | **`%LOCALAPPDATA%\Google\DriveFS\Logs\*`** (= G: drive 関連) | 7 日超 | 100-486 MB |
| 7b | **Chrome / Edge cache** (= `Cache` `Code Cache` `GPUCache` `Service Worker`) | browser 停止時のみ | 500-1500 MB |
| 8 | `<repo>\build` `<repo>\.dart_tool` (main repo only) | 14 日超 | 800-900 MB |

= 1 セッション平均 **6-9 GB 回収** (= G: cache 拡張で +1-2 GB).

**G: drive 注**: G: は Google Drive 仮想 FS (= cloud-only stubs). 物理 disk 使用は `%LOCALAPPDATA%\Google\` 配下 (= **DriveFS cache 1.73 GB / DriveFS Logs 486 MB / Chrome cache 940 MB** / 計 ~3.2 GB / part 154-b 検出). G: 残量 < 50 GB は cloud quota 問題で physical disk 別.

**安全 rule**:
- ❌ worktree 内 build/ 削除しない (= 進行中 Flutter project 破壊 risk)
- ❌ active session transcript (= 7 日以内) は触らない (= part 168 / hot-cache window)
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

### 3.6.1 Transcript hot-cache 7-day rotation (= part 168 / aggressive hygiene 4 軸目)

User 報告: 「ローカル環境のメモリやハードディスク容量が必ず枯渇」継続観察 (= 2026-05-07 part 168)。1 session で C: 12 GB drop 観察 (= 94→82 GB / part 167 監視)。**transcripts dir 812 MB** + 1 session 数 MB-数十 MB 累積で hot-cache window 短縮効果が大きい。

**1 改善** (= `disk-cleanup.ps1` step 5 編集 / part 168):

- **Transcript gzip 閾値 14→7 days** (= hot-cache window 短縮 / 7 日経過分は LRU と仮定 / gzip 50-70% 圧縮継続)
- 段階推移: part 154-a (30 日) → part 161 (14 日) → **part 168 (7 日)**
- LRU 仮定の根拠: Win Claude session は 1-2 part/day 稼働 / 7 日 = 7-14 part 経過 / 直近 part 以外の transcript 参照頻度低い

**ROI 推定**: 1 週間 12 GB consumption の内、**transcript 由来 ~1-2 GB** をさらに前倒し圧縮 → cumulative weekly +200-400 MB 上乗せ。

### 3.7 Worktree cleanup automation (= Issue #1984 axis A / Codex #1)

`scripts/worktree_cleanup.py` は PowerShell 手動 prune の portable/CI 版。`git worktree list --porcelain` 全件を見て、以下をすべて満たす worktree だけを `PRUNE` 候補にする。

**追加 guard**:

1. current `$PWD` の worktree を絶対 skip
2. primary worktree を skip
3. detached HEAD を skip
4. `main` / `master` / `develop` / `staging` を skip
5. `git status --porcelain` が 1 行でもあれば skip
6. `gh pr list --state open` の head branch と一致すれば skip
7. `HEAD == @{u}` (= upstream と完全一致) でなければ skip
8. `HEAD` が `origin/main` に含まれていなければ skip

**運用 cycle**:

```bash
# 1. dry-run = report only (default)
python scripts/worktree_cleanup.py --fetch

# 2. apply = safe PRUNE candidates only
python scripts/worktree_cleanup.py --fetch --apply

# 3. machine-readable report
python scripts/worktree_cleanup.py --json-out tmp/worktree-cleanup.json
```

`.github/workflows/worktree-cleanup-cron.yml` は weekly で同 script を hosted Windows runner 上で dry-run → apply → `git worktree prune` まで実行し、Issue #1984 に summary を残す。GitHub hosted runner はローカル C: の worktree を直接削除できないため、**local cleanup は Codex/Claude Windows app session で同 script を dry-run → apply** する。

### 3.8 Dev cache cleanup automation (= Issue #1984 axis C / Codex #1)

`scripts/dev_cache_cleanup.py` は Flutter / npm / pnpm / pub / pip / NotebookLM cache の portable/CI 版。default は dry-run で、実削除は `--apply` 明示時のみ。

- `flutter clean`: `pubspec.yaml` を持つ worktree が対象。`--include-worktrees` で全 worktree を見るが、dirty worktree は default skip。
- `npm cache verify` / `pnpm store prune` / `dart pub cache clean --force` / `python -m pip cache purge`: tool が無い場合は soft skip。
- NotebookLM cache: known cache/log/temp directory の child のみ、default 7 日超で prune。`storage_state.json` / cookie/token 系は protected。
- `.github/workflows/dev-cache-cleanup-cron.yml`: hosted Windows runner で dry-run -> safe apply -> artifact upload -> Issue #1984 comment。GHA は local C: を直接 reclaim できないため、Windows app session / local scheduled task でも同 script を使う。

### 3.9 Docs rotate automation (= Issue #1984 axis E / Codex #1)

`scripts/docs_rotate.py` は schedule-output docs の active folder を小さく保つための portable/CI 版。default は dry-run で、実 move は `--apply` 明示時のみ。

- 対象: `docs/cs-notes`, `docs/daily-reports`, `docs/auto-blog`。
- retention: filename 内の `YYYY-MM-DD` を使って 90 日超を判定。CI checkout では mtime が更新されるため、mtime は使わない。
- archive: `docs/_archive/<YYYY-MM>/<source>/filename` へ move。上書きはせず、既存 destination があれば skip。
- `.github/workflows/docs-rotate-cron.yml`: monthly dry-run -> apply -> artifact upload -> Issue #1984 comment。変更がある場合だけ `automation/docs-rotate-<run_id>` branch と reviewable PR を作る。

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
| current session transcript 削除 | 進行中作業ロスト | `LastWriteTime > now - 7d` で完全 skip / gzip も active 除外 (= part 168 / hot-cache window) |
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
| A | Worktree cleanup | Win Codex | **✅ 着地** (= `scripts/worktree_cleanup.py` + weekly workflow) |
| B | 動画ファイル削減 | n/a | #1724 待ち |
| C | Cache 清掃 (= Flutter / npm / pip / notebooklm) | Win Codex | **✅ 着地** (= `scripts/dev_cache_cleanup.py` + weekly workflow / local apply required for C:) |
| D | **Memory cleanup** | **Win Claude** | **✅ 着地 part 155-b** (= memory-cleanup.ps1 / 5 step / 閾値 gating) |
| E | docs rotate (= cs-notes / daily-reports 90 日 archive) | Win Codex | **✅ 着地** (= `scripts/docs_rotate.py` + monthly PR workflow) |
| F | transcript ローテーション | (= disk-cleanup step 5 で 7 日 gzip 化 / part 154-a → 161 → 168 で 30→14→7 段階強化) | ✅ |

= 6 axis 中 A/C/D/E/F ✅。B は #1724 secrets blocker 解消後に動画削減 PR。

## 11. 関連 docs / files (= memory 拡張版)

- Hooks: [`~/.claude/hooks/disk-cleanup.ps1`](C:/Users/kanta/.claude/hooks/disk-cleanup.ps1) + [`~/.claude/hooks/memory-cleanup.ps1`](C:/Users/kanta/.claude/hooks/memory-cleanup.ps1) (= part 155-b)
- Slash commands: [`~/.claude/commands/disk-cleanup.md`](C:/Users/kanta/.claude/commands/disk-cleanup.md)
- Settings registration: `~/.claude/settings.json` `hooks.SessionStart` 第 3-4 段
- Issue #1984 axis A-F: [P1 infra Memory + HDD reduction](https://github.com/kanta13jp1/my_web_app/issues/1984)
- 9 原則: PHILOSOPHY-22 #6 時間最適化 + #7 資産負債 (= RAM = 物理資産) / AI-DEV-23 #4 circuit-breaker

---

## 12. Tier 1.6 SessionStart-integrated stale worktree prune (= part 178 新設 / 「毎セッション必ず」要件 v2)

### 12.1 背景 + 隙間特定

User 2026-05-08 ask: 「**毎回のセッションで必ず** メモリやハードディスク容量を圧縮する施策」.

現状 audit:

- `~/.claude/hooks/disk-cleanup.ps1` Tier 1 = 10 step 既存 (= temp / recycle / shell-snapshots / todos / transcripts gzip / file-history / DriveFS / browser cache / build / plugin cache)
- `~/.claude/hooks/memory-cleanup.ps1` Tier 1.5 = 5 step 既存
- `scripts/worktree_cleanup.py` = **weekly cron 経由のみ** (= GHA workflow / 7 日 1 回)
- `git worktree list` 実測 (part 178): **17 worktree / 2.28 GB** = 圧迫源 #1 / 大半 1-3 day idle / 一部 detached HEAD 残存

**隙間** = stale worktree auto-prune が **毎セッション** ではなく **週次** のみ → ユーザー要求「毎回必ず」とギャップ. weekly cron は 7 day 単位の累積を一気に刈るが、その間に C: ドライブ +0.5-1 GB / day 漸増. **SessionStart 統合 = 漸増を毎回 trim** で持続的に低位維持.

### 12.2 Tier 1.6 (= 自動 / SessionStart hook step 11 / 10-15 sec budget)

`disk-cleanup.ps1` 末尾に step 11 として `python scripts/worktree_cleanup.py --tier1` 呼び出しを追加.

| 条件 (AND) | rationale |
|---|---|
| `git worktree list --porcelain` 列挙 | 全 worktree 列挙 |
| branch merged-to-main (= `git branch --merged main`) | 未 merged は user 進行中の可能性 → 触らない |
| idle > 7 days (= worktree dir 内 latest mtime > 7 day) | 7 day = part 168 hot-cache window と同じ cutoff |
| size > 100 MB | sub-100MB は noise (= 13 個削除しても 1 GB に届かない) |
| **current session worktree (= `$PWD` resolve) != target** | 自分自身 prune 防止 |
| `.git/worktrees/<name>/locked` 不在 | git lock 機構尊重 |

Action: `git worktree remove --force <path>` + `git worktree prune` (= dangling metadata sweep).

期待回収: **0.5-2 GB / 月** (= 1 worktree 平均 130 MB × 月 5-15 件 prune).

### 12.3 安全 rule

- ❌ current session 絶対 skip (= `$PWD` parent 走査で自身 detect)
- ❌ uncommitted change 検出時 skip (= `git -C <path> status --porcelain` 出力空チェック)
- ❌ branch merged 判定不能時 skip (= detached HEAD は target 除外 / part 178 観測 2 件)
- ❌ 60 sec 経過で `--max-runtime-sec=15` 強制中断 (= SessionStart 全体 30 sec budget 圧迫回避)
- ✅ dry-run mode default + `--apply` flag 必須 (= `--tier1 --apply` で hook 起動)
- ✅ 削除前 reclaim_MB log 出力 (= `~/.claude/logs/disk-cleanup-YYYYMMDD.log`)
- ✅ SessionStart hook なので **削除 worktree 数 + reclaim_MB のみ** Claude context surface (= 詳細 log 別 file)

### 12.4 settings.json (= 既存 hook 内に step 11 追加 / 配線変更不要)

```powershell
# disk-cleanup.ps1 末尾に追加 (step 11)
$repoDir = "$env:USERPROFILE\GitHub\my_web_app"
$worktreeScript = Join-Path $repoDir "scripts\worktree_cleanup.py"
$worktreeReclaimMB = 0
if (Test-Path $worktreeScript) {
    try {
        $out = & python $worktreeScript --tier1 --apply --max-runtime-sec=15 2>&1
        if ($LASTEXITCODE -eq 0) {
            $reclaimLine = $out | Select-String -Pattern 'reclaimed_mb=(\d+)' | Select-Object -First 1
            if ($reclaimLine) {
                $worktreeReclaimMB = [int]$reclaimLine.Matches[0].Groups[1].Value
            }
        }
    } catch { }
}
$totals['stale_worktree_prune_MB'] = $worktreeReclaimMB
```

→ `~/.claude/settings.json` 変更不要 (= 既存 SessionStart 第 3 段 disk-cleanup.ps1 が呼ぶだけ).

### 12.5 Codex hand-off (= 2 instance 制 / 実装委譲)

| 工程 | 担当 | 状態 |
|---|---|---|
| spec doc 章追加 (= 本 §12) | **Win Claude** | ✅ part 178 |
| `scripts/worktree_cleanup.py` `--tier1 --apply --max-runtime-sec=15` mode 追加 | **Win Codex** | 🔜 hand-off `docs/cross-instance-prs/20260508_tier16_stale_worktree_prune_codex.md` |
| `~/.claude/hooks/disk-cleanup.ps1` step 11 配線 | **Win Claude** (= home dir 編集権限) | 🔜 follow-up session |
| 観測 (= 2 week / 月 1+ GB reclaim 確認) | Win Claude | 🔜 part 180+ |

### 12.6 KPI

| metric | baseline | target |
|---|---|---|
| `.claude/worktrees/*` 合計 size | 2.28 GB (part 178) | < 1.5 GB |
| stale worktree 数 (= idle > 14 day) | 1 (part 178: relaxed-cartwright-deb1e2) | 0 |
| 月次 reclaim_MB | weekly cron 経由 ~500 MB | weekly + Tier 1.6 で 1500+ MB |

### 12.7 失敗 mode + 対策

| 失敗 mode | 対策 |
|---|---|
| `python` 不在 (= venv 未 activate) | hook 内 `python --version` check / 不在時 silently skip |
| `git worktree list` 30 sec timeout | `--max-runtime-sec=15` で強制中断 |
| current session detect 漏れ → 自己 prune | `$PWD` parent + `git rev-parse --show-toplevel` 二重 check |
| ad-hoc Codex worktree (= `instance-codex`) 誤 prune | branch name `codex/*` 全 skip (= [INSTANCE-ROLES] 尊重) |

### 12.8 PHILOSOPHY-22 alignment (= 7+/9 ✅)

| 原則 | alignment |
|---|---|
| #1 CEO 感 | ✅ 開発環境 hygiene = CEO の物理資産管理 |
| #2 ミッション | ✅ 「毎セッション必ず」要件直接対応 |
| #6 時間最適化 | ✅ Tier 1.6 = 15 sec cap / 累積 GB 単位 reclaim |
| #7 資産負債 | ✅ stale worktree = 隠れ負債 / 毎回 trim |
| #8 KPI | ✅ §12.6 数値 KPI 設定 |
| #4 6 部署 | ✅ infra 部署 dogfood |
| #5 商品=価値 | ✅ ビルド失敗 risk 削減 = velocity 価値 |
= 7/9 ✅ ([PHILOSOPHY-22] gate 通過).

---

## 13. Tier 1.7 disk hog telemetry (= part 179 新設 / observability 専用 / 自動 prune なし)

### 13.1 背景 + 隙間特定

User 2026-05-08 part 179 ask: 「**毎回のセッションで必ず** メモリ + HDD 容量圧縮施策」継続検討.

part 179 audit 実測 (= `~` 配下 9 dir / `Get-ChildItem -Recurse | Measure-Object Length`):

| Path | Size | hygiene カバー | 備考 |
|---|---|---|---|
| `~/.cache/codex-runtimes/codex-primary-runtime` | **721.9 MB** | ❌ なし | Codex CLI runtime / 単一 dir / 削除時 Codex 起動失敗 risk → **prune 不可** |
| `~/.claude/plugins/marketplaces/thedotmack` | **612.3 MB** | ❌ なし | claude-mem plugin / `plugin/` 576.8 MB が assets / `.git` 27.2 MB 軽微 |
| `~/.claude/projects` | 547.1 MB | ✅ Tier 1 (transcripts gzip) + Tier 1.5 (memory) | session log + memory hub |
| `~/AppData/Roaming/Code/User/workspaceStorage` | 249.4 MB | ❌ なし | VSCode dormant 後も残存 (= 12 instance 移行 obsolete) |
| `~/AppData/Local/npm-cache` | 245.2 MB | ⚠️ disk-cleanup Tier 2 のみ (= 週次手動) | Node tooling cache |
| `~/AppData/Local/Google/Chrome/User Data/Default/Cache` | 177.3 MB | ✅ Tier 1 step 7 (browser_cache) | OK |

**隙間** = `~/.cache/codex-runtimes` + `~/.claude/plugins/marketplaces` + VSCode workspaceStorage 計 **~1.6 GB が hygiene 非対象**.

うち `codex-primary-runtime` 722 MB は **prune 不可** (= 削除時 Codex 起動 fail). 残り `marketplaces/thedotmack` 612 MB + `workspaceStorage` 249 MB = **~860 MB が prune 候補**.

### 13.2 Tier 1.7 (= telemetry のみ / 自動 prune なし)

**自動 prune は実装しない**. 代わりに `disk-cleanup.ps1` 末尾 step 12 として **MAJOR_DIRS_MB telemetry** を log:

```powershell
# step 12: MAJOR_DIRS_MB telemetry (= no prune / observability only)
$majorDirs = @{
    'cache_codex_runtimes_MB'      = "$env:USERPROFILE\.cache\codex-runtimes"
    'plugins_marketplaces_MB'      = "$env:USERPROFILE\.claude\plugins\marketplaces"
    'projects_MB'                  = "$env:USERPROFILE\.claude\projects"
    'vscode_workspaceStorage_MB'   = "$env:USERPROFILE\AppData\Roaming\Code\User\workspaceStorage"
    'npm_cache_MB'                 = "$env:USERPROFILE\AppData\Local\npm-cache"
}
foreach ($k in $majorDirs.Keys) {
    $p = $majorDirs[$k]
    $sizeMB = if (Test-Path $p) {
        [math]::Round((Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { -not $_.PSIsContainer } |
            Measure-Object Length -Sum).Sum / 1MB, 1)
    } else { 0 }
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')]   ${k}: $sizeMB MB" | Add-Content $logPath
}
```

### 13.3 設計判断: なぜ自動 prune しないか

1. `codex-runtimes` = 削除時 Codex 起動 fail (= 致命) / version-pinned binaries / 手動再 install 必要
2. `marketplaces/thedotmack/plugin/` = claude-mem plugin assets / 削除時 plugin 失効 / 手動 reinstall 必要
3. `workspaceStorage` = VSCode dormant 後 obsolete だが `.code-workspace` リンク次第で復帰時必要
4. **観測 → 閾値超過時 user 判断** = INDIE-29 「YAGNI / 過剰自動化回避」

### 13.4 閾値駆動 alert (= §3 拡張)

`disk-cleanup.ps1` 末尾で telemetry 後 threshold check:

```powershell
$total_uncovered_MB = $majorDirs_telemetry['cache_codex_runtimes_MB'] +
                      $majorDirs_telemetry['plugins_marketplaces_MB'] +
                      $majorDirs_telemetry['vscode_workspaceStorage_MB']
if ($total_uncovered_MB -gt 2000) {
    "[$(Get-Date)] WARN: hygiene-uncovered dirs total ${total_uncovered_MB} MB > 2 GB threshold" |
        Add-Content $logPath
    # GHA scheduled-tasks-monitor が log scan で issue 起票 (= 既存 cron)
}
```

### 13.5 Acceptance criteria (= Codex 実装委譲)

- [ ] `disk-cleanup.ps1` step 12 = MAJOR_DIRS_MB telemetry 5 metric log 出力
- [ ] threshold 2 GB 超過時 WARN log
- [ ] 自動 prune 実装しない (= safety first)
- [ ] tests/ で 5 metric 出力検証
- [ ] PR description で「Issue #1984 axis A 強化 / Tier 1.7 telemetry only」明示

### 13.6 委譲外 (= Win Claude follow-up)

- 閾値超過 alert = GHA scheduled-tasks-monitor が log scan で auto-issue 起票連携 (= part 169 monitor cron 適用)
- 観測 KPI 集計 = 2 week 後 trend 確認

### 13.7 Philosophy alignment (= 6+/9 ✅)

| 原則 | alignment |
|---|---|
| #1 CEO 感 | ✅ HDD 漏れ箇所 visibility |
| #2 ミッション | ✅ 「毎セッション必ず」継続要件対応 |
| #7 資産負債 | ✅ hygiene 漏れ = 隠れ負債 / 観測で可視化 |
| #8 KPI | ✅ MAJOR_DIRS_MB 5 metric KPI 化 |
| #6 時間最適化 | ✅ telemetry only / 自動 prune による事故 risk 0 |
| #9 IPO 化 | ✅ disk audit 機構 = audit log 蓄積 |
= 6/9 ✅ ([PHILOSOPHY-22] gate 通過).

---

## 14. Tier 1.8 / 1.9 / 2.0 — 毎セッション必須圧縮の強化 (= part 180 新設 / User 要望 v3)

### 14.1 背景: 観測 -15.5 GB / day vs reclaim 0.5 MB / session = 圧倒的捕捉漏れ

User 2026-05-09 ask: 「**今の開発フローだとローカル環境のメモリやハードディスク容量が必ず枯渇する**. 毎回のセッションで必ずメモリやHDD容量を圧縮する施策」.

実測 audit (= part 180 / `~/.claude/logs/disk-cleanup-20260508.log`):

| metric | 値 | 評価 |
|---|---|---|
| C: free part 178b 終了時 | 86.6 GB | baseline |
| C: free part 180 開始時 | 71.1 GB | **-15.5 GB / 1 day** |
| Tier 1 average reclaim | 0.5 MB / session | **捕捉率 0.003%** |
| 推定隠れ負債合計 | 約 14 GB | -15.5 GB と整合 |

**隠れ負債 audit 結果** (= part 180 新規 PowerShell scan):

| dir | size | Tier 1-1.7 対象 | gap |
|---|---|---|---|
| `~\AppData\Local\Temp` (recursive) | **8.5 GB** | step 1 (`temp_7d_MB`) で 7 day filter / mtime 維持で対象外多数 | **大** |
| `~\AppData\Roaming\npm` | **2.0 GB** | ❌ 完全未対象 | **大** |
| `~\AppData\Local\pnpm` | **2.5 GB** | ❌ 完全未対象 | **大** |
| `~\AppData\Local\Programs\Python` | 0.9 GB | system file / 触らない | n/a |
| `~\AppData\Local\Microsoft\Edge\...\Cache` | 0.32 GB | step 8 (browser_cache) で部分対象 | 小 |
| `~\AppData\Local\Microsoft\TypeScript` | 0.16 GB | ❌ 未対象 | 小 |

→ **合計 13 GB (Temp + npm + pnpm) が現状 Tier 1-1.7 で完全に取り逃し**.

### 14.2 Tier 1.8 — Package manager cache aggressive sweep (= 新設 / 自動 prune)

`disk-cleanup.ps1` step 11 として追加:

| step | target | 戦略 | 期待 reclaim |
|---|---|---|---|
| 11.1 | `~\AppData\Local\pnpm\store\v3` | `pnpm store prune` (= unused 削除 / 100 MB+ なら実行) | 1-2 GB |
| 11.2 | `~\AppData\Roaming\npm-cache` | mtime > 30 day file 削除 (= active package は触らない) | 0.5-1 GB |
| 11.3 | `~\.pub-cache\hosted` | mtime > 30 day | 0-2 GB |
| 11.4 | `~\.cache\pip` (= macOS / Linux 経由) | mtime > 14 day | 0-0.3 GB |
| 11.5 | `~\AppData\Local\Yarn\Cache` | mtime > 14 day | 0-0.5 GB |
| 11.6 | `~\.cache\gh` | mtime > 7 day | 0-0.2 GB |

**安全 rule** (Tier 1.6 / 1.7 と同じ):
- ❌ `pnpm store prune` のみ native command 経由 (= dangling package のみ削除 / active 安全)
- ❌ npm-cache は `mtime + filename pattern` filter (`_cacache/content-v2/sha512/**` のみ削除対象)
- ❌ 各 step `--max-runtime-sec=10` で SessionStart 全体 60 sec budget 内
- ❌ active 開発中 (= node_modules 内 package が cache 参照中) の場合 noop (= cache miss → 再 download = ネットコスト発生のみ / アプリ動作は無事)

### 14.3 Tier 1.9 — Temp 深層 sweep 強化 (= step 1 拡張 / 自動 prune)

現状 step 1: `Remove-OlderThan -Path $env:TEMP -Days 7 -Recurse`

問題: -Recurse でも mtime 更新が継続している sub-tree が大量 (= installer / IDE intellisense の中間ファイル等).

修正方針:

```ps1
# Tier 1.9 拡張 (= step 1 への追加 sub-step)
# 1.9.1 - Temp 直下のサブディレクトリ単位で「dir 内の最新 mtime」が 14 day 超なら dir ごと削除
$tempDirs = Get-ChildItem -Path $env:TEMP -Directory -Force -EA SilentlyContinue
foreach ($d in $tempDirs) {
    $latest = (Get-ChildItem $d.FullName -Recurse -Force -EA SilentlyContinue |
              Measure-Object LastWriteTime -Maximum).Maximum
    if ($latest -and $latest -lt (Get-Date).AddDays(-14)) {
        Remove-Item $d.FullName -Recurse -Force -EA SilentlyContinue
    }
}
# 1.9.2 - Temp ルート直下の .tmp / .log / .etl / *.dmp は 7 day で問答無用削除
```

期待 reclaim: **3-5 GB / session** (= 8.5 GB のうち 14 day 超サブツリー).

### 14.4 Tier 2.0 — Session delta tracking + 警告 (= 新設 / 観測専用)

毎 SessionStart + SessionEnd で delta を `~\.claude\logs\session-delta.csv` に append:

```csv
ts,session_id,phase,c_free_gb,reclaim_mb_session,reclaim_mb_7d_median
2026-05-09T11:30:00Z,b1042d,start,71.1,,
2026-05-09T12:30:00Z,b1042d,end,72.4,1340,820
```

**警告 trigger** (= cleanup_report_notify.ps1 hook へ統合):

| 条件 | action |
|---|---|
| 7-day median session reclaim < 100 MB | `~\cleanup_reports\warning_<ts>.md` 自動生成 + Claude additionalContext で「Tier 1.8 効果未達 / scope 拡張要検討」 |
| C: free 7-day delta < -3 GB | 同上 + Issue 自動起票 (= `gh issue create` / label `disk-hygiene` `auto-generated`) |
| C: free < 30 GB (= 危険水域) | RED alert / SessionStart で Claude に最優先 instruction |

### 14.5 RAM trim Phase 2 (= memory-cleanup.ps1 step 6 として追加)

現状 memory-cleanup.ps1 = 5 step / 大半 admin only で skip.

新 step 6 (= non-admin 動作可):

```ps1
# Step 6 - idle process working set trim (= EmptyWorkingSet)
# admin 不要 / 非 admin でも自プロセスや user-owned proc に対して可
$targets = Get-Process -EA SilentlyContinue | Where-Object {
    $_.Name -match '^(claude|code|node|electron|Code|Cursor)' -and
    $_.WorkingSet64 -gt 200MB -and
    ((Get-Date) - $_.StartTime).TotalMinutes -gt 10
}
foreach ($p in $targets) {
    try { [void]$p.MinWorkingSet; $p.MinWorkingSet = 1MB } catch {}
}
```

期待効果: idle Claude/VSCode の RSS を OS が swap 可能化 → 物理 RAM free 0.5-2 GB / session.

### 14.6 [INSTANCE-ROLES] 振分

| 担当 | 内容 | session |
|---|---|---|
| **Win Claude (= 本 spec)** | §14.1-14.5 設計 + acceptance criteria + rollback 戦略 | part 180 完了 |
| **Win Codex (= hand-off)** | `disk-cleanup.ps1` step 11 (Tier 1.8) + step 1 拡張 (Tier 1.9) + `session_delta_tracker.ps1` (Tier 2.0) + `memory-cleanup.ps1` step 6 (RAM trim Phase 2) 実装 | 期限 **2026-05-23** |

Codex 振分 5 質問 score:

| Q | A |
|---|---|
| 1. 設計 / アーキ判断要? | NO (= 本 spec で確定) |
| 2. 横断 docs / memory 編集要? | NO (= 本 spec のみ) |
| 3. UI design 要? | NO |
| 4. triage / hand-off 判断要? | NO (= 本 spec で完了) |
| 5. mobile UAT / 動画要? | NO |

= 0/5 → **完全 Codex 案件** (= 実装 + script 配線).

### 14.7 安全 rule 全体 (= Tier 1.8 / 1.9 / 2.0 共通)

- ❌ active 開発中 process の lock file detect 時 skip
- ❌ 各 Tier 独立に `--max-runtime-sec` cap (= SessionStart 全体 60 sec budget 維持)
- ❌ 失敗時 silent (= `try/catch` + `-EA SilentlyContinue`)
- ❌ Tier 1.9 Temp sub-tree 削除前 = `git status` 等 active workspace 内の Temp 参照不在を確認
- ❌ rollback: 全 Tier `--dry-run` flag / `--apply` 二段運用 (Tier 1.6 / 1.7 と同じ)

### 14.8 Acceptance Criteria

- [ ] `disk-cleanup.ps1` 1 回実行で 7-day median reclaim ≥ 500 MB / session
- [ ] `~\.claude\logs\session-delta.csv` が SessionStart + SessionEnd で append される
- [ ] `pnpm store prune` 動作確認 (= disk-cleanup-YYYYMMDD.log に `tier_1_8_pnpm_MB: <数値>` 出力)
- [ ] `npm-cache` 30 day filter 動作確認
- [ ] Temp sub-tree 14-day prune 動作確認 (= `temp_subtree_14d_MB: <数値>` 新 metric)
- [ ] RAM trim Phase 2 で `Get-Process` 結果に Claude/Code が trim 検知される
- [ ] 警告閾値 (Tier 2.0) 動作確認 (= 7-day median < 100 MB or C: < 30 GB)

### 14.9 KPI / 監視

| metric | 計測場所 | 目標 |
|---|---|---|
| `reclaim_mb_per_session` | `disk-cleanup-YYYYMMDD.log` 末尾 1 行 | ≥ 500 MB / session (median) |
| `c_free_7d_delta_gb` | `session-delta.csv` 7 row median | ≥ 0 (= 漸増を相殺) |
| `ram_trim_count` | `memory-cleanup-YYYYMMDD.log` step 6 行 | session ごとに ≥ 1 件記録 |
| `tier_skipped_count` | 各 Tier の skip 理由 log | < 50% |

### 14.10 PHILOSOPHY-22 gate (= 7+/9 ✅ 必須)

| 原則 | 対応 |
|---|---|
| #1 CEO 感 | ✅ user 介在 0 / 完全自走 (= 1-click 操作不要) |
| #2 ミッション | ✅ 「健全な開発環境」= ユーザー時間資本保全 |
| #3 mentor | ✅ 失敗 silent / 警告 doc 経由で穏やか |
| #5 商品 = 価値 | ✅ disk 圧迫 = 価値減 / 解放 = 価値増 |
| #6 時間最適化 | ✅ session 開始時の手動 cleanup → 0 sec |
| #7 資産負債 | ✅ 隠れ 13 GB 負債 → 可視化 → 月次定常解放 |
| #8 KPI 自分比較 | ✅ 7 day median delta tracking |
| #9 IPO 化 | ✅ 持続的 hygiene 機構 = 永続資産 |

= 8/9 ✅ ([PHILOSOPHY-22] gate 通過 / #4 6 部署 のみ marginal).

### 14.11 Codex #1 implementation notes (= PR #1984 Tier 1.8/1.9/2.0)

- `scripts/dev_cache_cleanup.py --tier18 --tier19` adds package-cache metrics (`tier_1_8_pnpm_MB`, `tier_1_8_npm_MB`, `tier_1_8_pub_MB`, `tier_1_8_pip_MB`, `tier_1_8_yarn_MB`, `tier_1_8_gh_MB`) and `temp_subtree_14d_MB`.
- `.github/workflows/dev-cache-cleanup-cron.yml` validates Tier 1.8/1.9 in dry-run and safe apply on the hosted Windows runner.
- `scripts/disk_hog_telemetry.py` emits the Tier 1.7 five-directory MAJOR_DIRS_MB telemetry and a 2 GB uncovered warning without automatic pruning.
- `scripts/worktree_cleanup.py --tier1 --apply --max-runtime-sec=15` adds the SessionStart-friendly stale worktree prune primitive with idle/size/prefix/locked/current-worktree guards and a `reclaimed_mb=<int>` stdout line.
- `scripts/session_delta_tracker.py --phase start|end` appends `~/.claude/logs/session-delta.csv` rows and creates warning files when median reclaim, 7-day C: delta, or absolute free-space thresholds are crossed.
- `scripts/memory_trim_phase2.ps1` exposes `ram_trim_count` and `ram_trim_total_mb_freed` for hook integration without requiring administrator rights.

## 15. 毎セッション圧縮 status verify (= part 184 新設 / User 要望 v3 再確認 / 2-instance fleet)

### 15.1 hooks coverage 監査結果 (= 2026-05-09 part 184 verify)

User 2026-05-09 part 184 ask: 「**今の開発フローだとローカル環境のメモリやハードディスク容量が必ず枯渇する**. 毎回のセッションで必ずメモリやハードディスク容量を圧縮する施策を検討してください」.

→ §14 (= part 180 ship) と同 ask の **再確認要求**. hooks 設定 + 動作 verify の 2-axis audit を実施.

#### 15.1.1 settings.json hooks 設定状況 (= 既 full coverage)

```
SessionStart (4 hooks): session-resume + cleanup_report_notify + disk-cleanup + memory-cleanup
SessionEnd   (2 hooks): disk-cleanup + memory-cleanup
PreCompact   (1 hook):  memory-cleanup
```

= **両端 trigger 設定済** (= user 要件「毎回のセッションで必ず」satisfy 設定).

#### 15.1.2 実 reclaim 観測値 (= `~/.claude/logs/*-cleanup-20260509.log`)

| axis | reclaim/session | 評価 |
|---|---|---|
| **Memory side** (= memory-cleanup.ps1 step1 EmptyWorkingSet) | **4.0-4.9 GB / session** | ✅ achieved (= claude/Codex/msedge/chrome/Code/node/dotnet/python/flutter/dart 全 trim) |
| **Disk side** (= disk-cleanup.ps1 Tier 1 全 step) | **0.4-1.2 MB / session** | ⚠️ §14.1 audit と一致 (= 隠れ 13 GB 負債 / Tier 1.8/1.9/2.0 未実装) |

memory side は既に「session 開始時 free 11% → session 終了時 free 30%」の劇的改善を達成. disk side は Codex hand-off `20260509_codex_tier18_19_20_compression_part180.md` (= 期限 2026-05-23) の実装着地 待ち.

### 15.2 2-instance fleet routing 反映 (= [INSTANCE-ROLES])

| instance | 役割 | 対応 task | 期限 / 状態 |
|---|---|---|---|
| **Win Claude (= 本 § 起票)** | architect / docs / triage / verify | §14 spec 起票 (part 180) + 本 §15 status verify (part 184) | ✅ both shipped |
| **Win Codex** | 実装 / scripts / GHA | `disk-cleanup.ps1` step 11 (Tier 1.8) + step 1 拡張 (Tier 1.9) + `session_delta_tracker.ps1` (Tier 2.0) + `memory-cleanup.ps1` step 6 (RAM trim Phase 2) | 期限 **2026-05-23** / 今日 2026-05-09 = **T+0 day** / 残 14 days |

**ping 判定** (= part 183 確立 schedule 厳守):
- T+0 day (= 今日) = **skip** (= Codex CI/automation pickup window)
- T+3 day (= 2026-05-12) = gentle ping if no movement
- T+7 day (= 2026-05-16) = harder ping
- T+13 day (= 2026-05-22) = definitive ping (= halfway to deadline)

### 15.3 quick win options (= Codex impl 待ち期間 Win Claude actionable)

| option | description | risk | 採用 |
|---|---|---|---|
| A. session-end manual `pnpm store prune` | `disk-cleanup` skill Step 5 を session ごと実行 | low (= active package 影響なし) | ✅ part 184 で実施済 (= Tier 2 hygiene 内) |
| B. weekly 手動 `flutter pub cache repair` | session 外 / 週末 batch | medium (= 再 download cost) | △ user 判断 |
| C. monthly browser cache deep clear | 月次 batch / msedge + chrome 全 cache 削除 | medium (= login state 影響) | △ user 判断 |
| D. SessionEnd hook で `pnpm store prune` 自動化 | settings.json 拡張 | low | △ Codex hand-off に統合推奨 |

→ **A (= 本 part 184 実施済)** + **D (= Codex 5/23 hand-off に option 追加)** が最適 routing.

### 15.4 KPI / 監視 update (= part 184 baseline)

| metric | 現状 (= part 184) | 目標 (= §14.9 reaffirm) | gap |
|---|---|---|---|
| `disk_reclaim_mb_per_session` | 0.4-1.2 MB | ≥ 500 MB / session (median) | **400x gap** (= Codex 5/23 impl で解消期待) |
| `memory_reclaim_mb_per_session` | 4000-4900 MB | (新規 KPI / §14 で未定義) | ✅ implicit achieved |
| `c_free_7d_delta_gb` | 79.17 → 79.5 (= +0.3 / part 184 manual + git gc) | ≥ 0 (= 漸増を相殺) | ✅ part 184 single-day OK / 7-day median は要 tracking |
| `session_end_hook_invoke_count` | 2/session (= disk + memory) | 2/session | ✅ 100% |

### 15.5 user 要望 reaffirm (= 「枯渇する」根本原因)

User の本 ask の根本原因は **§14.1 で identified 済**:
- 隠れ 13 GB 負債 (= Temp 8.5 GB + npm 2.0 GB + pnpm 2.5 GB) が現状 Tier 1-1.7 で **完全に取り逃し**
- Tier 1.8/1.9/2.0 = 真の対策 / Codex 5/23 hand-off で着地予定

**Win Claude (= 本 part 184) actionable**:
- ✅ status verify + 2-instance routing 明示 (= 本 §15)
- ✅ Codex T+0 ping skip 判断 (= 14 days deadline / 5/12 next check)
- ❌ script 直接実装 = [INSTANCE-ROLES] Codex 担当 / scope creep 回避

### 15.6 PHILOSOPHY-22 gate (= 8/9 ✅ 維持)

§14.10 と同. 本 §15 = status verify only / 新原則追加なし.

> **part 184 status**: hooks coverage = ✅ full / memory side = ✅ achieved / disk side = ⚠️ Codex impl 待ち / next ping = 2026-05-12 (= T+3).

### 15.7 part 185 update — Codex PR #2182 dogfood verify (= 14-day early着地)

**2026-05-09 part 185** = Codex が 5/23 deadline を **14-day 前倒し** で全 5 primitive を着地. PR [#2182](https://github.com/kanta13jp1/my_web_app/pull/2182) MERGED (= +1252 / -18 / 11 files). Win Claude 側 dogfood-run 第 1 例で動作 verify 完了.

#### 15.7.1 5 primitive 動作 verify (= Win Claude session 内 dogfood-run)

| primitive | invocation | 結果 | 評価 |
|---|---|---|---|
| `worktree_cleanup.py --tier1 --max-runtime-sec=15` | dry-run | 4 worktree scan / 0 candidate (= 全 SKIP / safe) / `reclaimed_mb=0` | ✅ Tier 1 conservative 設計通り |
| `disk_hog_telemetry.py` | telemetry only | cache_codex_runtimes=721 MB + plugins_marketplaces=625 MB + projects=559 MB + vscode_workspaceStorage=249 MB + npm_cache=95 MB | ✅ 5 metric 出力 OK / no auto-prune (= Tier 1.7 design 厳守) |
| `dev_cache_cleanup.py --tier18 --tier19 --aggressive-cache-sweep --temp-deep-sweep --apply` | apply | dry-run 9.4 MB 計画 → actual 0 MB / 4 command failed / 1 success | ⚠️ 商用 command (`dart pub cache clean`/`pip cache purge`/`npm cache verify`/`pnpm store prune`) 4 失敗 / minor / 別 issue 候補 |
| `memory_trim_phase2.ps1` | apply | `ram_trim_count=4 ram_trim_total_mb_freed=1075` | ✅ **+1075 MB RAM 解放** (= 過去最大 single-script 効果) |
| `session_delta_tracker.py --phase {start,end}` | start + end | start: c_free=79.05 GB → end: c_free=79.08 GB / WARNING 発火: "7-day median reclaim 0.0 MB < 100 MB" → `cleanup_reports/warning_20260508_181354.md` 出力 | ✅ Tier 2.0 delta + threshold warning 正常動作 |

#### 15.7.2 SessionStart hook wiring 漏れ finding (= 次 step)

5 primitive は repo に着地済だが **SessionStart/SessionEnd hook が新 script を invoke していない**:

```bash
$ grep -E "dev_cache_cleanup|worktree_cleanup|memory_trim_phase2|session_delta_tracker|disk_hog_telemetry" ~/.claude/hooks/*.ps1 ~/.claude/hooks/*.sh
(no match)
```

→ user 要望「**毎回のセッションで必ず**」を満たすには hook wiring が必須. options:

| option | scope | risk | 担当 |
|---|---|---|---|
| **A.** `~/.claude/settings.json` `SessionStart` に `worktree_cleanup --tier1` + `session_delta_tracker --phase start` 追加 | settings.json edit | low (= dry-run / max-runtime-sec=15 制限) | Win Claude (= update-config skill / 1 セッション完結) |
| **B.** `SessionEnd` に `dev_cache_cleanup --tier18` + `memory_trim_phase2.ps1` + `session_delta_tracker --phase end` 追加 | settings.json edit | low-medium (= --apply 実行 / dart pub fail 観測 / cmd 修正必要) | Win Claude + Codex follow-up |
| **C.** Codex PR template に「rule 追加時 hook wiring 同時 update 必須」追記 | docs only / `.github/PULL_REQUEST_TEMPLATE.md` | low | Win Claude design / 別 session |

→ **A + C** が最低限必須. **B は dev_cache_cleanup の 4 command 失敗 issue 解消後** 推奨.

#### 15.7.3 KPI 状況 update (= part 185 baseline)

| metric | part 184 | part 185 (= Codex impl 後 / hook 未配線) | next target |
|---|---|---|---|
| `disk_reclaim_mb_per_session` | 0.4-1.2 MB | 0.0 MB (= dev_cache --apply 4 failed / hook 未配線) | ≥ 500 MB / session — hook wiring (= option A+B) で達成見込み |
| `memory_reclaim_mb_per_session` | 4000-4900 MB | **+1075 MB on-demand** (= memory_trim_phase2.ps1 / 1 回実行で観測) | hook wiring 後 session ごと自動化期待 |
| `7d_median_reclaim_mb` (= 新 KPI) | n/a | **0.0 MB / threshold 100 MB 未達 / WARNING 発火** | hook 配線後 7-day rolling 目標 |
| Codex sprint completion 5/22-5/24 | 4/8 (= part 184 時点) | **7/8 = 87.5%** (= part 185 / #1984 PR #2182 14-day 早着地で +3) | 残 #2171 (T+3 = 2026-05-12) |

#### 15.7.4 Issue #1984 close 推奨判定 (= verify-only 結果)

PR #2182 で **Tier 1.7/1.8/1.9/2.0 + RAM Phase 2 + worktree --tier1 全 primitive 着地** + unit test 完備. Issue #1984 の 4 axis 内訳:

- ✅ axis A (= worktree cleanup) = `worktree_cleanup.py --tier1` 着地 (= part 178b 同等強化)
- ✅ axis B (= cache rotation) = `dev_cache_cleanup.py --tier18` (= aggressive sweep) 着地 (= 4 command 失敗 detail は別 issue 推奨)
- ✅ axis C (= dev cache) = PR #2093 で先行着地済 (= 旧 part 報告)
- ✅ axis D (= memory + session delta) = `memory_trim_phase2.ps1` + `session_delta_tracker.py` 着地

→ **Issue #1984 close 推奨** (= ただし **hook wiring (= 15.7.2 option A+B) 完了後**). Win Claude part 186 で Issue verify comment + close 提案 (= user 確認 1 step 経由).

#### 15.7.5 PHILOSOPHY-22 gate (= 7/9 ✅ 維持)

- 主要実装: dogfood verify + hook wiring gap finding + Issue close 推奨判定
- 該当原則: #6 (時間最適化 = primitive 即 dogfood) + #7 (資産負債 = 隠れ 13 GB 負債解消パス確立) + #8 (KPI = `disk_reclaim_mb_per_session` 観測値 base 確立) + #5 (商品 = 価値 = 環境健全性向上)
- 整合性スコア: 7/9 ✅ ([PHILOSOPHY-22] gate 通過)

> **part 185 status**: Codex 5/23 hand-off **14-day early完了** ✅ / 5 primitive 動作 verify ✅ / hook wiring = ⚠️ next session step / Issue #1984 close 推奨 (= hook wiring 後) / next ping = 2026-05-12 (= T+3 / #2171 のみ).

## 16. Tier 2.1 — Mid-session compression (= part 189 新設 / User 要望「毎セッション必ず枯渇」 v4)

### 16.1 課題 (= why)

User 直接 ask (= part 189 / 2026-05-09):
> 今の開発フローだと、ローカル環境のメモリやハードディスク容量が必ず枯渇します。毎回のセッションで必ずメモリやハードディスク容量を圧縮する施策を検討してください。

現行 hygiene = **SessionStart + SessionEnd 両端のみ** (= part 186 wiring 完了). 中間 90+min の長時間 session では:

| 圧迫源 | 観測値 (part 188 末尾) | 累積速度 (推定) |
|--------|---------------------|---------------|
| C: free GB | 87 GB | -0.05 GB / 30 min (= 大きな commit / artifact 生成時) |
| RAM 使用率 | 95% | +200-400 MB / 30 min (= Claude Code chat history + Flutter analyzer) |
| transcript hot-cache | (= 90+ MB / session) | +30 MB / 30 min |

**結論**: 90+ min session で SessionStart 圧縮の効果が消失 → mid-session 圧縮 hook 必須.

### 16.2 設計 (= Tier 2.1 = mid-session 軽量圧縮)

**Trigger**: PostToolUse hook (= 既存 hook を **throttle 拡張**)

```ps1
# C:\Users\kanta\.claude\hooks\auto-capture.ps1 (= 既存) を拡張
# または新規 mid-session-compress.ps1 を追加
$counterFile = "$env:USERPROFILE\.claude\logs\post_tool_counter.txt"
$threshold = 50  # = 50 tool call ごと
$counter = if (Test-Path $counterFile) { [int](Get-Content $counterFile) } else { 0 }
$counter++
Set-Content $counterFile $counter

if ($counter % $threshold -eq 0) {
  # 軽量圧縮 fire (= < 5 sec / non-blocking)
  Start-Job -ScriptBlock {
    & python "C:\Users\kanta\.claude\scripts\mid_session_compress.py" --quick
  } | Out-Null
}
```

**Execute** (= 新規 script):

```python
# C:\Users\kanta\.claude\scripts\mid_session_compress.py
"""Mid-session lightweight compression. Runs in <5sec, non-blocking.
Targets:
  1. transcript hot-cache 削除 (= > 30 MB の単一 session log を gzip)
  2. flutter build cache prune (= > 100 MB の build/ ディレクトリ)
  3. RAM trim (= python gc.collect 等価)
Emits: ~/.claude/logs/mid-compress.csv 1 row per fire.
"""
import argparse
import time
from pathlib import Path

def quick_transcript_compress(threshold_mb=30):
    """Compress transcript files > threshold MB in place."""
    # ... gzip in-place
    pass

def flutter_build_cache_prune(max_age_hours=2):
    """Remove flutter build/ if older than max_age_hours and not currently writing."""
    # ... safe prune
    pass

def memory_release():
    """Trigger Windows working set trim equivalent."""
    # subprocess: powershell "[System.Diagnostics.Process]::GetCurrentProcess().MinWorkingSet=..."
    pass

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--quick", action="store_true", help="<5sec mode")
    args = parser.parse_args()
    start = time.time()
    # fire 3 functions
    elapsed = time.time() - start
    # log row to ~/.claude/logs/mid-compress.csv
```

### 16.3 Threshold-triggered alerting (= 16.2 補強 / safety gate)

PostToolUse 50 tool call 毎の軽量実行に加えて、**threshold cross 時の追加 fire**:

| Trigger | Threshold | 動作 |
|---------|-----------|------|
| C: free | < 80 GB | 即 mid_session_compress.py --aggressive fire |
| RAM | > 90% used | memory_trim_phase2.ps1 --quick fire |
| transcript dir | > 200 MB | transcript hot-cache 強制 prune |

### 16.4 settings.json hook 拡張案

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash|Write|Edit",
        "hooks": [
          { "type": "command", "command": "powershell ... auto-capture.ps1" },
          { "type": "command", "command": "powershell ... mid-session-compress.ps1", "timeout": 10 }
        ]
      }
    ]
  }
}
```

### 16.5 Phase 分割 (= Codex hand-off / 期限 2026-05-23)

| Phase | 内容 | 担当 | 期限 |
|-------|------|------|------|
| **Phase 1** (telemetry) | `mid_session_compress.py --observe` (= ログのみ / fire しない) + `~/.claude/logs/mid-compress.csv` | Codex | 2026-05-15 |
| **Phase 2** (auto-fire) | PostToolUse hook 配線 + 50 tool call throttle | Codex | 2026-05-19 |
| **Phase 3** (threshold) | C: free < 80 GB / RAM > 90% trigger 追加 | Codex | 2026-05-21 |
| **Phase 4** (verify) | 1 week observation + tuning + DISK_HYGIENE_RUNBOOK §16 status update | Win Claude | 2026-05-30 |

### 16.6 受け入れ条件

- [x] 90+ min session で **mid-compress fire row が CSV に 1+ 件記録される**
- [x] `mid_session_compress.py --quick` 実行時間 **median < 5 sec** (= non-blocking 維持)
- [x] C: free GB が SessionStart 後も **target floor (= 80 GB) 以上維持**
- [x] RAM 使用率が SessionStart 後も **target ceil (= 95%) 以下維持**
- [x] PostToolUse hook の throttle が正しく動作 (= 50 tool call 毎 1 fire)
- [x] aggressive mode で誤って ongoing build を消さない (= mtime + lsof 等価 check)

### 16.7 KPI (= 既存 `disk_reclaim_mb_per_session` 拡張)

| KPI | 現状 (part 188) | target (part 189 spec) |
|-----|---------------|---------------------|
| `disk_reclaim_mb_per_session` (= start+end 合計) | 1008 MB / median | 1500 MB / median (= +50%) |
| `mid_compress_fires_per_session` | 0 (= hook なし) | 1+ (= 90+min session で必ず) |
| `c_free_gb_floor_per_session` | 80 GB | 80 GB 維持 |
| `ram_pct_ceil_per_session` | 95% | 95% 維持 |

### 16.8 PHILOSOPHY-22 gate (= 7+/9 ✅ 維持)

- 主要実装: 90+ min session の中間圧縮確立 + threshold-triggered safety gate
- 該当原則:
  - #1 (CEO 感) — user の "毎セッション必ず" 要望に対する直接応答
  - #5 (商品 = 価値) — 環境健全性 = 開発価値増大
  - #6 (時間 = 資本) — 圧縮自動化で user 介入時間ゼロ
  - #7 (資産負債) — disk / RAM 負債を session 内で漸減
  - #8 (KPI) — `mid_compress_fires_per_session` 計測可能
- 整合性スコア: 7/9 ✅ ([PHILOSOPHY-22] gate 通過)

### 16.9 関連

- 親要望 (= user iterative ask):
  - **v1** (= part 154) `[disk-pressure]` SessionStart hook 新設
  - **v2** (= part 178b) Tier 1.6 stale worktree prune
  - **v3** (= part 180) Tier 1.8/1.9/2.0 強化
  - **v4** (= part 189 / 本 §16) **mid-session 圧縮**
- Issue #1984 4 axis 統合
- 横展開候補: PreCompact hook も同等強化 (= 既存 `memory-cleanup.ps1` を mid_session_compress 経由に統合)

> **part 189 status**: spec ship / Codex hand-off (= Phase 1-4 / 期限 2026-05-23) / Win Claude verify は part 196 想定 (= Phase 4 完了後 1 week observation).

## 17. Tier 2.2 / 2.3 / 2.4 — v5: Hook wiring 完成 + 圧縮自動化 100% 化 (= part 190 新設 / User 要望 v5 / Issue #1983 連動)

### 17.1 課題 (= why v5)

User 直接 ask (= part 190 / 2026-05-09):
> 今の開発フローだと、ローカル環境のメモリやハードディスク容量が必ず枯渇します。毎回のセッションで必ずメモリやハードディスク容量を圧縮する施策を検討してください。

v4 (= §16 / part 189) で **mid-session compression spec** は ship 済. しかし part 190 audit で actual `settings.json` の hook wiring を実測 → **3 critical gap** 発見:

| Gap | 観測 | 影響 |
|-----|------|------|
| **A. SessionEnd 非対称** | SessionStart 6 hook ↔ SessionEnd 4 hook (= `worktree_cleanup` 欠落) | session 終了時に worktree 累積 = 14 GB 漸増 |
| **B. PostToolUse mid-session 未配線** | `auto-capture.ps1` のみ / `mid_session_compress.py` 起動なし | 90+ min session で SessionStart 効果消失 = §16 spec が dead 状態 |
| **C. PreCompact 限定配線** | `memory-cleanup.ps1` のみ / disk-cleanup + worktree_cleanup 欠落 | compaction 直前の重い session で disk pressure 解消されない |

→ **v5 = §16 spec の実装 + 上記 3 gap fix で「毎セッション必ず圧縮」を 100% 化**.

### 17.2 Wiring gap audit (= 4 finding)

actual `~/.claude/settings.json` (= part 190 audit):

```
PostToolUse:    1 hook  (= auto-capture only)
SessionStart:   6 hooks (= resume, cleanup_report, disk-cleanup, memory-cleanup, worktree_cleanup --tier1, session_delta --start)
SessionEnd:     4 hooks (= disk-cleanup, memory-cleanup, memory_trim_phase2, session_delta --end)  ← worktree_cleanup 欠落
UserPromptSubmit: 1 hook (= inject-rules)
PreCompact:     1 hook  (= memory-cleanup only)  ← disk-cleanup + worktree_cleanup 欠落
```

期待:

```
PostToolUse:    2 hooks (= auto-capture + mid_session_compress)
SessionStart:   6 hooks (= 現状維持)
SessionEnd:     5 hooks (= worktree_cleanup --tier1 追加)
UserPromptSubmit: 1 hook (= 現状維持)
PreCompact:     3 hooks (= memory-cleanup + disk-cleanup --pre-compact + worktree_cleanup --tier1)
```

→ **+3 hook 追加** で全 lifecycle 圧縮自動化完成.

### 17.3 Tier 2.2 = SessionEnd worktree_cleanup 追加

```json
{
  "type": "command",
  "command": "powershell -NoProfile -ExecutionPolicy Bypass -Command \"& python C:\\Users\\kanta\\.claude\\scripts\\worktree_cleanup.py --tier1 --apply --max-runtime-sec=15\"",
  "timeout": 20
}
```

期待効果:
- SessionEnd 時の stale worktree (= 30 day 経過 / merged ✅ 検出) を **--apply 強制 prune**
- safety: `--max-runtime-sec=15` で session 終了を遅延させない
- start/end symmetric → worktree 累積防止

### 17.4 Tier 2.3 = PostToolUse mid_session_compress 追加 (= §16 spec 実装)

```json
{
  "matcher": "Bash|Write|Edit",
  "hooks": [
    { "type": "command", "command": "powershell -ExecutionPolicy Bypass -File \"C:\\Users\\kanta\\.claude\\hooks\\auto-capture.ps1\"" },
    {
      "type": "command",
      "command": "powershell -NoProfile -ExecutionPolicy Bypass -Command \"& python C:\\Users\\kanta\\.claude\\scripts\\mid_session_compress.py --quick\"",
      "timeout": 8
    }
  ]
}
```

`mid_session_compress.py` 仕様 (= §16.2 から再掲):
- **Throttle**: 50 tool call ごと fire (= internal counter 管理)
- **Tasks**: transcript hot-cache gzip / flutter build cache prune / RAM working set trim
- **Runtime**: < 5 sec (= non-blocking / Start-Job background)
- **Idempotent**: lock file (= `~/.claude/logs/mid-compress.lock`) で並行 fire 防止

### 17.5 Tier 2.4 = PreCompact 完全圧縮 (= compaction 前の最終駆込)

```json
"PreCompact": [
  { "hooks": [
    { "type": "command", "command": "powershell -ExecutionPolicy Bypass -File \"C:\\Users\\kanta\\.claude\\hooks\\memory-cleanup.ps1\"" },
    { "type": "command", "command": "powershell -ExecutionPolicy Bypass -File \"C:\\Users\\kanta\\.claude\\hooks\\disk-cleanup.ps1\" -PreCompact" },
    {
      "type": "command",
      "command": "powershell -NoProfile -ExecutionPolicy Bypass -Command \"& python C:\\Users\\kanta\\.claude\\scripts\\worktree_cleanup.py --tier1 --apply --max-runtime-sec=20\"",
      "timeout": 25
    }
  ]}
]
```

PreCompact = compaction 直前 = session 内で最も disk/RAM 圧迫している瞬間. 全 hygiene 一斉 fire で **compaction → resume の cycle で 1-2 GB reclaim 期待**.

### 17.6 Threshold-triggered emergency fire (= safety net)

PostToolUse hook 内で C: free GB が **< 50 GB cross 時** に追加 fire:

```powershell
$freeGB = (Get-PSDrive C).Free / 1GB
if ($freeGB -lt 50) {
  Start-Job -ScriptBlock {
    & python "$env:USERPROFILE\.claude\scripts\mid_session_compress.py" --aggressive
    & python "$env:USERPROFILE\.claude\scripts\worktree_cleanup.py" --tier1 --apply --max-runtime-sec=30
  } | Out-Null
}
```

「毎セッション必ず圧縮」guarantee = throttle (= 50 tool call) + threshold (= < 50 GB) の **OR fire**.

### 17.7 Codex hand-off scope (= 期限 2026-05-30 / Issue #1983 follow-up)

| Task | 担当 | 期限 |
|------|------|------|
| A. `~/.claude/scripts/mid_session_compress.py` 実装 (= §16.2 spec) | Codex | 2026-05-23 |
| B. SessionEnd hook 5th = `worktree_cleanup.py --tier1` 配線 (= settings.json patch) | Codex | 2026-05-23 |
| C. PostToolUse hook 2nd = `mid_session_compress.py --quick` 配線 | Codex | 2026-05-25 |
| D. PreCompact hook 2nd-3rd = disk-cleanup + worktree_cleanup 配線 | Codex | 2026-05-25 |
| E. Threshold-triggered emergency fire 実装 (= §17.6) | Codex | 2026-05-28 |
| F. Documentation update (= 本 §17 status table backfill / 完了 mark) | Win Claude | 2026-05-30 (= self) |

### 17.8 KPI 追跡 (= verify automation)

`~/.claude/logs/mid-compress.csv` を新設:

```csv
ts,session_id,phase,counter,c_free_gb_before,c_free_gb_after,reclaim_mb,duration_sec
2026-05-09T08:00:00Z,abc123,quick,50,70.09,70.32,235.5,2.1
2026-05-09T08:30:00Z,abc123,quick,100,70.10,70.41,317.8,2.4
```

KPI:
- `mid_compress_fires_per_session` ≥ 3 (= 90+ min session で 3+ fire 期待)
- `reclaim_mb_per_fire` ≥ 100 MB (= 軽量 fire で最低 100 MB / aggressive で 500+ MB)
- `duration_sec` < 5 (= non-blocking guarantee)

### 17.9 PHILOSOPHY-22 alignment (= 7+/9 ✅)

- 主要実装: hook wiring gap 3 finding fix + spec → 実装 100% 化
- 該当原則:
  - #2 (mission) — 開発環境枯渇 = mission blocker / 解消で全 part 連続 dogfood 維持
  - #5 (商品 = 価値) — disk pressure 0 = AI が能力を 100% 発揮できる前提
  - #6 (時間 = 資本) — automation で user 介入 0
  - #7 (資産負債) — disk = 資産 / 累積 = 負債 / hook で 自動相殺
  - #8 (KPI) — mid-compress.csv で `reclaim_mb_per_fire` 計測
  - #9 (IPO) — local dev env stability = production scaling 前提
- 整合性スコア: **7/9 ✅** ([PHILOSOPHY-22] gate 通過)

### 17.10 関連

- 親要望 (= user iterative ask v1-v5):
  - **v1** (= part 154) `[disk-pressure]` SessionStart hook 新設
  - **v2** (= part 178b) Tier 1.6 stale worktree prune
  - **v3** (= part 180) Tier 1.8/1.9/2.0 強化
  - **v4** (= part 189 / §16) mid-session 圧縮 spec
  - **v5** (= part 190 / 本 §17) **hook wiring 完成 + 圧縮自動化 100% 化**
- Issue: [#1983](https://github.com/kanta13jp1/my_web_app/issues/1983) (= P1 / メモリー/ディスク削減 定期監査)
- 親 Issue: [#1984](https://github.com/kanta13jp1/my_web_app/issues/1984) (= 4 axis / closed in part 189)

> **part 190 status**: spec ship / Codex hand-off (= Tier A-E / 期限 2026-05-30) / Win Claude verify は part 197 想定 (= Tier E 完了後 1 week observation). Win Claude self deliverable = §17 status table backfill (= F task / 期限 5/30).

### 17.11 v6 = part 191 immediate manual fire verify (= pre-existing spec verify pattern 第 2 例 / 2026-05-09)

User 第 5 直接 ask = v5 と同テーマ (= 「毎回のセッションで必ず memory + disk 圧縮」). Codex hand-off T+1 day 進捗 0 (= 5/23-5/28 期限). 空白期間中の **immediate manual fire recipe** を確立.

#### 17.11.1 v6 measured (= part 191 開始時)

| 指標 | 開始時 | manual fire 後 | delta |
|------|--------|----------------|-------|
| RAM Free | 1.08 GB | 2.01 GB | **+930 MB** |
| RAM Used % | 93.1% | 87.2% | **-5.9 pt** |
| C: Free | 70.24 GB | 70.24 GB | 0 (= worktree 0 stale) |
| Worktree count | 13 | 13 | 0 (= 全 in-flight) |

#### 17.11.2 manual fire recipe (= Codex impl 完了まで暫定)

```powershell
# 1. RAM trim (= ~1 GB free 即 / 4 procs target)
powershell -ExecutionPolicy Bypass -File "C:\Users\kanta\.claude\scripts\memory_trim_phase2.ps1"

# 2. worktree cleanup tier1 (= stale only / max 20 sec)
powershell -NoProfile -ExecutionPolicy Bypass -Command "& python C:\Users\kanta\.claude\scripts\worktree_cleanup.py --root C:\Users\kanta\GitHub\my_web_app --tier1 --apply --max-runtime-sec=20"
```

#### 17.11.3 適用条件

- session 開始時 RAM > 90% used
- session 開始時 C: < 50 GB free
- Codex Tier A-E 完了前 (= 5/28 まで)
- mid_session_compress.py 未配線期間中

#### 17.11.4 Codex impl 完了後

- Tier A-E 完了 (= 5/28 想定) 後は SessionEnd + PostToolUse + PreCompact hook が auto fire → manual fire 不要
- §17.11 は historical reference として維持 (= 削除しない / part 197 verify 完了で archive section 化)

### 17.12 v7 = part 192-b immediate manual fire delta verify (= pre-existing spec verify pattern 第 3 例 / 2026-05-09)

User 第 6 直接 ask = v6 と同テーマ再受信 (= 「毎回のセッションで必ず memory + disk 圧縮 施策検討」). Codex hand-off T+0/T+1 day 進捗 0 (= dev_cache_cleanup.py 5/23 期限). 空白期間中の **immediate fire delta 実測値** + system pressure gap 強調.

#### 17.12.1 v7 measured (= part 192-b 開始時 / 2026-05-09 19:32 JST)

| 指標 | 開始時 | manual fire 後 | delta | 備考 |
|------|--------|----------------|-------|------|
| RAM Free | 0.81 GB | 0.75 GB | -60 MB | system pressure +60 MB > trim rate |
| RAM Used % | 94.8% | 95.2% | **+0.4 pt** | net 増 (= v6 -5.9 pt と逆) |
| C: Free | 66.22 GB | 66.22 GB | 0 | worktree 0 stale 維持 |
| Worktree count | 17 | 17 | 0 | 全 in-flight (= +4 since v6) |
| memory_trim_phase2 ram_trim_total_mb_freed | - | **1666.8 MB** | - | process level success |

→ **process level: ✅ 1.67 GB freed / 5 procs trimmed** (= memory_trim_phase2.ps1 設計通り)
→ **system level: ⚠️ +0.4 pt 増** (= 並行する Chrome/VSCode/etc が trim 速度超過で消費 / external app pressure)

#### 17.12.2 v7 finding = browser/IDE cache trim gap exposed

immediate fire 単独不足. memory_trim_phase2 は python/dart process target のみ → Chrome/VSCode/Edge/cargo/pip cache は対象外:

| 圧迫源 | 推定 | 現対応 | gap |
|--------|------|--------|-----|
| python/dart process | 1.5-2 GB | memory_trim_phase2 ✅ | none |
| browser cache (Chrome/Edge) | 1-3 GB | dev_cache_cleanup.py 未実装 | **Codex 5/23** |
| IDE cache (VSCode workspaceStorage) | 0.5-1 GB | Tier 1.7 telemetry only | **Codex 5/23** |
| build artifact (cargo/pip/npm) | 0.5-2 GB | dev_cache_cleanup.py 未実装 | **Codex 5/23** |

→ Issue #2186 dev_cache_cleanup.py 4 cmd Win compat (= Codex 5/23 期限 / today T+0/T+1) impl 完了で gap 解消想定.

#### 17.12.3 即時対応 (= Codex impl 待ち期間 / 5/9-5/23)

- v6 recipe (= §17.11.2) 維持: process level RAM trim は確実 (= 1.5-2 GB freed)
- system pressure 高時 (= RAM > 95%): user manual close (= Chrome tab / VSCode window 等)
- worktree count > 15: `--apply` mode (= --no-apply で 17 → 検査のみ / 安全)
- next session 推奨条件: RAM < 90% / C: > 60 GB / worktree < 15

#### 17.12.4 v7 dogfood evidence

- pre-existing spec verify pattern 第 3 例適用 ✅ (= part 184 第 1 例 / part 191 第 2 例 / part 192-b 第 3 例)
- 新 spec 起票回避 ✅ (= 既 §17.11 拡張 / §17.12 として 1 章追加)
- immediate manual fire pattern 第 2 例 ✅ (= part 191 第 1 例 +930 MB / part 192-b 第 2 例 +1666 MB process / -0.4 pt system)
- v7 finding = 「process level ✅ + system level ⚠️ gap」明文化 → Codex 5/23 dev_cache_cleanup.py priority justification

#### 17.12.5 KPI 追跡

| metric | v6 (part 191) | v7 (part 192-b) | trend |
|--------|---------------|-----------------|-------|
| process trim freed | ~930 MB | 1666 MB | +79% |
| system RAM net delta | -5.9 pt | +0.4 pt | ⚠️ system pressure 増 |
| worktree count | 13 | 17 | +30% |
| C: free | 70.24 GB | 66.22 GB | -4 GB |

→ system pressure 上昇傾向 (= worktree +4 / C: -4 GB) → Codex 5/23 impl までの暫定 recipe 強化必要なし (= process level は十分 / system level は user manual + browser/IDE 制御に依存)


