---
title: "How a Solo Founder Monitors 190 Competitors Automatically"
tags: saas,startup,business,ai
published: true
---

# How a Solo Founder Monitors 190 Competitors Automatically

## The Asymmetry Problem

Notion, Evernote, Slack, Google — enterprise SaaS companies employ dedicated competitive intelligence teams. A solo founder tracking the same landscape manually would spend half the workday on research.

Jibun Kaisha monitors 190 competitors **fully automatically**. Here's the system design.

---

## Target Selection

### Direct Competitors (21) — Daily

The 21 products that functionally overlap with Jibun Kaisha:

```
notion, evernote, moneyforward, slack, chatwork, x,
animaworks, claude-code, codex, netkeiba, openclaw,
claude-cowork, jobcan, amazon, google, microsoft,
discord, line, facebook, liven, github
```

UI changes, pricing updates, and feature releases for these 21 are detected **daily**.

### Indirect / Reference (169) — Weekly

Companies that influence the market without directly competing. AI startups, funded players, ecosystem signals. Weekly scan for major changes only.

---

## Technical Architecture

```
GHA cron (competitor-monitoring) → daily 09:00 JST
  ↓
admin-hub:competitor.check
  ├→ Availability check per service (HTTP HEAD)
  ├→ RSS / news feed retrieval
  ├→ Summarize changes via Gemini 1.5 Flash
  └→ Store in Supabase competitor_features table

Generate report → docs/competitor-reports/YYYY-MM-DD.md
Slack notification (significant changes only)
```

### jp_strength Scoring

Each of 172 competitors receives a Japan market threat score:

```sql
UPDATE competitors SET jp_strength =
  CASE
    WHEN has_japanese_ui AND japan_user_base > 100000 THEN 'CRITICAL'
    WHEN has_japanese_ui OR japan_user_base > 10000  THEN 'HIGH'
    WHEN english_only AND enterprise_focus           THEN 'MEDIUM'
    ELSE 'LOW'
  END;
```

Four levels: CRITICAL → HIGH → MEDIUM → LOW.

Examples:
- **Notion** → CRITICAL (full Japanese UI, massive Japanese user base)
- **Evernote** → HIGH (Japanese support, established user trust)
- **Harvey AI** → LOW (English-only, legal niche)

---

## What Gets Monitored: 10 Feature Axes

Each competitor is evaluated on 10 dimensions:

| Axis | What it measures | Example signals |
|------|-----------------|-----------------|
| AI Integration | Depth of AI features | Notion AI, Slack GPT |
| Pricing | Plan changes, price moves | Increases, free tier cuts |
| Mobile UX | Mobile experience quality | PWA, native app redesigns |
| API/Integration | Third-party connectivity | Zapier, Make support count |
| Offline Support | Offline functionality | Local storage, sync |
| Privacy/Security | Data protection posture | E2E encryption, SOC2 |
| Japan Localization | Japanese market depth | UI, support, payment |
| B2B Features | Enterprise capabilities | Admin console, SSO |
| Data Export | Portability | Export formats |
| Performance | Speed and reliability | Lighthouse scores |

---

## Detection Implementation

### Availability Check

```typescript
async function checkAvailability(url: string): Promise<CompetitorStatus> {
  const start = Date.now();
  try {
    const res = await fetch(url, {
      method: "HEAD",
      signal: AbortSignal.timeout(5000),
    });
    return {
      status: res.ok ? "up" : "degraded",
      latency_ms: Date.now() - start,
      http_status: res.status,
    };
  } catch {
    return { status: "down", latency_ms: -1, http_status: 0 };
  }
}
```

### Change Detection

```typescript
const diff = await gemini.generateContent({
  contents: [{
    parts: [{
      text: `Previous: ${previousSnapshot}\nCurrent: ${currentSnapshot}\n\nSummarize significant changes in 3 points max. If no change, reply "no change".`,
    }],
  }],
});

const change = diff.response.text().trim();
if (change !== "no change") {
  await saveChange(competitor, change);
  await notifySlack(competitor, change);
}
```

---

## What the System Actually Catches

Sample detections from April 2026:

| Competitor | Detected Change | Severity |
|------------|----------------|----------|
| Notion | AI features merged into Pro plan (was separate add-on) | CRITICAL |
| Slack | AI huddle summaries rolled out to all plans | HIGH |
| GitHub Copilot | Workspace feature adds multi-repo support | HIGH |
| Evernote | Mobile app redesign launched | MEDIUM |
| Chatwork | AI features added to enterprise tier | MEDIUM |

Manually monitoring this would take 5–10 hours per week. The system surfaces it **daily at zero ongoing cost**.

---

## Report Format

```markdown
# Competitor Monitor — 2026-04-26

## CRITICAL Changes
- **Notion**: AI pricing consolidated into Pro (impact: our differentiation shrinks)

## HIGH Changes
- **Slack**: AI huddle summaries → all plans (impact: communication feature gap narrows)

## Availability Summary
- All 21 direct competitors: UP (no incidents)
- Average response time: 342ms

## Recommended Actions
1. Update Jibun Kaisha value proposition against Notion's new AI pricing
2. Raise priority on AI meeting summary feature development
```

---

## Why This Beats a Dedicated Team

Enterprise companies use headcount for competitive intelligence. Solo founders don't need to match that — they need to match the **outcome** (current market awareness) with different inputs (automation + AI).

The advantage isn't information volume — it's **reaction speed**. Updating your pricing page the day after a competitor raises theirs. Publishing a differentiation post the week a competitor ships a new feature. That speed is determined by system design, not team size.

---

## Related Posts

- [AI-Powered WBS Task Management](./2026-09-12-wbs-task-management-ai-assistant-en.md)
- [Supabase Edge Functions + AI Cost Breakdown](./2026-08-22-supabase-edge-functions-ai-cost-en.md)
- [How to Learn 236 AI Tools Without Burning Out](./2026-09-19-ai-university-how-to-learn-providers-en.md)

---

*Jibun Kaisha — integrating the best of 21 competitors into one life management app*  
*Live: https://my-web-app-b67f4.web.app/*
