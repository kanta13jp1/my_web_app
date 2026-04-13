---
title: "How I Published 21 Technical Articles in One Day Using GitHub Actions + Supabase"
tags: GitHubActions,Supabase,automation,buildinpublic
published: true
---

# How I Published 21 Technical Articles in One Day Using GitHub Actions + Supabase

## The Problem

While building my Flutter Web + Supabase app, I kept writing draft articles but never publishing them. Every new feature gave me ideas for blog posts, but the manual posting process was tedious enough that I kept putting it off.

One day I realized I had 21 unpublished drafts sitting in `docs/blog-drafts/`:

```
docs/blog-drafts/
├── 2026-03-28-note-comments.md       # unpublished
├── 2026-03-31-app-feedback.md        # unpublished
├── 2026-04-01-workflow-automation.md # unpublished
... (21 total)
```

So I built a GitHub Actions workflow to solve this once and for all.

---

## The Solution: `blog-publish.yml` — One Command to Publish

```yaml
name: Blog Publish

on:
  workflow_dispatch:
    inputs:
      draft_path:
        description: 'Path to Japanese draft → Qiita'
        required: true
      draft_path_en:
        description: 'Path to English draft → dev.to (optional)'
        required: false
        default: ''
      platforms:
        description: 'Target platforms: qiita, devto, or qiita,devto'
        default: 'qiita,devto'
      dry_run:
        description: 'true=preview only, false=actually publish'
        default: 'false'
```

**5-step pipeline:**
1. **Step 2**: Extract title and tags from frontmatter
2. **Step 3**: Register record in Supabase `blog_posts` table
3. **Step 4**: Post via `schedule-hub` Edge Function to Qiita / dev.to
4. **Step 5**: Update `published: false` → `published: true` in the draft file
5. **Step 6**: Log the run to `schedule_task_runs` for monitoring

### Dispatch command (one line)

```bash
gh workflow run blog-publish.yml \
  --field draft_path="docs/blog-drafts/2026-04-12-my-topic.md" \
  --field draft_path_en="docs/blog-drafts/2026-04-12-my-topic-en.md" \
  --field platforms="qiita,devto" \
  --field dry_run="false"
```

---

## Architecture: Supabase Edge Function as the Publishing Hub

All platform API calls go through a single Supabase Edge Function called `schedule-hub`:

```typescript
// schedule-hub/index.ts
const publicActions = ["blog.auto_publish", "blog.create"];

case "blog.auto_publish": {
  const { title, content, platforms, tags } = body;
  const results: Record<string, unknown> = {};

  if (platforms.includes("qiita")) {
    results.qiita = await publishToQiita(title, stripFrontmatter(content), tags);
  }
  if (platforms.includes("devto")) {
    results.devto = await publishToDevTo(title, stripFrontmatter(content), tags);
  }
  return json({ results });
}
```

**Key design decision**: Adding the action to `publicActions` bypasses JWT auth, letting GitHub Actions call it directly with the SERVICE_ROLE_KEY. No token juggling needed.

### Stripping frontmatter automatically

Drafts contain Zenn/Qiita frontmatter that shouldn't appear in the published article. The Edge Function strips it server-side:

```typescript
function stripFrontmatter(content: string): string {
  if (!content.startsWith("---")) return content;
  const end = content.indexOf("---", 3);
  return end === -1 ? content : content.slice(end + 3).trim();
}
```

---

## Handling Dual-Language Publishing

I maintain separate files for Japanese (Qiita) and English (dev.to):

```
docs/blog-drafts/
├── 2026-04-13-sql-quoting-fix.md      # Japanese → Qiita
├── 2026-04-13-sql-quoting-fix-en.md   # English → dev.to
```

Step 4 of the workflow routes content to the right platform:

```yaml
# Japanese content → Qiita
if echo "$PLATFORMS" | grep -q "qiita"; then
  PAYLOAD=$(jq -n \
    --arg action "blog.auto_publish" \
    --arg title "$TITLE" \
    --arg content "$CONTENT_JP" \
    --arg platforms "qiita" \
    ...)
fi

# English content → dev.to (only if draft_path_en is provided)
if echo "$PLATFORMS" | grep -q "devto"; then
  if [ -n "$DRAFT_PATH_EN" ] && [ -f "$DRAFT_PATH_EN" ]; then
    CONTENT_EN=$(cat "$DRAFT_PATH_EN")
    TITLE_EN=$(grep '^title:' "$DRAFT_PATH_EN" | ...)
    PAYLOAD_EN=$(jq -n ... --arg platforms "devto" ...)
  fi
fi
```

---

## The Bash Shell Quoting Gotcha (Production Bug)

One thing that bit me: **never inject `${{ steps.outputs.value }}` directly into bash strings**.

```yaml
# DANGEROUS — breaks if title contains double-quotes
run: |
  TITLE="${{ steps.meta.outputs.title }}"

# SAFE — GitHub Actions substitutes ${{ }} before bash runs
env:
  ARTICLE_TITLE: ${{ steps.meta.outputs.title }}
run: |
  TITLE="$ARTICLE_TITLE"
```

GitHub Actions substitutes `${{ }}` expressions *before* the shell runs. If the value contains `"`, it terminates your bash string mid-way — causing confusing syntax errors that look unrelated to the title content.

I also found bash quoting artifacts (`'"'"'`) leaking into SQL migration files, causing `SQLSTATE 42601` in production. Always pass dynamic values through `env:` blocks.

---

## Step 5 Limitation: Branch Protection

The workflow pushes a `published: true` update to a branch, but `GITHUB_TOKEN` can't bypass branch protection (require PR):

| Approach | Result |
|----------|--------|
| `git push origin HEAD:main` | GH006 Protected branch |
| `gh api repos/.../merges POST` | HTTP 409 |
| `gh pr create` | GitHub Actions can't merge its own PRs |

**Current workaround**: Step 5 creates `blog-publish/<run_id>-<timestamp>` branch → merge locally:

```bash
git fetch origin
git merge origin/blog-publish/24330099575-20260413-160011 --no-edit
git push origin main
```

**Permanent fix**: Set a `BLOG_PAT` secret (Personal Access Token with bypass permission) and use it for the push step.

---

## Publishing 21 Articles in One Day

```bash
# Find all unpublished drafts
grep -rl "^published: false" docs/blog-drafts/ | sort

# Dispatch 3 at a time (parallel runs)
gh workflow run blog-publish.yml --field draft_path="..." --field platforms="qiita,devto"
gh workflow run blog-publish.yml --field draft_path="..." --field platforms="qiita,devto"
gh workflow run blog-publish.yml --field draft_path="..." --field platforms="qiita,devto"

# After completion, merge all published:true branches
git fetch origin
for branch in $(git branch -r | grep "blog-publish/"); do
  git merge "$branch" --no-edit
done
git push origin main
```

3 parallel dispatches × 7 rounds = 21 articles published in ~1 hour.

---

## Key Lessons

| Problem | Solution |
|---------|----------|
| Qiita 403 with empty tags | Always set a default tag |
| GitHub Actions auth (401) | Add action to `publicActions` array |
| Mixed Zenn/Qiita frontmatter | Parse both `tags:` and `topics:` |
| Branch protection blocks merge | Merge locally or use BLOG_PAT |
| Bash syntax error from title with `"` | Pass all GHA outputs through `env:` block |

---

## Summary

The `blog-publish.yml` + Supabase `schedule-hub` combo gives me a one-command publishing pipeline. Twenty-one drafts published in one session. Now every time I finish a feature, I write the article immediately and queue it for dispatch.

The key insight: **lower the activation energy for publishing**. If posting takes more than 30 seconds, you'll procrastinate. Make it one command.

---

Building in public: https://my-web-app-b67f4.web.app/

#GitHubActions #Supabase #automation #buildinpublic
