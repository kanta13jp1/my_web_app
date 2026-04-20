# 🧹 Stale Worktree Prune 依頼 (PS#6 → VSCode版)

**Date**: 2026-04-20 16:05 JST
**From**: PS版#6 (instance-ps6)
**To**: VSCode版 (main repo owner)
**Priority**: 🟢 LOW (cleanup task)

## Summary

`.claude/worktrees/` に random-name worktree が 8 本滞留 (最古 3 週間前 / 最新 17 分前)。
全て origin/main 反映済み or unique commit が別 SHA で merge 済みのため、
**local prune 可能** と audit 済み。

## Audit Result

| Worktree | Branch | Ahead | Behind | 最終 commit | 判定 |
| --- | --- | --- | --- | --- | --- |
| brave-visvesvaraya | claude/brave-visvesvaraya | 2 | 2088 | 3w ago | ✅ PR #293 で merge 済 |
| dazzling-lichterman-2143ae | claude/dazzling-lichterman-2143ae | 0 | 813 | 3d ago | ✅ safe |
| loving-murdock-f3b2e1 | claude/loving-murdock-f3b2e1 | 1 | 787 | 3d ago | ✅ c6aa9c1d で landed |
| nostalgic-jemison-3cabe0 | claude/nostalgic-jemison-3cabe0 | 0 | 559 | 2d ago | ✅ safe |
| objective-cannon-33031f | claude/objective-cannon-33031f | 0 | 884 | 3d ago | ✅ safe |
| sleepy-curran | feat-vanity-guard | 1 | 2451 | 3w ago | ✅ PR #294 で merge 済 |
| tender-banach-b0c85f | claude/tender-banach-b0c85f | 0 | 732 | 3d ago | ✅ safe |
| upbeat-euclid-08cda1 | claude/upbeat-euclid-08cda1 | 0 | 8 | 17m ago | ✅ safe |

**保持すべき worktree** (instance-*): ps / ps1-6 / vscode / win — アクティブなので触らない。

## 実行コマンド (VSCode版で main repo で実行)

```bash
cd C:/Users/kanta/GitHub/my_web_app

# worktree 削除 (force 不要 — uncommitted なし & 本体 merge 済)
git worktree remove .claude/worktrees/brave-visvesvaraya
git worktree remove .claude/worktrees/dazzling-lichterman-2143ae
git worktree remove .claude/worktrees/loving-murdock-f3b2e1
git worktree remove .claude/worktrees/nostalgic-jemison-3cabe0
git worktree remove .claude/worktrees/objective-cannon-33031f
git worktree remove .claude/worktrees/sleepy-curran
git worktree remove .claude/worktrees/tender-banach-b0c85f
git worktree remove .claude/worktrees/upbeat-euclid-08cda1

# branch 削除 (all are merged)
git branch -D claude/brave-visvesvaraya
git branch -D claude/dazzling-lichterman-2143ae
git branch -D claude/loving-murdock-f3b2e1
git branch -D claude/nostalgic-jemison-3cabe0
git branch -D claude/objective-cannon-33031f
git branch -D feat-vanity-guard
git branch -D claude/tender-banach-b0c85f
git branch -D claude/upbeat-euclid-08cda1

# prune metadata
git worktree prune
```

## 効果

- 8 worktree (推定 ~2-4GB) 解放
- `git worktree list` noise 減
- `git fetch` 軽量化

## Philosophy Alignment

- 原則 7 (資産 vs 負債): 負債 worktree を削除、資産 = clean repo
- 原則 6 (資本 = 時間): worktree list 見通し向上で判断時間短縮

## 備考

PS版#6 は main repo を直接触らないルール (worktree isolation)。
VSCode版が main repo 専任のため依頼化。
