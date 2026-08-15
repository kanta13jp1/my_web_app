---
name: blog-publish-cleanup
description: |
  手動 dispatch で作成される blog-publish/<run_id>-* orphan branch を main にマージ + 削除する。
  workflow_dispatch は GH006 branch protection を避けるため branch 経由で push するので、
  時間経過で orphan branch が溜まる。セッション冒頭 or Rule 17 check 時に実行推奨。
  Triggers on: "/blog-publish-cleanup", "orphan branch 削除", "blog-publish/ cleanup",
  "orphan branches を merge", "blog 片付け".
---

# Blog-Publish Orphan Branch Cleanup Skill

`blog-publish.yml` の手動 dispatch が残す `blog-publish/<run_id>-YYYYMMDD-HHMMSS` ブランチを
main に統合 → 削除する。

## いつ実行するか

- セッション開始時 (前セッションの dispatch 分が残っている場合)
- Rule 17 WF health check の一部として
- orphan branch 数が 5本 超えたら (git log ノイズ源)

## 実行ステップ

### Step 1: 今日の orphan branch 一覧

```bash
TODAY=$(date +%Y%m%d)
git ls-remote --heads origin "blog-publish/*$TODAY*" 2>&1
```

### Step 2: 一括 fetch + merge

```bash
BRANCHES=$(git ls-remote --heads origin "blog-publish/*$TODAY*" | awk '{print $2}' | sed 's|refs/heads/||')
for b in $BRANCHES; do
  git fetch origin "$b"
  git merge "origin/$b" --no-edit --no-ff -m "merge orphan: $b" || git merge --abort
done
```

### Step 3: Rebase + Push main

```bash
git pull --rebase origin main
git push origin HEAD:main
```

### Step 4: Remote branch 削除

```bash
for b in $BRANCHES; do
  git push origin --delete "$b"
done
```

### Step 5: EN frontmatter 補完

merged branch は JA のみ `published:true` 化する (`blog-publish.yml` Step 5 の旧版バグ)。
EN counterpart を一括補完:

```bash
for ja_file in docs/blog-drafts/*.md; do
  [[ "$ja_file" == *-en.md ]] && continue
  ja_pub=$(grep '^published:' "$ja_file" | head -1 | awk '{print $2}')
  if [ "$ja_pub" = "true" ]; then
    en_file="${ja_file%.md}-en.md"
    if [ -f "$en_file" ]; then
      en_pub=$(grep '^published:' "$en_file" | head -1 | awk '{print $2}')
      if [ "$en_pub" = "false" ]; then
        sed -i 's/^published: false/published: true/' "$en_file"
        git add "$en_file"
      fi
    fi
  fi
done
```

### Step 6: Commit + Push 補完分

```bash
if git diff --cached --quiet; then
  echo "No EN補完 needed"
else
  git commit -m "docs: blog-drafts EN frontmatter published:true 一括補完 (orphan branch cleanup)"
  git pull --rebase origin main && git push origin HEAD:main
fi
```

## 古い orphan branch (2026-04-12 以前)

数十本残っている (`2026-04-12-041025` 等)。コンテンツ既に main に入っているので削除可:

```bash
git ls-remote --heads origin "blog-publish/2026-04-12*" 2>&1 | awk '{print $2}' | sed 's|refs/heads/||' | \
  xargs -I{} git push origin --delete "{}"
```

**注意**: 古いorphan branch は commit hash が main と divergence している可能性。安全のため:

```bash
for b in $OLD_BRANCHES; do
  BRANCH_HEAD=$(git ls-remote --heads origin "$b" | awk '{print $1}')
  IN_MAIN=$(git branch -r --contains "$BRANCH_HEAD" origin/main | head -1)
  if [ -n "$IN_MAIN" ]; then
    git push origin --delete "$b"  # safe: commit は main に含まれる
  else
    echo "SKIP: $b (not merged into main)"
  fi
done
```

## 競合回避

- 他インスタンスが同時に merge すると冗長 merge commit が発生。PS scope で集中対応。
- 実行中に新規 dispatch が走ると orphan が追加される → Step 1 を再実行して追従。
