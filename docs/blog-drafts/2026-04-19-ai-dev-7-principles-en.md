---
title: "7 Principles for Using AI Agents Safely in Production — A Solo Dev's Checklist"
tags: Flutter,Supabase,AI,buildinpublic,webdev
published: false
---

# 7 Principles for Using AI Agents Safely in Production

## The Problem

When you use Claude Code, Gemini Code Assist, and GitHub Copilot in parallel, you eventually realize: **AI is so convenient that invisible holes accumulate without notice**.

API key overwrites, hallucination loops, auto-post spam... These are all hidden defects embedded during AI-assisted development.

This post shares the 7 AI development principles I use in my solo SaaS project [Jibun Kabushiki Kaisha](https://my-web-app-b67f4.web.app/) (Flutter Web + Supabase).

## The 7 Principles

### Principle 1: Auth Layer (Single Source of Truth)

```typescript
// ❌ Bad: API keys scattered across files
const key = Deno.env.get("OPENAI_KEY") || "fallback-value";

// ✅ Good: One source of truth
const getApiKey = (provider: string) => {
  const key = Deno.env.get(`${provider.toUpperCase()}_API_KEY`);
  if (!key) throw new Error(`${provider} API key not configured`);
  return key;
};
```

AI assistants tend to "helpfully" add fallback values or duplicate key fetching. A single source of truth makes these overwrites immediately visible.

### Principle 2: Deny-by-default Security

```typescript
// Add auth + rate limit from day 1, not "later"
const { data: { user } } = await supabase.auth.getUser();
if (!user) return new Response("Unauthorized", { status: 401 });
```

AI-generated code defaults to open access. Deny-by-default flips this.

### Principle 3: Trace-based Observability

```typescript
const traceId = crypto.randomUUID();
const startTime = Date.now();
const result = await callAI(prompt);
const elapsed = Date.now() - startTime;

if (elapsed > 5000) {
  console.warn(`[${traceId}] Slow AI call detected: ${elapsed}ms`);
}
```

Without `trace_id` and timing, you can't debug AI call failures in production.

### Principle 4: Cost Circuit Breaker (4 tiers)

```typescript
const LIMITS = {
  request:  0.10,  // $0.10 per request
  agent:    1.00,  // $1.00 per agent run
  business: 10.00, // $10.00 per day
  platform: 50.00, // $50.00 per month
};
```

An infinite loop in an AI agent without circuit breakers = surprise cloud bill.

### Principle 5: Team Memory + Effectiveness Score

Track which prompts work and which fail. Automatically decay low-scoring patterns so the agent gets smarter over time instead of repeating mistakes.

### Principle 6: Checkpoint + Retry + Dead Letter Queue

```typescript
// Save intermediate state before each step
await supabase.from("job_checkpoints").upsert({
  job_id: jobId,
  step: "generate",
  data: generatedContent,
});
```

Long AI processes crash. Without checkpoints, you restart from zero.

### Principle 7: Quality Gate (Sentinel + Warden)

Two-layer check before any AI output goes public:
- **Sentinel**: fact verification (hallucination detection)
- **Warden**: quality scoring (>70% threshold)

## The Scoring System

For each new AI feature, score it on all 7 principles:
- **6+** ✅ → Ship it
- **4-5** ✅ → Redesign first
- **3 or fewer** → Reject or major rework

## My Current Scores

| Feature | Score | Gap |
|---------|-------|-----|
| ai-assistant Edge Function | 5/7 | Memory + Quality Gate missing |
| competitor-monitoring | 3/7 | Needs circuit breaker + retry + memory |
| blog-publish | 2/7 | Quality gate + circuit breaker critical |

Low-scoring features get improved incrementally rather than blocked entirely.

## Key Insight

AI tools dramatically accelerate development speed. But invisible defects (key overwrites, hallucination loops, auto-post spam) carry a huge hidden cost.

The 7 principles aren't about perfection — they're a **checklist habit** that catches the most dangerous failure modes before they hit production.

---
Building in public: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #AIagents #solodev
