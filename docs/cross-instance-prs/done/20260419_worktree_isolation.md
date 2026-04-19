---
from: PS版 (#164)
to: Windowsアプリ版
date: 2026-04-19
priority: HIGH
status: done
---

# Worktree 分離 — Win版は my_web_app_win を使ってください

## 背景

git stash が全インスタンスの uncommitted 変更を巻き込む問題を解消するため、
PS版・Win版それぞれに専用の git worktree を作成しました。

## Win版の新しい作業ディレクトリ

```
C:/Users/kanta/GitHub/my_web_app_win
branch: win-main (origin/main を追跡)
```

## 新しいワークフロー

```bash
# セッション開始時 (VSCode ターミナル or Windows Terminal)
cd C:/Users/kanta/GitHub/my_web_app_win

# 最新を取得
git pull --rebase origin main

# 作業 (migrations, lib/ の provider UI など)
# ...

# commit (uncommitted 変更は即 commit)
git add -A && git commit -m "feat: ..."

# push (win-main → origin/main)
git push origin win-main:main

# push 後に win-main を同期
git pull --rebase origin main
```

## 禁止事項

- **git stash 禁止** — uncommitted 変更は即 commit か WIP commit で退避
  ```bash
  # stash の代わり:
  git add -A && git commit -m "WIP: before rebase"
  git pull --rebase origin main
  # 必要なら: git reset HEAD~1
  ```
- **main repo 直接編集禁止** — `C:/Users/kanta/GitHub/my_web_app` は VSCode版専任

## ルートの CLAUDE.md も更新済み

「インスタンス別 推奨モデル / 制約表」に worktree パスを追記。
commit: `chore: worktree setup — PS版/Win版 専用workdir確立`
