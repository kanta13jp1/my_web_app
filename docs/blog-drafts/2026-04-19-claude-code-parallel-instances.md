---
title: "Claude Codeを10インスタンス並列実行 — git worktreeで作業分離する設計"
tags: ClaudeCode,GitHubActions,個人開発,buildinpublic
published: true
---

# Claude Codeを10インスタンス並列実行

## 問題: stashが他インスタンスの変更を消す

複数の Claude Code インスタンスを同じリポジトリで同時に動かすと、以下の問題が起きる:

```
インスタンスA: lib/pages/home_page.dart を編集中 (uncommitted)
インスタンスB: git pull --rebase を実行
              → Aの uncommitted changes がrebaseに巻き込まれて消える

インスタンスC: git stash を実行
              → 同じworkdirを共有しているため、AとBの変更も stash に入る
```

根本原因: **全インスタンスが同じworkdirを共有している**。

## 解決策: インスタンスごとに専用 worktree を割り当てる

```bash
# 各インスタンス用の worktree を作成
git worktree add .claude/worktrees/instance-ps1 -b claude/ps1-wip
git worktree add .claude/worktrees/instance-ps2 -b claude/ps2-wip
git worktree add .claude/worktrees/instance-vscode -b claude/vscode-wip
git worktree add .claude/worktrees/instance-win -b claude/win-wip
```

各インスタンスは自分の worktree のみ操作する。`git stash`・`git pull --rebase` の影響が他インスタンスに及ばない。

## 10インスタンス役割分担

```
PS版#1      → .claude/worktrees/instance-ps1  (CI/WF health監視)
PS版#2      → .claude/worktrees/instance-ps2  (ブログ投稿dispatch)
PS版#3      → .claude/worktrees/instance-ps3  (AI大学コンテンツ更新)
PS版#4      → .claude/worktrees/instance-ps4  (競合モニタリング)
PS版#5      → .claude/worktrees/instance-ps5  (on-callバグ修正)
PS版#6      → .claude/worktrees/instance-ps6  (バッチ処理/競馬)
VSCode版    → .claude/worktrees/instance-vscode (UI/デザイン)
Win版       → .claude/worktrees/instance-win   (AI大学/migration)
WEB版       → worktree不要 (GitHub MCPのみ)
📱スマホ版  → worktree不要 (GitHub MCPのみ)
```

## セットアップスクリプト

```bash
#!/bin/bash
# .claude/scripts/setup-instance-worktree.sh
set -e

INSTANCE=$1
REPO_ROOT=$(git rev-parse --show-toplevel)
WORKTREE_DIR="$REPO_ROOT/.claude/worktrees/instance-$INSTANCE"
BRANCH="claude/${INSTANCE}-wip"

if [ -d "$WORKTREE_DIR" ]; then
  echo "worktree already exists: $WORKTREE_DIR"
  exit 0
fi

git worktree add "$WORKTREE_DIR" -b "$BRANCH" 2>/dev/null || \
  git worktree add "$WORKTREE_DIR" "$BRANCH"

echo "created: $WORKTREE_DIR (branch: $BRANCH)"
```

```bash
# 使い方
bash .claude/scripts/setup-instance-worktree.sh ps1
bash .claude/scripts/setup-instance-worktree.sh vscode
```

## Pushのパターン

worktreeのブランチから main に push する:

```bash
# PS版#1 の worktree から
cd .claude/worktrees/instance-ps1

# 変更をcommit
git add docs/GROWTH_STRATEGY_ROADMAP.md
git commit -m "ci: Rule17 health check"

# origin/main に rebase してから push
git pull --rebase origin main
git push origin claude/ps1-wip:main
```

複数インスタンスが同時に push する場合は rebase 競合が起きる。その場合:

```bash
# 競合を検出してリトライ
git pull --rebase origin main 2>&1 | grep -q "CONFLICT" && \
  git rebase --abort && \
  git fetch origin main && \
  git rebase origin/main  # 手動解決
```

## .gitignoreに worktree ディレクトリを追加しない

worktree は git が管理するリポジトリの一部なので `.gitignore` に追加してはいけない。代わりに:

```bash
# .git/info/exclude (ローカルのみ・コミットされない)
.claude/worktrees/
```

または `git worktree list` で管理する:

```bash
git worktree list
# /path/to/my_web_app          abc1234 [main]
# /path/to/.claude/worktrees/instance-ps1  def5678 [claude/ps1-wip]
# /path/to/.claude/worktrees/instance-ps2  ghi9012 [claude/ps2-wip]
```

## 効果

| 問題 | worktree分離前 | worktree分離後 |
|---|---|---|
| stash干渉 | インスタンス間で変更が消える | **各自のstashは独立** |
| pull --rebase | 他インスタンスのuncommittedが消える | **自分の変更のみ影響** |
| 並行push | 競合・上書きリスク | **rebase後のmainが常に整合** |
| デバッグ | どのインスタンスが変更したか不明 | **branchで追跡可能** |

## まとめ

`git worktree` は複数プロセスが同じリポジトリを並行操作するときの標準的な解決策。Claude Code のように「複数インスタンスが自律的に作業する」環境では必須の設計パターン。インスタンスごとに worktree + wip branch を割り当てることで、作業が独立し、並行開発の衝突を根本から排除できる。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#ClaudeCode #GitWorktree #buildinpublic #個人開発
