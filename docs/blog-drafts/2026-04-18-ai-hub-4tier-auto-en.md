---
title: "Building a 4-Tier AI Cost Auto-Routing System with Supabase Edge Functions"
tags: Flutter,Supabase,Deno,AI,buildinpublic
published: true
---

# Building a 4-Tier AI Cost Auto-Routing System with Supabase Edge Functions

## What I Built

I added a `provider.chat_auto` action to the AI Hub Edge Function of my personal life management app.
It automatically routes AI requests through 4 cost tiers, escalating to more expensive providers only when cheaper ones fail.

## The 4-Tier Architecture

| Tier | Providers | Est. cost/1K tok |
|------|-----------|-----------------|
| **free** | DeepSeek, Groq, Cerebras, SiliconFlow, Novita | $0.0001 |
| **budget** | SambaNova, Arcee AI, MiniMax, DeepInfra | $0.001 |
| **performance** | OpenAI, Google, Mistral, Cohere, Perplexity | $0.01 |
| **premium** | Anthropic Claude, OpenAI GPT-4, Gemini Ultra | $0.05 |

## Auto-Escalation Logic

```typescript
const TIER_ORDER: Tier[] = ["free", "budget", "performance", "premium"];

async function callWithAutoEscalation(messages, preferredTier = "free") {
  for (const tier of TIER_ORDER.slice(TIER_ORDER.indexOf(preferredTier))) {
    for (const provider of TIER_PROVIDERS[tier]) {
      try {
        const result = await callSingleProvider(provider, messages);
        await logCost(provider, tier, true);
        return result;
      } catch {
        // Try next provider in tier, then escalate to next tier
      }
    }
  }
  throw new Error("All tiers exhausted");
}
```

If a provider fails (quota, network, API error), the system automatically:
1. Tries the next provider in the same tier
2. Escalates to the next tier if all providers in the current tier fail

## Cost Tracking

Each request logs to `ai_hub_chat_logs` with `provider`, `tier`, `estimated_cost_usd`, so I can track:
- Which providers are actually being used
- When escalations happen (indicates quota issues)
- Monthly cost breakdown by tier

## Key Refactor

The original `provider.chat` had all provider API calls inlined in a giant switch-case.
I extracted `callSingleProvider()` so both `provider.chat` and `provider.chat_auto` share the same calling logic — no code duplication.

## Result

Free tier (DeepSeek/Groq free APIs) handles most requests at near-zero cost.
When Claude quota runs out, it automatically falls back to OpenAI → Google → DeepSeek.
AI feature uptime improved significantly.

---
Building in public: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #Deno
