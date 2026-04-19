---
title: "GitHub Actions orphan branch が溜まり続ける問題 — blog-publish.yml の設計と管理"
tags: GitHub,CI/CD,個人開発,buildinpublic,GitHubActions
published: false
---

# GitHub Actions orphan branch が溜まり続ける問題

## 問題: `workflow_dispatch` から push すると保護ブランチに弾かれる

`blog-publish.yml` は技術記事を Qiita/dev.to に自動投稿した後、
`published: false` → `true` に書き換えて git push したい。

しかし GitHub の protected branch ルールで main への直接 push は禁止されている。

```
error: GH006 Protected branch update failed for refs/heads/main.
```

### 解決策: orphan branch 経由で PR を作る

`workflow_dispatch` からは直接 main に push できないが、
**一時 branch を作って merge** する方法なら通る。

```yaml
# blog-publish.yml の published:true 更新ステップ
- name: Update published status
  run: |
    BRANCH="blog-publish/${{ github.run_id }}-$(date +%Y%m%d-%H%M%S)"
    git checkout -b "$BRANCH"
    sed -i 's/^published: false/published: true/' "$DRAFT_PATH"
    git add "$DRAFT_PATH"
    git commit -m "docs: $DRAFT_PATH published:true"
    git push origin "$BRANCH"
    gh pr create --title "Blog published: $TITLE" --body "Auto-merge" --base main --head "$BRANCH"
    gh pr merge --auto --squash
```

これで `blog-publish/<run_id>-YYYYMMDD-HHMMSS` ブランチが作られ、
自動 merge される。

## 問題: orphan branch が溜まり続ける

自動 merge に失敗すると branch が残り続ける。
30本を超えると `git ls-remote` が遅くなり、CI ログが汚れる。

### 定期クリーンアップコマンド

```bash
# 溜まり具合を確認
git ls-remote --heads origin 'blog-publish/*' | wc -l

# まとめてマージして削除
git fetch origin
for branch in $(git branch -r | grep "origin/blog-publish/" | sed 's|.*origin/||'); do
  git merge origin/$branch --no-edit 2>&1
  git push origin --delete "$branch" 2>&1
done
git pull --rebase origin main && git push origin HEAD:main
```

### 他のパターンも同様

| orphan branch パターン | 発生源 |
|----------------------|-------|
| `blog-publish/<id>-*` | blog-publish.yml |
| `cs-check-*` | cs-check.yml |
| `ai-university-update/*` | ai-university-update.yml |
| `daily-report-*` | daily-report.yml |
| `claude/*` | Claude Code Schedule |

全て同じパターン: `workflow_dispatch` → protected branch 回避 → PR branch → merge 後 branch残留。

## 管理コマンドをまとめる

```bash
# 各カテゴリの orphan 数を一発確認
for pattern in "blog-publish/*" "cs-check-*" "ai-university-update/*" "daily-report-*" "claude/*"; do
  count=$(git ls-remote --heads origin "$pattern" | wc -l)
  echo "$count $pattern"
done
```

5本超で自動削除が安全な目安。

## まとめ

`workflow_dispatch` + protected branch の組み合わせでは:
1. 直接 push はできない
2. PR branch → auto-merge が正解
3. merge 後の cleanup を忘れずに

cleanup を毎セッションの Rule17 (WF health check) に組み込んでおくと積み残しがない。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#GitHubActions #CI/CD #buildinpublic #個人開発
