---
title: "10 Things I Learned from Failing at Indie Dev — What 3 Products Taught Me"
tags: ai,indiedev,buildinpublic,automation
published: true
---

# 10 Things I Learned from Failing at Indie Dev — What 3 Products Taught Me

I built three products and shut down two of them. Here's why they failed and what I took from each.

## Failed Product 1: Task Manager

```
Build time: 3 months
Users: 12 (including friends)
Shutdown reason: Notion was obviously better
```

### Lesson 1: Use competitors until you know them cold

I started building without deeply using Notion. Three months later, I realized my product was clearly inferior. I had been solving a problem someone had already solved better.

**What I do now**: maintain a database of 21+ competitors and use them monthly.

### Lesson 2: If you don't use it every day, nobody will

Ask yourself: do I open this product every single day? If the answer is no, you're building for a user who doesn't exist yet.

## Failed Product 2: Automated Budget Tracker

```
Build time: 2 months
Users: 45 (from Product Hunt)
Shutdown reason: external API broke, fix cost exceeded revenue
```

### Lesson 3: Quantify your external dependency risk

"Depending on another company's API" = "dying on their schedule." One API change wiped out two months of work.

**What I do now**: wrap external APIs inside Edge Functions so they're swappable. Core logic stays under my control.

### Lesson 4: Monetize early

"Get users first, charge later" is a trap. I collected 45 free users but only 2 converted to paid. Price gates should be designed from day one.

### Lesson 5: Define your shutdown criteria in advance

```
My current shutdown criteria (written down):
  - MRR < ¥10,000 after 3 months
  - MAU declining for 3 consecutive months
  - >50% of dev time spent on technical debt
```

## How I Apply These Lessons (Current Product)

```
From failure 1: database of 21+ competitors, used monthly + AI University
From failure 2: wrap external APIs to stay swappable
From both: payment flow designed from Day 1
```

### Lesson 6: MVP means "sellable," not just "working"

Include a payment flow in your first MVP. Retrofitting Stripe later costs more than building it in from the start.

### Lesson 7: Interview before you build

Five user interviews before writing code prevents three months of wasted effort. Every time.

### Lesson 8: Make decisions with data

```
Gut feel: "this should be easy to use"
Data:      8-min avg session / 34% bounce / DAU trend
```

I now auto-collect metrics daily via Supabase Analytics and GHA Schedule.

### Lesson 9: Don't do everything yourself

```
Me:   design, decisions, user communication
AI:   implementation, tests, documentation
GHA:  deployment, monitoring, reports
```

Even as a solo founder, the "delegation" mindset matters.

### Lesson 10: Stay at a sustainable pace

```
❌ Burnout period: 60 hours/week → burned out in 3 weeks
✅ Current pace:   20 hours/week → 1+ year of consistent output
```

A sustainable pace produces more total output over the long run than sprinting and crashing.

## Summary

```
Top 3 takeaways:
  1. Use competitors deeply before building
  2. Define shutdown criteria upfront
  3. Protect a sustainable pace
```

Failure isn't shameful. Repeating the same failure is the problem. Recording what went wrong and applying it next time — that's the core skill of indie development.
