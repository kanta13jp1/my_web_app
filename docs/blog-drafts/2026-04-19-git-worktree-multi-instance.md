---
title: "git worktreeで5インスタンスのClaude Codeが並行開発する — stash競合を根本解消"
tags: GitHubActions,個人開発,buildinpublic,AI,git
published: true
---

# git worktreeで5インスタンスのClaude Codeが並行開発する

## 問題: git stashが他インスタンスの作業を消す

5つのClaude Codeインスタンスが同じリポジトリで並行作業していると、
次の事故が発生する:

```
PS版: (uncommitted 変更なし)
Win版: lib/pages/horse_racing.dart を編集中 (uncommitted)
PS版: git stash → git pull --rebase → git stash pop
   ↑ このstashがWin版の変更を巻き込む → Win版の作業が消滅
```

## 解決策: 各インスタンスに専用 worktree

```bash
# 各インスタンス用ブランチ + worktree を作成
git worktree add .claude/worktrees/instance-vscode -b claude/vscode-wip origin/main
git worktree add .claude/worktrees/instance-ps     -b claude/ps-wip     origin/main
git worktree add .claude/worktrees/instance-win    -b claude/win-wip    origin/main
```

各インスタンスは **独立した作業ディレクトリ** を持つため、
git stash は自分の worktree にしか影響しない。

## 各インスタンスのワークフロー

```bash
# PS版 (毎セッション)
cd C:/path/to/repo/.claude/worktrees/instance-ps

# 最新を取得
git rebase origin/main

# 作業して即 commit
git add -A && git commit -m "docs: T-1#165 draft"

# origin/main に push
git push origin claude/ps-wip:main

# worktree を最新に同期
git rebase origin/main
```

## git stash 完全廃止: WIP commit パターン

rebase 前に uncommitted 変更がある場合も stash 不要:

```bash
# stash の代わり
git add -A && git commit -m "WIP: before rebase"
git rebase origin/main
# 必要なら: git reset HEAD~1 で unstaged に戻す
```

## worktree の検証 (セッション開始時必須)

```bash
git rev-parse --show-toplevel
# → /path/to/repo/.claude/worktrees/instance-ps ならOK
# → /path/to/repo (main repo) なら即 cd で移動
```

## Edit ツールのパス確認

Claude Code の Edit/Write ツールは絶対パスを使う。
**自 worktree のパスで始まることを必ず確認**:

```
✅ C:/path/to/repo/.claude/worktrees/instance-ps/docs/blog-drafts/xxx.md
❌ C:/path/to/repo/docs/blog-drafts/xxx.md  (main repo = 他インスタンス領域)
```

## まとめ

| Before | After |
|--------|-------|
| 全インスタンスが main repo で作業 | 各インスタンスが専用 worktree |
| git stash が全員に影響 | stash は自 worktree のみ |
| `git stash` 多用 | WIP commit で代替 |
| 事故: 他インスタンスの変更が消える | 独立 → 消滅なし |

5インスタンス並行開発の基盤として worktree 分離は必須。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#git #個人開発 #buildinpublic #AI #Claude
