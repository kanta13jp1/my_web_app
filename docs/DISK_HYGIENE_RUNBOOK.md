# Disk Hygiene Runbook — 自分株式会社 (= Win版#132 part 154)

> **status**: ops runbook / 2026-05-05 / Win版#132 part 154
> **trigger**: C: free < 50 GB / G: free < 50 GB / 9 worktree fleet による継続圧迫
> **scope**: ローカル開発環境 (= Win Claude / Win Codex 2 instance + 9+ worktree fleet) のディスク逼迫を毎セッション自動軽減 + 週次手動深掘り

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
| ≥ 50 GB | 通常運転 | log のみ (= `~/.claude/logs/disk-cleanup-YYYYMMDD.log`) |
| 25-50 GB | report 書き出し | `~/cleanup_reports/disk_report_<ts>.md` (= 既存 cleanup_report_notify.ps1 が pickup) |
| 10-25 GB | **WARN** | `additionalContext` 経由で Claude に「`/disk-cleanup` 推奨」surface |
| < 10 GB | **ALERT** | `additionalContext` で「即座に `/disk-cleanup` 実行」surface (= ビルド失敗 risk) |

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
