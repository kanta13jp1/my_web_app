---
title: "git worktreeブランチからmainに直push — 複数インスタンス衝突リカバリ完全版"
tags: ClaudeCode,git,buildinpublic,個人開発
published: false
---

# git worktreeブランチからmainに直push

## TL;DR

Claude Code を複数インスタンスで動かす場合、各インスタンスの `wip` ブランチから `origin/main` に直接 push する運用が最もシンプル。衝突時は `git pull --rebase origin main` 一発でリカバリできる。

## 前提: ワークツリー構成

```
my_web_app/
  .claude/worktrees/
    instance-ps1/   ← claude/ps1-wip ブランチ
    instance-ps2/   ← claude/ps2-wip ブランチ
    instance-vscode/ ← claude/vscode-wip ブランチ
```

各インスタンスは自分の `wip` ブランチで作業し、`origin/main` に push するときだけ主線に合流する。

## push コマンドの 3 パターン

### パターン 1: `HEAD:main` (推奨)

```bash
git push origin HEAD:main
```

現在チェックアウト中のブランチを `origin/main` に push する。ブランチ名を覚えなくていいのがメリット。

### パターン 2: ブランチ名を明示

```bash
git push origin claude/ps1-wip:main
```

スクリプトや CI で使う場合はこちらが安全。`HEAD` が何を指しているか不明な状況でも確実に動く。

### パターン 3: ワークツリー外から push

```bash
git -C .claude/worktrees/instance-ps1 push origin HEAD:main
```

メインリポジトリのディレクトリから別インスタンスの変更を push するときに使う。

## 衝突リカバリ手順

並行インスタンスが同時に push すると、後から push したほうが弾かれる:

```
! [rejected]        claude/ps1-wip -> main (non-fast-forward)
error: failed to push some refs
hint: Updates were rejected because the remote contains work that you do
hint: not have locally.
```

**標準リカバリ (1 コマンド)**:

```bash
git pull --rebase origin main && git push origin HEAD:main
```

`rebase` なので merge コミットが発生しない。ログがきれいに保てる。

## 衝突が多発するパターンと対策

### ROADMAP.md への同時追記

`docs/GROWTH_STRATEGY_ROADMAP.md` は全インスタンスが毎セッション末尾に追記するため、最も衝突が多いファイル。

**対策**: インスタンスごとにセクションを固定する。

```markdown
### PS版#1 セッション記録

### PS版#2 セッション記録

### VSCode版 セッション記録
```

別インスタンスのセクションには触れないため、rebase での自動マージ成功率が上がる。

### migration ファイルのタイムスタンプ衝突

```
20260419220000_seed_foo.sql   ← PS版#1 が生成
20260419220000_seed_bar.sql   ← Win版 が同時生成
```

同じタイムスタンプになると Supabase deploy で `duplicate key` エラーが出る。

**対策**: migration ファイルを作る前に `ls supabase/migrations/ | grep $(date +%Y%m%d)` でその日の最後のファイルを確認し、1 秒ずらす。

```bash
# 現在の最大タイムスタンプを確認
ls supabase/migrations/ | grep 20260419 | sort | tail -1
# → 20260419220000_seed_foo.sql

# 新しいファイルは +10秒
touch supabase/migrations/20260419220010_seed_bar.sql
```

### WIP ブランチが mainより大幅に遅れている場合

長時間作業して `origin/main` が 20 コミット以上進んでいると、rebase の conflict が増える。

**診断**:

```bash
git log --oneline claude/ps1-wip..origin/main | wc -l
# 20 以上なら fetch してから確認
```

**対策**: conflict が 3 件以上なら手動マージに切り替える。

```bash
git rebase --abort
git fetch origin
git merge origin/main  # merge commit を許容する
# conflict を手動解決
git push origin HEAD:main
```

## まとめ

| ケース | コマンド |
|---|---|
| 通常 push | `git push origin HEAD:main` |
| rejected 後のリカバリ | `git pull --rebase origin main && git push origin HEAD:main` |
| conflict が多い場合 | `git rebase --abort && git merge origin/main` → 手動解決 |
| migration タイムスタンプ確認 | `ls supabase/migrations/ \| grep $(date +%Y%m%d) \| sort \| tail -1` |

複数インスタンス並行開発は衝突そのものを完全には避けられない。でも `rebase + direct push to main` パターンを一貫させることで、「衝突があっても 30 秒でリカバリできる」状態を維持できる。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#ClaudeCode #git #buildinpublic #個人開発
