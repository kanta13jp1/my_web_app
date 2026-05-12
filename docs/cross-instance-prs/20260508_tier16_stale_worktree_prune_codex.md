# [cross-instance-pr] Tier 1.6 SessionStart-integrated stale worktree prune — `worktree_cleanup.py --tier1` mode 追加依頼

**To**: Win版 (Codex CLI) — 実装/修正PR/SQL/EF Deno/GHA role
**From**: Win版 (Claude Code) — Win版#132 part 178 / spec doc ship 完了
**Priority**: medium
**Date**: 2026-05-08
**Deadline**: 2026-05-22 (= 14 day grace / Issue #1984 axis A 強化分)
**Related**: [Issue #1984](https://github.com/kanta13jp1/my_web_app/issues/1984) / [`docs/DISK_HYGIENE_RUNBOOK.md` §12](../DISK_HYGIENE_RUNBOOK.md)

## 背景

User 2026-05-08 ask: **「毎回のセッションで必ず メモリやハードディスク容量を圧縮する施策」**.

現状 `scripts/worktree_cleanup.py` = **weekly cron 経由のみ**. 17 worktree / 2.28 GB 蓄積 (= part 178 実測). SessionStart 統合で漸増を毎回 trim 化.

詳細仕様は [`docs/DISK_HYGIENE_RUNBOOK.md` §12](../DISK_HYGIENE_RUNBOOK.md) 参照.

## 依頼事項 (= Codex 実装範囲 / scope 明確)

### 1. `scripts/worktree_cleanup.py` 拡張

既存 weekly mode 維持しつつ `--tier1` mode 追加:

```bash
python scripts/worktree_cleanup.py --tier1 --apply --max-runtime-sec=15
```

### 2. `--tier1` mode 仕様

| 条件 (AND) | 実装方法 |
|---|---|
| `git worktree list --porcelain` 列挙 | subprocess |
| branch merged-to-main | `git branch --merged main --list <branch>` 判定 |
| idle > 7 days | `os.stat(worktree_dir).st_mtime` で latest mtime 算出 |
| size > 100 MB | `du -sb` 等で集計 |
| current session worktree != target | `$PWD` から `git rev-parse --show-toplevel` 比較 |
| `.git/worktrees/<name>/locked` 不在 | `os.path.exists` |
| branch 名 `codex/*` skip | string prefix check (= [INSTANCE-ROLES] 尊重) |
| detached HEAD skip | `git -C <path> symbolic-ref HEAD` 失敗時 skip |
| uncommitted change skip | `git -C <path> status --porcelain` 出力空 check |

### 3. Action

`git worktree remove --force <path>` + 完了後 `git worktree prune`.

### 4. Output (= hook 連携用)

stdout に必ず 1 行 `reclaimed_mb=<int>` 出力 (= disk-cleanup.ps1 が regex parse). dry-run/apply 両方で出力 (dry-run は予測値).

### 5. Safety cap

- `--max-runtime-sec=15` 必須 (= SessionStart 30 sec budget 圧迫回避)
- timeout 到達時は graceful exit (= 部分 prune OK / 残りは次回 session)
- exception で全 skip (= hook が silently catch する想定)

### 6. Test

`tests/test_worktree_cleanup.py` 拡張 — `--tier1 --dry-run` で:
- current session worktree 絶対 skip
- `codex/*` branch 絶対 skip
- detached HEAD 絶対 skip
- merged branch + idle 7+ day + size 100+ MB のみ target list 出力

## 委譲外 (= Win Claude follow-up session 担当)

- `~/.claude/hooks/disk-cleanup.ps1` step 11 配線 (= home dir 編集権限が Codex repo 内では不可)
- 観測 KPI 集計 (= 2 week 後 reclaim_MB 確認)

## Acceptance criteria

- [ ] `python scripts/worktree_cleanup.py --tier1 --dry-run` がエラーなく target list 出力
- [ ] `--apply` で実際に prune + `reclaimed_mb=<int>` stdout
- [ ] `--max-runtime-sec=15` で graceful timeout
- [ ] tests pass (= existing weekly mode regression なし)
- [ ] PR description で「Issue #1984 axis A 強化 / DISK_HYGIENE_RUNBOOK §12 実装」明示

## Reference

- spec: [`docs/DISK_HYGIENE_RUNBOOK.md` §12](../DISK_HYGIENE_RUNBOOK.md#12-tier-16-sessionstart-integrated-stale-worktree-prune--part-178-新設--毎セッション必ず要件-v2)
- Issue: [#1984](https://github.com/kanta13jp1/my_web_app/issues/1984)
- 既存 weekly mode: `scripts/worktree_cleanup.py` + `.github/workflows/worktree-cleanup-cron.yml`

---

✅ Win版 (Claude Code) part 178 / 2026-05-08 09:55 JST ship
