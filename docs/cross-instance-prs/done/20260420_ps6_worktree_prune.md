# 🧹 Stale Worktree Prune (PS#6 → VSCode版)

**起票**: PS#6 (2026-04-20)  
**更新**: PS#6 S60 (2026-04-27) — 大半をPS#6自身で完了

---

## ✅ 完了済み (PS#6 S60 2026-04-27)

| 作業 | 結果 |
| --- | --- |
| git worktree metadata 削除 (gallant-lehmann / nervous-cray / sweet-blackwell / vibrant-cray) | ✅ git worktree prune済 |
| orphan dir 削除 (exciting-wu / frosty-hamilton / naughty-noether / blissful-nightingale) | ✅ PowerShell Remove-Item |
| leaderboard UI cross-instance-pr | ✅ VSCode が ef12a60b で実装済 → done/ 移動 |

## 🔲 残留 (VSCode版 or 次回起動後)

| worktree/branch | 状態 | 備考 |
| --- | --- | --- |
| `.claude/worktrees/cranky-chaplygin-f003b4/` | 空dir残留 (プロセスロック) | 次回再起動後に削除可 |
| `.claude/worktrees/sweet-blackwell-226190/` | 空dir残留 (プロセスロック) | 次回再起動後に削除可 |
| `C:/Users/kanta/GitHub/my_web_app_ci_fix` | codex/ci-final-field-fix ahead=0 | VSCode で `git worktree remove` |
| `C:/Users/kanta/GitHub/my_web_app_horse_fix` | codex/horse-learning-loop ahead=0 | VSCode で `git worktree remove` |

## 残作業コマンド (VSCode版 main repo で実行)

```bash
# プロセス終了後に空ディレクトリ削除
rm -rf .claude/worktrees/cranky-chaplygin-f003b4
rm -rf .claude/worktrees/sweet-blackwell-226190

# 外部 codex worktrees 削除
git worktree remove C:/Users/kanta/GitHub/my_web_app_ci_fix
git worktree remove C:/Users/kanta/GitHub/my_web_app_horse_fix
git branch -D codex/ci-final-field-fix
git branch -D codex/horse-learning-loop
```

## Philosophy Alignment

- 原則 7 (資産 vs 負債): 負債 worktree を削除、資産 = clean repo ✅ (大半完了)
