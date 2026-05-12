# [cross-instance-pr] Tier 1.7 disk hog telemetry — `disk-cleanup.ps1` step 12 配線依頼

**To**: Win版 (Codex CLI) — 実装/修正PR/SQL/EF Deno/GHA role
**From**: Win版 (Claude Code) — Win版#132 part 179 (続き) / spec doc ship 完了
**Priority**: medium
**Date**: 2026-05-08
**Deadline**: 2026-05-22 (= 14 day grace / Issue #1984 axis A 継続強化)
**Related**: [Issue #1984](https://github.com/kanta13jp1/my_web_app/issues/1984) / [`docs/DISK_HYGIENE_RUNBOOK.md` §13](../DISK_HYGIENE_RUNBOOK.md#13-tier-17-disk-hog-telemetry--part-179-新設--observability-専用--自動-prune-なし)

## 背景

User 2026-05-08 part 179 ask: 「**毎回のセッションで必ず** メモリ + HDD 容量圧縮施策」継続検討.

part 179 audit 実測:
- `~/.cache/codex-runtimes/codex-primary-runtime` = **721.9 MB** / hygiene 非対象 / **prune 不可** (= Codex 起動 fail)
- `~/.claude/plugins/marketplaces/thedotmack` = **612.3 MB** / claude-mem plugin / hygiene 非対象 / 削除時 plugin 失効
- `~/AppData/Roaming/Code/User/workspaceStorage` = **249.4 MB** / VSCode dormant 後 obsolete だが復帰時必要

計 **~1.6 GB が hygiene 非対象 = 隠れ負債**. うち prune 候補 ~860 MB / 残 722 MB は不可.

詳細仕様: [`docs/DISK_HYGIENE_RUNBOOK.md` §13](../DISK_HYGIENE_RUNBOOK.md#13-tier-17-disk-hog-telemetry--part-179-新設--observability-専用--自動-prune-なし) 参照 (= 全 7 節).

## 依頼事項 (= Codex 実装範囲)

### 1. `~/.claude/hooks/disk-cleanup.ps1` step 12 配線

spec §13.2 のコード snippet (= MAJOR_DIRS_MB telemetry 5 metric log) をそのまま step 12 として末尾追加.

### 2. threshold 2 GB 超過時 WARN log

spec §13.4 の threshold check snippet 配線.

### 3. **自動 prune 実装しない** (= safety first)

`codex-runtimes` 削除 = Codex 起動 fail 致命. `marketplaces/thedotmack/plugin/` 削除 = claude-mem plugin 失効. **観測のみ / user 判断は手動**.

### 4. test 拡張

`tests/test_disk_cleanup_hook.py` 等 (= 既存あれば) で:
- 5 metric が log 出力されること
- threshold 超過時 WARN log 出力
- 既存 step 1-11 regression なし

## Acceptance criteria

- [ ] `~/.claude/hooks/disk-cleanup.ps1` step 12 = MAJOR_DIRS_MB telemetry 5 metric log 出力
- [ ] threshold 2 GB 超過時 WARN log
- [ ] 自動 prune 実装しない
- [ ] tests pass (= existing step 1-11 regression なし)
- [ ] PR description で「Issue #1984 axis A 継続強化 / Tier 1.7 telemetry only / DISK_HYGIENE_RUNBOOK §13 実装」明示

## 委譲外 (= Win Claude follow-up)

- 閾値超過 alert → GHA scheduled-tasks-monitor log scan auto-issue 起票連携 (= part 169 monitor cron 横展開)
- 観測 KPI 集計 (= 2 week 後 trend 確認)

## Reference

- spec: [`docs/DISK_HYGIENE_RUNBOOK.md` §13](../DISK_HYGIENE_RUNBOOK.md#13-tier-17-disk-hog-telemetry--part-179-新設--observability-専用--自動-prune-なし)
- Issue: [#1984](https://github.com/kanta13jp1/my_web_app/issues/1984)
- 並行 hand-off (= Tier 1.6): [`20260508_tier16_stale_worktree_prune_codex.md`](./20260508_tier16_stale_worktree_prune_codex.md) (= 期限 2026-05-22 / 同期間)
