---
title: "How I Automated CS, Bug Fixes, and Competitor Monitoring with Claude Code Schedule"
tags: ClaudeCode,Supabase,GitHubActions,buildinpublic
published: true
---

# How I Automated CS, Bug Fixes, and Competitor Monitoring with Claude Code Schedule — Zero Servers, Zero API Cost

## Title Options
1. How I Automated CS, Bug Fixes, and Competitor Monitoring with Claude Code Schedule
2. 9 Automated Tasks Running 24/7 Without a Server — Claude Code Schedule
3. From Support Tickets to Blog Drafts: Full Automation with Claude Code Schedule

## Target
- [x] dev.to (English, technical)
- [ ] Hashnode
- [ ] Medium

## Draft

### The Problem

I run a personal SaaS called "Jibun Corp" (自分株式会社) — an AI-integrated life management platform built with Flutter Web + Supabase. As a solo developer, I was drowning in:
- Support ticket responses
- Bug reports and fixes
- Competitor monitoring across 14 products
- Daily reports and metrics tracking
- Blog post writing

### The Solution: Claude Code Schedule

Claude Code recently added a "Schedule" feature. It runs tasks on a cron-like schedule, entirely in Anthropic's cloud. No server, no PC required, no API costs beyond the Pro plan.

### My 9 Automated Tasks

| Task | Frequency | What it does |
|------|-----------|-------------|
| daily-report | Daily 9 AM | Fetches metrics → generates report → posts to X |
| cs-check | Hourly | Reads tickets → replies via FAQ or fixes bugs → escalates complex ones |
| weekly-sns-draft | Weekly Mon | Summarizes week → drafts social posts |
| daily-development | Daily 10 AM | Pushes roadmap tasks forward |
| pr-auto-review | Every 3h | Reviews open PRs for security, performance, logic |
| competitor-monitoring | Daily 7 AM | Checks 14 competitors' websites and news |
| infra-health-check | Every 30 min | Verifies DB connectivity and table availability |
| dependency-audit | Weekly Mon | Checks for vulnerable packages |
| blog-draft | Daily 8 AM | Generates technical blog drafts |

### Architecture

```
CLAUDE.md (task definitions)
    ↓
Claude Code Schedule (cron trigger)
    ↓
WebFetch → Supabase Edge Functions (thin API layer)
    ↓
Supabase PostgreSQL (data persistence)
    ↓
GitHub push → Firebase auto-deploy
```

### Key Learnings

1. **Edge Functions as thin APIs**: Schedule can only use WebFetch (HTTP), so create minimal Edge Functions that expose your data.

2. **RLS matters**: Schedule runs as `service_role`, so set up RLS policies accordingly.

3. **Log everything**: Created a `schedule_task_runs` table to track execution status, viewable from the admin dashboard.

### Cost

- Claude Pro plan: $20/month (already paying for development)
- Additional API cost: $0
- Server cost: $0
- Total automation cost: $0

### Conclusion

Claude Code Schedule turns CLAUDE.md into a living operations manual. Write what you want done, set a schedule, and walk away.

---

URL: https://my-web-app-b67f4.web.app/
GitHub: https://github.com/kanta13jp1/my_web_app

#flutter #supabase #claudecode #automation #buildinpublic
