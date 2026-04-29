---
title: "Indie Dev Launch Strategy — Getting Traction on ProductHunt, HackerNews, and Reddit"
tags: indiedev,webdev,buildinpublic,flutter
published: true
---

# Indie Dev Launch Strategy — Getting Traction on ProductHunt, HackerNews, and Reddit

Shipping is only half the battle. Getting people to notice, try, and talk about your indie project requires a deliberate launch strategy. In this article I'll walk through the pre-launch checklist, ProductHunt mechanics, the HN Show HN format, Reddit community rules, and how to coordinate everything on launch day without burning out.

## Pre-Launch Checklist

Start at least two weeks before launch. Rushing this almost always results in embarrassing bugs on your biggest traffic day.

```
LANDING PAGE
□ Hero headline — one sentence: "X for people who Y"
□ 3–5 screenshots or a short demo video (< 90 seconds)
□ FAQ section (minimum 5 questions)
□ Contact / feedback form or email
□ OG image (1200×630 px, < 300 KB)
□ Mobile layout verified on real device
□ Core Web Vitals: LCP < 2.5s, CLS < 0.1
□ Privacy policy + cookie consent (GDPR)

PRODUCT QUALITY
□ No crash-level bugs in the happy path
□ Onboarding completes in ≤ 3 steps
□ Error messages are clear and actionable
□ Works on iOS Safari (the hardest target)

SOCIAL READINESS
□ X / Twitter bio updated, pinned tweet ready
□ ProductHunt account created (7+ days old)
□ HN / Reddit account age ≥ 7 days
□ Email list for announcing to existing contacts

ANALYTICS
□ Event tracking for signups + first key action
□ Error monitoring (Sentry / LogRocket)
□ Uptime monitoring (BetterUptime / Checkly)
```

## ProductHunt Strategy

### Timing

ProductHunt's daily leaderboard resets at **midnight PST**. The best submission window is **Tuesday–Thursday at 00:01–00:30 PST** — enough upvotes to gain momentum before the US wakes up, without the heavy competition of Monday or the dead zone of weekends.

What to avoid:
- **Monday** — heaviest competition, lowest upvote-per-impression rate
- **Friday–Sunday** — viewership drops 30–40%
- **Any day Apple or OpenAI ships something** — you'll be buried

### Finding a Hunter

A well-connected hunter posting on your behalf can generate 2–5× the initial upvotes compared to self-posting. The first 100–200 upvotes in the first two hours determine whether you crack the front page.

```
How to find hunters:
1. Browse PH's top hunters list (filter by "last 30 days")
2. Search Twitter: site:producthunt.com "hunted by" + your category
3. Post in Indie Hackers "Looking for a Hunter" thread
4. Find who hunted similar tools in your space

Outreach template:

Subject: Would you hunt [Product] on ProductHunt?

Hi [Name],

I've been following your launches — the way you support 
indie devs is genuinely inspiring.

I'm launching [Product Name] on [proposed date]:
→ [One line: what it does and who it's for]
→ [One line: the most interesting/unusual thing about it]

Demo: [URL]
Assets (logo, screenshots, copy): [Drive link]

No pressure at all — totally understand if you're busy.
Would a 10-min call help?

Thanks,
[Your name]
```

### Crafting Your Launch Content

Your tagline has 60 characters. Your thumbnail is 240×240 px. Make them count.

```
Tagline formulas that work:
• "[Action] [thing] without [pain]"
  → "Manage tasks without switching apps"
• "The [category] for [specific audience]"
  → "The life OS for indie developers"
• "[Number] tools replaced by one"
  → "Notion + MoneyForward + Slack in one Flutter app"

Screenshot sequence (4 minimum):
1. Hero — the one screen that tells the whole story
2. Key feature #1 in use (real data, not mockup)
3. Key feature #2
4. Pricing / availability / CTA

Maker comment structure:
1. Origin story (2–3 sentences — make it human)
2. What it does — 3 bullet points
3. Tech transparency (indie devs love this)
4. Honest current state ("v0.2, some rough edges")
5. Specific question for commenters to answer
```

## Hacker News — Show HN

### The Format

```
Title must match: "Show HN: [Name] – [Short description]"

Good: "Show HN: Jibun – Flutter life-management app replacing 5 SaaS tools"
Bad:  "Show HN: I spent 6 months building this amazing app please upvote"
```

HN readers are engineers. They want to know:
- What technical problem did you solve?
- Why this approach and not an existing tool?
- What's the current limitation?

### Your First Comment

Post this immediately after your Show HN goes live:

```markdown
Hi HN!

**Why I built this**
I was context-switching between Notion, MoneyForward, Slack, and X 
a dozen times a day. The friction was killing my focus and I couldn't 
find a single tool that handled personal + financial + communication tasks.

**What it is**
[App name] is a Flutter Web app (also a PWA) backed by Supabase. 
It replaces my use of Notion (tasks/notes), MoneyForward (expenses), 
and Slack (notifications) with a single interface.

**Technical details**
- Flutter 3.x Web + Dart, deployed to Firebase Hosting
- Supabase PostgreSQL with 15 Edge Functions (Deno/TypeScript)
- AI daily judgment via Claude API — summarizes your day and 
  suggests one priority action
- All data stays in your Supabase project (no vendor lock-in)

**Current state**
Solo project, v0.3. Known issues: iOS Safari scroll jank, 
the mobile nav needs work. MAU is currently small — honest 
feedback is what I'm here for.

**What I'd love to know**
Is there one feature that would make you replace your current 
stack with something like this?

Demo: [URL] | Source: [GitHub if open]
```

### Survival Tips

- **Post Tuesday–Thursday at 9–11 AM EST** — peak HN traffic, enough runway before the day ends
- Reply to every comment within 2 hours, especially critical ones
- Never defend against criticism — "You're right, here's why I made that trade-off" wins more respect than arguing
- If a comment identifies a real bug, fix it and reply with the fix
- "Flag" votes come fast on Show HN — keep the tone humble and technical, not salesy

## Reddit Strategy

### Subreddit Selection

Don't spray-post the same link everywhere. Pick 2–3 subreddits and post natively in each.

```
Great launch communities:
r/SideProject       — most welcoming, low bar for self-promo
r/webdev            — if it's a web tool
r/flutter           — if Flutter is a core part of the story  
r/Entrepreneur      — business model conversations
r/IndieHackers      — engaged indie dev audience
r/learnprogramming  — if it has an educational angle

Rules you MUST check first:
- Self-promotion ratio (most require < 10%)
- "No promotional posts" vs "allowed with caveats"  
- Minimum account karma requirements
- Flair requirements
```

### Crafting Your Reddit Post

Reddit rewards storytelling and vulnerability over product pitches.

```markdown
**Title formula:** 
"After [time spent] building [thing], here's what I learned 
about [relatable challenge] [Optional: tech tag]"

Example:
"After 8 months building a Flutter life-management app, 
here's what I wish I knew about launching [Flutter]"

**Body structure:**

**The problem I was trying to solve**
[2–3 paragraphs — make it personal and specific, 
not "productivity apps suck". Describe the exact pain point.]

**What I built**
[Product name + one-liner + link]

Features:
- [Feature 1 with concrete benefit]
- [Feature 2]  
- [Feature 3]

**Tech stack (for the curious)**
Flutter Web, Supabase, Firebase Hosting, Claude API.
[Brief honest take on why each choice]

**What surprised me**
[A genuine insight from the build process — 
this is what gets upvotes on Reddit]

**What I'm looking for**
[Specific question — not "what do you think?" but 
"what's the one workflow you'd want automated?"]

[Link] — free tier available, no CC required
```

## Launch Day Coordination

```
LAUNCH DAY TIMELINE (all times in your timezone)

T-24h  Prepare all copy. Brief anyone helping promote.
       Set up spreadsheet to track metrics hourly.

T-0    PH post goes live (PST midnight).
       Post your Maker comment within 5 minutes.

T+0:30 Post to X/Twitter: announce + link.
       DM 5–10 friends directly — organic upvotes matter more
       than mass blasts.

T+1h   Check PH rank. If < position 10, amplify.
       Reply to all comments already posted.

T+9h   Show HN post (optimized for US morning traffic).
       Post first comment immediately.

T+12h  Reddit post (r/SideProject first).
       Tailor the body to that community's culture.

T+16h  LinkedIn post (different audience — more professional framing).

T+20h  Day wrap-up tweet: share raw numbers + one key insight.

T+24h  Thank-you replies to everyone who upvoted/commented.
```

## Post-Launch Follow-Up

The 72-hour window after launch is when you convert interest into retained users.

```
D+1   Categorize all feedback. Group into: bugs / UX issues /
      missing features / won't-fix. Publish a public roadmap.

D+2   Ship a patch for the top 3 bugs. Post on PH/HN 
      "Update: fixed X, Y, Z based on your feedback."

D+3   Send a personal thank-you email to every user who 
      signed up on launch day. Ask one question.

D+7   Write a launch retrospective post:
      - Numbers: visits, signups, conversions, revenue
      - What worked and what didn't
      - Top 3 feedback themes
      - Your next 30-day milestone
      
      Publish it. Share it. It's your best content 
      for the next launch.
```

## Summary Table

| Platform | Best For | Key Variable | Timing |
|----------|----------|--------------|--------|
| ProductHunt | Early adopters, VCs, press | Hunter quality | Tue–Thu 00:01 PST |
| Hacker News | Engineers, SEO backlink | Technical credibility | Tue–Thu 9–11 AM EST |
| Reddit | Community building, organic reach | Post authenticity | Varies by subreddit |

The biggest mistake indie devs make is spending months building and hours launching. Flip the ratio — spend at least a week on launch prep, and plan your post-launch follow-through before you ever hit submit.

---

What's your best (or worst) launch story? I'm especially curious about Show HN — did you get kind feedback, brutal feedback, or total silence? Drop it in the comments.
