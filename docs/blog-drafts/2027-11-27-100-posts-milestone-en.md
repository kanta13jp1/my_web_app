---
title: "100 Posts on dev.to: 10 Things I Learned Writing About Indie Dev"
tags: ai,indiedev,buildinpublic,automation
published: true
---

# 100 Posts on dev.to: 10 Things I Learned Writing About Indie Dev

I just hit 100 posts on dev.to — Flutter, Supabase, AI APIs, and indie dev workflows. Here's what surprised me along the way.

## The 100 Posts Breakdown

```
By category:
  Flutter:          22 posts (state mgmt, animations, testing, Web perf)
  Supabase:         18 posts (Auth, RLS, Realtime, Edge Functions)
  AI/LLM:           20 posts (Claude API, prompt design, agents)
  Indie dev:        25 posts (KPIs, SEO, costs, marketing)
  GHA/automation:   15 posts (CI/CD, scheduling, security)

By language:
  English (EN): 50 posts (dev.to international)
  Japanese (JA): 50 posts (drafts toward Qiita/note)
```

## 10 Things Writing 100 Posts Taught Me

### 1. A Published Post Beats a Perfect Draft

My first 10 posts sat in drafts for weeks — "not quite ready yet." Looking back from post #100, quality grew linearly with volume. Done is better than perfect.

### 2. Write While Implementing — Not After

```
Bad pattern:
  implement → it works → "I'll write about it later" → 3 weeks pass → can't remember

Good pattern:
  write as you implement →
  every sticking point becomes the "problem" section of the post
```

### 3. Code Blocks Drive Reads

Analytics showed posts with code blocks get 2× the reads. A Flutter state management example I wrote "just for reference" turned into my most-visited post.

### 4. Specific Numbers in Titles Win on CTR

```
❌ "Flutter state management comparison"
✅ "Flutter State Management Compared: Provider vs Riverpod vs Bloc"

❌ "Cut indie dev costs"
✅ "Indie Dev Cost Management: Designing a $0→$100/Month Stack"
```

### 5. English Posts Reach a Global Audience

My English posts got 5× the impressions of Japanese ones. Technical writing translates well even with imperfect English — the code communicates.

### 6. Failure Stories Get Shared Most

Posts about mistakes ("3 products that failed", "10 lessons from failure") consistently outperformed success stories in shares. Failure is relatable.

### 7. Automation Keeps the Habit Alive

```yaml
# Weekly reminder if unpublished drafts pile up
on:
  schedule:
    - cron: '0 9 * * MON'
jobs:
  blog-reminder:
    steps:
      - run: |
          COUNT=$(find docs/blog-drafts -name "*-en.md" \
            | xargs grep -l "^published: false" | wc -l)
          echo "Unpublished drafts: $COUNT"
```

Building a system that reminds me when drafts stack up cut "too busy to post" gaps significantly.

### 8. Tags Matter — dev.to Silently Caps at 4

dev.to only applies the first 4 tags from your frontmatter — extra tags are dropped without warning. Always put specific tags (flutter, supabase) before generic ones (webdev, programming).

### 9. Series Format Increases Completion Rate

Writing "Phase X" series posts is far easier to sustain than standalone posts. Zero decision cost for "what do I write next." The series structure carries you forward.

### 10. Writing Forces Real Understanding

Every time I tried to write about something I "understood," I discovered gaps. Supabase RLS row policies and Claude API Prompt Caching both only became fully clear to me when I had to explain them in writing.

## Toward the Next 100

```
Goal: 200 posts on dev.to (within 1 year)
New topics:
  - AI agent production case studies
  - Flutter + Supabase real-world ops lessons
  - Indie SaaS monetization in the open

More automation:
  - GHA weekly draft generation
  - Auto-measure SEO impact post-publish
```

100 is a checkpoint. The next 100 will focus on tightening the "write → get read → improve" cycle.

---

**All 100 posts**: [dev.to/kanta13jp1](https://dev.to/kanta13jp1)

