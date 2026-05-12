---
title: "Content Marketing for Solo Founders: What 70 Dev.to Posts Taught Me"
tags: ai,indiedev,buildinpublic,automation
published: true
---

# Content Marketing for Solo Founders: What 70 Dev.to Posts Taught Me

70 posts on dev.to. First 30 were handwritten. Last 40 with AI. Here's everything I learned.

## The Core Insight First

```
Don't "create" content — record what you build.
Implementation → Documentation → Post: zero friction.
```

When I wrote manually, "finding topics" was expensive. Once I started working with AI, I realized: **just write what you did**. The topics are always there. Writing them was the bottleneck.

## The Numbers After 70 Posts

```
Phase 1-3 (manual):   ~30 posts / 3 months = 10/month
Phase 4-10 (AI):      ~40 posts / 2 months = 20/month

Average views/post: ~400 (dev.to)
Best post: 2,100 views (Flutter Web SEO)
Follower growth: ~180
```

Output doubled. Not because AI "writes posts for me" — the **recording cycle got faster**.

## The "Record, Don't Create" Method

### Step 1: Build something

Build normally. Don't think about content while doing it.

### Step 2: Write a 5-minute implementation note

```
- What I built (1 line)
- Why I chose this approach (2-3 lines)
- Where I got stuck (bullet list)
- Final implementation pattern (code snippet)
```

This note becomes the article skeleton.

### Step 3: Expand to draft with AI

Hand the note to Claude:

```
Expand this implementation note into a dev.to article.
Target readers: Flutter/Supabase indie developers.

[note content]
```

Review the draft, add your perspective and code. Total time: under 30 minutes.

## How Parallel Draft Generation Works at Scale

In a 12-instance parallel development setup, there's a blog-dedicated instance (PS#2):

```
PS#2 responsibilities:
  - Collect implementation logs from dev instances' commits
  - Generate JA/EN draft pairs
  - Auto-dispatch to dev.to via blog-publish.yml
```

This means "build → commit → article" flows automatically. Recording cost approaches zero.

## What Makes Posts Perform on Dev.to

Looking at the top-performing posts across 70:

**1. Specific titles**

```
❌ "Using Supabase Auth in my app"
✅ "Supabase Auth in Flutter: JWT, Magic Links, and OAuth from Scratch"
```

Readers decide in 3 seconds whether this article has what they need.

**2. Conclusion first**

```dart
// Show code immediately
await supabase.auth.signInWithOtp(email: 'user@example.com');
```

This is a blog, not an academic paper. Lead with the answer.

**3. Code is the main character**

Text 2 : Code 8 ratio is fine. Developer readers came to see code.

**4. It actually runs in production**

"I think this design is good" loses to "here's what broke in my production system."

## The Routine That Made 70 Posts Possible

```
Monday: Implementation (log at each commit)
Wednesday: AI draft generation (JA/EN pair)
Friday: Dispatch → publish to dev.to
```

1 post/week is the minimum. 2 posts/week (JA+EN pairs = 4 effective posts) is ideal.

**The key**: Don't search for topics. Implementation *is* the topic. If you're building, there's infinite material.

## Why Solo Founders Should Do Content

```
Posts → Followers → Trust → Users

vs.

Ads → Cost → Uncertain ROI
```

Content is an asset. Ad spend disappears. 70 posts from today will still show up in search next year. $0-cost asset generating 10,000+ monthly views indefinitely.

The actual cost is lower than it looks. If you're building, you just need to record.

## The One Rule

**Record the implementation. The content writes itself.**

Every feature you ship, every bug you trace, every architecture decision you debate — that's a post. Stop treating content as a separate activity from building.

For a solo founder, content and product are the same loop: you build → you write → people find you → you build for them.
