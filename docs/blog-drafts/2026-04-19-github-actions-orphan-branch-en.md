---
title: "GitHub Actions Orphan Branch Accumulation — Designing blog-publish.yml for Protected Branches"
tags: GitHub,CI/CD,buildinpublic,GitHubActions,devops
published: false
---

# GitHub Actions Orphan Branch Accumulation

## The Problem: workflow_dispatch Can't Push to Protected Branches

My `blog-publish.yml` workflow auto-posts articles to Qiita and dev.to, then needs to flip `published: false` → `true` in the draft file and commit it back to main.

But GitHub's branch protection rules block direct pushes from `workflow_dispatch`:

```
error: GH006 Protected branch update failed for refs/heads/main.
```

### The Fix: Route Through a PR Branch

`workflow_dispatch` can't push to main directly, but creating a temporary branch and merging it works:

```yaml
# blog-publish.yml — update published status
- name: Update published status
  run: |
    BRANCH="blog-publish/${{ github.run_id }}-$(date +%Y%m%d-%H%M%S)"
    git checkout -b "$BRANCH"
    sed -i 's/^published: false/published: true/' "$DRAFT_PATH"
    git add "$DRAFT_PATH"
    git commit -m "docs: $DRAFT_PATH published:true"
    git push origin "$BRANCH"
    gh pr create --title "Blog published: $TITLE" \
      --body "Auto-merge" --base main --head "$BRANCH"
    gh pr merge --auto --squash
```

This creates a `blog-publish/<run_id>-YYYYMMDD-HHMMSS` branch and auto-merges it.

## The New Problem: Orphan Branches Never Get Cleaned Up

When auto-merge fails (or the merge step is skipped), the branch sticks around. After enough runs, you accumulate dozens of stale branches:

```bash
git branch -r | grep "blog-publish/"
# origin/blog-publish/24613652356-20260419-055202
# origin/blog-publish/24614707550-20260419-065252
# origin/blog-publish/24619748692-20260419-070413
# ... (30 more)
```

This slows down `git ls-remote`, pollutes CI logs, and makes branch management confusing.

### Cleanup Command

```bash
# Check accumulation per category
for pattern in "blog-publish/*" "cs-check-*" "ai-university-update/*" "daily-report-*"; do
  count=$(git ls-remote --heads origin "$pattern" | wc -l)
  echo "$count  $pattern"
done

# Merge and delete all blog-publish orphans
git fetch origin
for branch in $(git branch -r | grep "origin/blog-publish/" | sed 's|.*origin/||'); do
  git merge "origin/$branch" --no-edit 2>&1
  git push origin --delete "$branch" 2>&1
done
git pull --rebase origin main && git push origin HEAD:main
```

> **Note**: Always merge before deleting. The branch may contain `published:true` updates that haven't reached main yet.

### Other Patterns That Accumulate the Same Way

| Pattern | Source |
|---------|--------|
| `blog-publish/<id>-*` | blog-publish.yml |
| `cs-check-*` | cs-check.yml |
| `ai-university-update/*` | ai-university-update.yml |
| `daily-report-*` | daily-report.yml |
| `claude/*` | Claude Code Schedule |

All follow the same pattern: `workflow_dispatch` → can't push to main → PR branch → merge succeeds but branch cleanup is forgotten.

## Prevention: Prune in Your WF Health Check

I run a Rule17 WF health check at the start of each session. Adding orphan branch detection there means they never accumulate past a handful:

```bash
for pattern in "blog-publish/*" "cs-check-*" "ai-university-update/*"; do
  count=$(git ls-remote --heads origin "$pattern" | wc -l)
  if [ "$count" -gt 5 ]; then
    echo "⚠️ $pattern: $count branches — cleaning up"
    # ... cleanup commands
  fi
done
```

5+ orphans = cleanup trigger. At the session cadence I run (daily), this stays manageable.

## Key Lessons

1. **`workflow_dispatch` + branch protection** → always use PR branch strategy
2. **PR branch auto-merge** → always check if merge actually succeeded
3. **Orphan branches** → add periodic cleanup to your health check routine, not to each individual workflow

The PR-branch pattern is the right architecture. The cleanup discipline is what makes it not turn into a mess.

---
Building in public: https://my-web-app-b67f4.web.app/
#GitHubActions #CI/CD #buildinpublic #devops
