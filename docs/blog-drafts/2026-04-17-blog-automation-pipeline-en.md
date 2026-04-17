---
title: "Automating Technical Blog Publishing: GitHub Actions + Supabase Edge Function Pipeline"
tags: Flutter,Supabase,buildinpublic,DevOps,automation
published: false
---

# Automating Technical Blog Publishing: GitHub Actions + Supabase Edge Function Pipeline

## The Problem

Writing code and writing about it are separate workflows. After a productive coding session, you've made 10 commits — but publishing a Qiita article and a dev.to post takes another hour. Multiply by 100 articles and the bottleneck is obvious.

[自分株式会社](https://my-web-app-b67f4.web.app/) has published **99+ technical articles** on Qiita and dev.to. Here's the automated pipeline that made it possible.

---

## Pipeline Overview

```
git commit (feature)
      ↓
blog-draft.yml (daily 08:00 JST)
→ generates JA + EN drafts from git log
→ saves to docs/blog-drafts/YYYY-MM-DD.md
      ↓
blog-publish.yml (manual dispatch or schedule)
→ reads draft markdown
→ calls blog-auto-publisher EF
→ posts to Qiita API + dev.to API
→ updates blog_posts table (status: posted)
```

Four components: two GitHub Actions workflows, one Supabase Edge Function, one PostgreSQL table.

---

## Component 1: Draft Generation (blog-draft.yml)

Runs daily at 08:00 JST. Reads 7 days of git log and generates drafts:

```yaml
- name: Generate blog drafts
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
  run: |
    COMMITS=$(git log --oneline --since="7 days ago")
    if [ -z "$COMMITS" ]; then exit 0; fi

    DATE=$(date +%Y-%m-%d)
    DRAFT_PATH="docs/blog-drafts/$DATE.md"
    DRAFT_PATH_EN="docs/blog-drafts/$DATE-en.md"

    # Generate JA draft via Claude API
    python scripts/generate_draft.py \
      --commits "$COMMITS" \
      --lang ja \
      --output "$DRAFT_PATH"

    # Generate EN draft
    python scripts/generate_draft.py \
      --commits "$COMMITS" \
      --lang en \
      --output "$DRAFT_PATH_EN"

    git add "$DRAFT_PATH" "$DRAFT_PATH_EN"
    git commit -m "自動: ブログ下書き $DATE (日本語+英語)"
    git push origin main
```

The draft has `published: false` in the frontmatter — the publish step flips it to `true`.

---

## Component 2: blog_posts Table

```sql
CREATE TABLE blog_posts (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  title           text        NOT NULL,
  draft_path      text        NOT NULL,
  status          text        NOT NULL DEFAULT 'draft',
    -- draft | posted | skipped
  target_platforms text[],
    -- ['qiita', 'devto']
  posted_at       timestamptz,
  url             text,
  created_at      timestamptz NOT NULL DEFAULT now()
);
```

`status = 'posted'` is **irreversible** — the EF checks this to prevent double-posting. If you need to re-post (e.g., major edit), insert a new row.

---

## Component 3: blog-auto-publisher Edge Function

Called by `blog-publish.yml`. Handles the actual API calls:

```typescript
// blog-auto-publisher/index.ts
const { action, id, content, tags } = await req.json();

if (action === 'auto_publish') {
  const results: Record<string, { url?: string; error?: string }> = {};

  // Check for duplicate post
  const { data: existing } = await supabase
    .from('blog_posts')
    .select('status')
    .eq('id', id)
    .single();

  if (existing?.status === 'posted') {
    return new Response(JSON.stringify({ ok: false, reason: 'already_posted' }));
  }

  // Post to Qiita
  if (platforms.includes('qiita')) {
    const qiitaRes = await fetch('https://qiita.com/api/v2/items', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${Deno.env.get('QIITA_ACCESS_TOKEN')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        title,
        body: content,
        tags: tags.map(t => ({ name: t })),
        private: false,
      }),
    });
    if (qiitaRes.ok) {
      const data = await qiitaRes.json();
      results.qiita = { url: data.url };
    } else {
      results.qiita = { error: `HTTP ${qiitaRes.status}` };
    }
  }

  // Post to dev.to
  if (platforms.includes('devto')) {
    const devtoRes = await fetch('https://dev.to/api/articles', {
      method: 'POST',
      headers: {
        'api-key': Deno.env.get('DEVTO_API_KEY')!,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        article: { title, body_markdown: content, tags, published: true },
      }),
    });
    if (devtoRes.ok) {
      const data = await devtoRes.json();
      results.devto = { url: data.url };
    } else {
      results.devto = { error: `HTTP ${devtoRes.status}` };
    }
  }

  // Update status
  const anySuccess = Object.values(results).some(r => r.url);
  if (anySuccess) {
    await supabase
      .from('blog_posts')
      .update({ status: 'posted', posted_at: new Date().toISOString(), url: results.qiita?.url ?? results.devto?.url })
      .eq('id', id);
  }

  return new Response(JSON.stringify({ ok: anySuccess, results }));
}
```

---

## Component 4: blog-publish.yml (Manual Dispatch)

The workflow accepts a draft path and dispatches to the EF:

```yaml
on:
  workflow_dispatch:
    inputs:
      draft_path:
        description: 'JA draft path (docs/blog-drafts/YYYY-MM-DD.md)'
        required: true
      draft_path_en:
        description: 'EN draft path (optional, for dev.to)'
        required: false
      platforms:
        description: 'Platforms: qiita, devto, or qiita,devto'
        default: 'qiita,devto'
      dry_run:
        description: 'Dry run (skip actual posting)'
        default: 'false'
```

Key step: register in `blog_posts` first, then call the publisher:

```yaml
- name: Step 3 - Register in blog_posts table
  id: register
  run: |
    RESPONSE=$(curl -s -w "\n%{http_code}" \
      -X POST "$SUPABASE_URL/functions/v1/blog-post-manager" \
      -H "Authorization: Bearer $SUPABASE_KEY" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg title "$TITLE" --arg path "$DRAFT_PATH" \
          '{action: "register", title: $title, draft_path: $path}')")
    POST_ID=$(echo "$RESPONSE" | head -1 | jq -r '.post.id')
    echo "post_id=$POST_ID" >> $GITHUB_OUTPUT

- name: Step 4 - Publish to platforms
  run: |
    CONTENT=$(cat "$DRAFT_PATH_EN")
    curl -X POST "$SUPABASE_URL/functions/v1/blog-auto-publisher" \
      -H "Authorization: Bearer $SUPABASE_KEY" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg id "$POST_ID" --arg content "$CONTENT" \
          '{action: "auto_publish", id: $id, content: $content}')"
```

---

## Qiita Rate Limit: The Hard Part

Qiita enforces a **~4 posts/day** daily limit. After that, the API returns 429 until midnight JST (15:00 UTC). The workflow handles it gracefully:

```yaml
- name: Step 4 - Publish to platforms
  continue-on-error: true  # 429 doesn't fail the workflow
  run: |
    HTTP_CODE=$(...)
    if [ "$HTTP_CODE" = "429" ]; then
      echo "⚠️ Qiita 429: daily limit reached. Retry after 15:00 UTC."
      echo "qiita_url=" >> $GITHUB_OUTPUT
    fi
```

The `blog_posts.status` stays `'draft'` on 429. A retry dispatch the next day picks it up.

---

## Bulk Backfill: Publishing Old Drafts

For a backlog of 90 drafts, `blog-backfill.yml` dispatches them in batches:

```bash
# Dispatch all unpublished EN drafts to dev.to
for f in docs/blog-drafts/*-en.md; do
  published=$(grep '^published:' "$f" | awk '{print $2}')
  if [ "$published" = "false" ]; then
    gh workflow run blog-publish.yml \
      -f draft_path_en="$f" \
      -f platforms="devto" \
      -f dry_run="false"
    sleep 3  # avoid API burst
  fi
done
```

`sleep 3` between dispatches — dev.to's API doesn't rate-limit as aggressively as Qiita, but burst protection still matters.

---

## Summary

| Component | Purpose |
|-----------|---------|
| `blog-draft.yml` | Auto-generates JA+EN drafts from git log (daily) |
| `blog_posts` table | Tracks status, prevents double-posting |
| `blog-auto-publisher` EF | API calls to Qiita + dev.to, updates status |
| `blog-publish.yml` | Manual dispatch with platform selection + dry run |

The result: write code, get articles. 99+ posts, one pipeline.

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #DevOps #automation
