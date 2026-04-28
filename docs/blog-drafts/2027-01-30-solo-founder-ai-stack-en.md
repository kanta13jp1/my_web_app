---
title: "My $230/Month AI Stack: Every Tool a Solo Founder Actually Uses"
tags: ai,indiedev,automation,buildinpublic
published: true
---

# My $230/Month AI Stack: Every Tool a Solo Founder Actually Uses

Full transparency: here's every AI tool I pay for, what it costs, and why I haven't replaced it. Total: $230/month. This stack runs 12 parallel AI instances, publishes 50+ blog posts, powers a horse racing prediction model, and handles customer support automation.

## The Full Stack

| Tool | Monthly | Primary use | Why irreplaceable |
|---|---|---|---|
| Claude Code Max | $200 | Architecture, code gen, 12 instances | Judgment/integration are Claude-only |
| Supabase Pro | $25 | PostgreSQL + EF + Auth + Realtime | Best Flutter integration |
| ElevenLabs | $5 | Video content audio generation | Best Japanese voice quality |
| GitHub Actions | $0 | CI/CD, all automation tasks | Free tier is sufficient |
| Firebase Hosting | $0 | Flutter Web production hosting | Free Google CDN |
| NotebookLM | $0 | Zero-token research, Master Brain | Google infrastructure, free |
| GitHub Copilot | $0* | Inline code completion | Claude Code supplement |

*Free VS Code extension tier

## Claude Code Max: Why Pay $200?

```
$200/month = unlimited plan, 12 instances working all day
             ↓
            vs
Pay-per-token = estimated $800–1200/month for equivalent work
```

Max plan is pay-once-work-unlimited. With 12 instances running continuously, the cost-per-task drops dramatically.

**April 2026 actual output:**
- 70 AI university providers added (PS#3)
- 174 competitor pages complete (PS#4)
- 54 dev.to posts published (PS#2)
- Stale EF audit + fixes (PS#5)
- Horse racing AI: 10-factor model (PS#6)

Equivalent freelance cost: $5,000–10,000+ easily.

## Supabase Pro: Why Only $25?

The **hub pattern** keeps EF count at 18. Without it, the function count would push into higher-tier pricing.

Additionally:
- Row Level Security concentrates auth logic in the DB layer
- Edge Functions move complex logic server-side
- Realtime eliminates polling → fewer client requests

## The Free Arsenal: GHA + Firebase + NotebookLM

**GitHub Actions**: 2,000 min/month free. Current automation (blog-publish / cs-check / daily-report / ai-university-update) uses ~1,200 min/month. Comfortable margin.

**Firebase Hosting**: 10GB/month + CDN free. Flutter Web SPA compresses to under 2MB. No issue.

**NotebookLM**: Free Google service. Single biggest contributor to keeping the Claude Code bill at $200 instead of $400. Token delegation saves ~$200/month worth of context.

## Tools I Evaluated and Rejected

| Tool | Reason not adopted |
|---|---|
| OpenAI API | Claude outperforms on Japanese-language quality |
| Vercel | Firebase sufficient, better Google integration |
| PlanetScale / Neon | Supabase = PG + EF + Auth in one |
| Sentry | GHA error notifications sufficient at this scale |
| Datadog / Grafana | Too heavy for solo dev operations |

## Three Cost Efficiency Principles

**1. Saturate flat-rate plans.**  
Fixed monthly tools are "free at the margin." Claude Code Max is worthless at 1 instance and valuable at 12. Architect to saturate the plan.

**2. Know the free tier ceilings.**  
GHA 2,000 min / Firebase 10GB / Supabase free limits — know exactly where you'd overflow and design to stay under.

**3. Choose AI tools that reduce your other AI costs.**  
NotebookLM cuts Claude token usage by 49% → delivers ~$100 of value while costing nothing. When evaluating a new tool, ask: does it reduce the cost of other tools in the stack?

## The Real Lesson

$230/month for the output of 12 engineers isn't about the tools. It's about three design decisions:
1. Max-utilize unlimited plans (Claude Code Max)
2. Design to stay cheap (hub pattern, zero-token research)
3. Extract maximum value from free tools (GHA, Firebase, NotebookLM)

AI spending is leverage purchasing, not capability purchasing. The question isn't "what can I buy?" — it's "how much force can I multiply per dollar?"
