---
title: "12インスタンス並行開発で衝突しない仕組み — git worktree 完全ガイド"
tags: AI,個人開発,automation,buildinpublic
published: true
---

# 12インスタンス並行開発で衝突しない仕組み — git worktree 完全ガイド

Claude Code 10インスタンス + Codex 2インスタンス = 計12インスタンスが同時に動いています。これで「ファイル競合」「マージ衝突」「誰が何を編集中か不明」という問題をゼロにした仕組みを公開します。

## 問題: 複数 AI が同じ repo を触ると何が起きるか

```
インスタンスA: lib/pages/landing_page.dart を編集中
インスタンスB: 同じファイルを別の修正で編集 → マージ衝突
インスタンスC: main で git pull → A の WIP を拾う → 動かない状態をデプロイ
```

ブランチ戦略だけでは足りない。同じ `main` ブランチで複数 AI が作業すると、必ず衝突する。

## 解決策: git worktree で物理的に分離

```bash
# 各インスタンス専用の worktree を作成
git worktree add .claude/worktrees/instance-ps1 -b claude/ps1-wip
git worktree add .claude/worktrees/instance-ps2 -b claude/ps2-wip
git worktree add .claude/worktrees/instance-vscode -b claude/vscode-wip
# ... 12インスタンス分
```

これにより:
- `instance-ps1/` に作業中のファイルが存在
- `instance-ps2/` に別の作業中ファイルが存在
- **同じファイルでも worktree が別なら衝突しない**

## worktree の仕組み

```
my_web_app/                    # main repo (統合・確認用のみ)
  .claude/
    worktrees/
      instance-ps1/            # PS#1 の作業領域
        lib/ → リアルファイル
        branch: claude/ps1-wip
      instance-ps2/            # PS#2 の作業領域
        lib/ → リアルファイル
        branch: claude/ps2-wip
      instance-vscode/         # VSCode版の作業領域
        lib/ → リアルファイル
        branch: claude/vscode-wip
```

各 worktree は**独立したブランチ**を持つ。`git add/commit` は各 worktree 内で完結。

## セッション開始プロトコル

```bash
# 各インスタンスはセッション開始時に実行
cd C:/Users/kanta/GitHub/my_web_app/.claude/worktrees/instance-ps2

# 最新 main を取り込む
git pull --rebase origin main

# 自分の担当を確認してから作業開始
```

`git stash` は **禁止**。複数 worktree 環境では stash が worktree 固有になり、別インスタンスが入ったとき消える可能性がある。WIP commit (`git commit -m "WIP"`) で退避する。

## push フロー

```bash
# 作業完了後
git add <files>
git commit -m "feat: ..."

# rebase してから push
git pull --rebase origin main
git push origin HEAD:main
```

**`git push origin HEAD:main`** が重要。`git push` だけだと `claude/ps2-wip` ブランチに push されて main に反映されない。

## 衝突が起きる唯一のケース

複数インスタンスが **同じファイルを同日に編集** して **両方が main に push** しようとしたとき:

```bash
# PS#4 が landing_page.dart を push
# PS#5 も同じファイルを修正して push しようとする
→ rebase conflict

# 解決策: push 前に必ず pull --rebase
git pull --rebase origin main
# → コンフリクト箇所を手動解決
git add <resolved-file>
git rebase --continue
git push origin HEAD:main
```

12インスタンス中、このケースが発生したのは月1-2回程度。**担当ファイルを事前に分離** (PS#4=競合ページ、PS#5=認証、PS#2=ブログ) することで最小化できる。

## インスタンス担当分離の設計

| インスタンス | 担当ファイル/ディレクトリ |
|---|---|
| VSCode版 | `lib/pages/` UI コンポーネント全般 |
| PS#1 | `.github/workflows/` Rule17 ヘルスチェック |
| PS#2 | `docs/blog-drafts/` T-1 コンテンツ |
| PS#3 | `supabase/migrations/*_seed_ai_university*` |
| PS#4 | `lib/pages/comparison_page.dart`, `web/sitemap.xml` |
| PS#5 | `lib/pages/` 認証ガード, `supabase/functions/` |
| PS#6 | `supabase/functions/schedule-hub/` 競馬AI |
| Win版 | `docs/`, `supabase/migrations/` schema変更 |

担当が重なるファイルは「片方が push したら、もう片方は pull --rebase してから」のルールで運用。

## Codex インスタンスの統合

Codex CLI は Claude Code とは別プロセスだが、同じ worktree 仕組みを使う:

```
.claude/worktrees/instance-codex1/  (branch: codex/codex1-wip)
.claude/worktrees/instance-codex2/  (branch: codex/codex2-wip)
```

Claude Code → cross-instance-pr を起票 → Codex がその worktree で実装 → PR → merge。

## 3ヶ月運用して分かったこと

**うまくいったこと**:
- ファイルレベルの衝突はほぼゼロ
- 各インスタンスが独立してコミット → git log が読みやすい
- `git log --oneline` でどのインスタンスが何をしたか一目瞭然

**失敗したこと**:
- ephemeral worktree (名前が毎回変わる) → pruned されて作業消失 → **固定名 `instance-*` に統一**
- migration timestamp が同日に競合 → 500刻みの offset ルールで解決

## まとめ

12インスタンス並行開発を安定させた核心は:
1. **git worktree** で物理的に作業領域を分離
2. **担当ファイルの事前分離** で衝突確率を最小化
3. **pull --rebase → push** の一貫したフロー
4. **stash 禁止・WIP commit 必須** の安全規則

「AIが競合する」問題は、人間のチーム開発と同じツール (git worktree) で解決できる。
