---
title: "Building a Self-Operating SaaS: How AI Runs My Company While I Sleep"
tags: Flutter,Supabase,buildinpublic,SaaS,automation
published: false
---

# Building a Self-Operating SaaS: How AI Runs My Company While I Sleep

## Target
- [x] Medium (long-form, narrative)
- [ ] Substack (newsletter)

## Draft

### Introduction

What if your SaaS could operate itself?

I'm building "Jibun Corp" — a Japanese life management platform that competes with 14 different SaaS products simultaneously. From Notion to Slack, from MoneyForward to Amazon.

The twist? AI handles the operations. Support tickets, bug fixes, competitor monitoring, daily reports, social media posts, code reviews, infrastructure health checks, vulnerability audits, and even blog draft generation.

All automated. Zero servers. Zero additional cost.

### The Architecture of Autonomy

The system is built on a simple principle: **CLAUDE.md is your operations manual.**

Claude Code Schedule reads the instructions, executes tasks on a cron schedule, and commits results to the repository. Firebase auto-deploys on push.

```
Human writes CLAUDE.md → Schedule triggers → Claude thinks + acts → Git push → Auto-deploy
```

### What Gets Automated

**Customer Support (Hourly)**
Claude reads support tickets via a Supabase Edge Function, matches them against FAQs, and either responds directly, fixes the underlying bug in code, or escalates to a human.

**Competitor Intelligence (Daily)**
14 competitors are monitored for availability, response times, and feature changes. Results are stored in a `competitor_monitoring` table and visible in the admin dashboard.

**Developer Operations (Every 3 Hours)**
Open pull requests are reviewed for security vulnerabilities, performance issues, and logic bugs. Comments are posted automatically.

### The Economics

| Item | Monthly Cost |
|------|-------------|
| Claude Pro Plan | $20 |
| Supabase (free tier) | $0 |
| Firebase Hosting (free tier) | $0 |
| **Total** | **$20** |

Compare this to hiring: a part-time CS agent ($2,000/mo), a DevOps engineer ($5,000/mo), a content writer ($1,500/mo). That's $8,500/month replaced by a $20 subscription.

### Current Status

- 4 registered users (day 1 of growth)
- 48 features implemented
- 9 automated tasks running 24/7
- 5 blog platforms covered daily

### What's Next

The roadmap targets all 14 competitors. It's ambitious — Notion has 100M users, Amazon has 310M active accounts.

But every journey starts with a single user. And right now, Claude is handling the operations while I focus on building.

---

🌐 Try it: https://my-web-app-b67f4.web.app/
📊 GitHub: https://github.com/kanta13jp1/my_web_app

#AI #SaaS #BuildInPublic #Automation
