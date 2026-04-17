---
title: "Expanding Jibun Corp's AI Hub to 20 Providers — Including Cerebras Ultra-Fast Inference & Chinese AI"
tags: Flutter,Supabase,AI,buildinpublic,webdev
published: true
---

# Expanding Jibun Corp's AI Hub to 20 Providers

## What Changed

The `ai-hub` Supabase Edge Function now supports **20 AI providers**, up from 14. The six new additions:

| Provider | Highlight | Default Model |
|---|---|---|
| **Cerebras** | Ultra-fast (1000+ tokens/s) | llama-3.3-70b |
| **NVIDIA NIM** | Enterprise inference API | meta/llama-3.1-70b-instruct |
| **Moonshot (Kimi)** | Long context, Chinese-origin | moonshot-v1-8k |
| **AI21 Labs** | Jamba SSM+Transformer hybrid | jamba-1.5-mini |
| **01.AI (Yi)** | Open-source Chinese LLM | yi-lightning |
| **Zhipu AI (GLM)** | GLM-4 family, generous free tier | glm-4-flash |

## The OpenAI-Compatibility Pattern

Every provider except Google Gemini uses the same OpenAI-compatible body builder:

```typescript
const OPENAI_COMPAT_BODY = (messages: unknown[], model: string) => ({
  model,
  messages,
  max_tokens: 1000,
  temperature: 0.7,
});

cerebras: {
  envKey: "CEREBRAS_API_KEY",
  chatUrl: "https://api.cerebras.ai/v1/chat/completions",
  defaultModel: "llama-3.3-70b",
  buildBody: OPENAI_COMPAT_BODY,
  parseResponse: OPENAI_COMPAT_PARSE,
},
```

This pattern means adding a new OpenAI-compatible provider is literally ~7 lines of config.

## Why Cerebras Stands Out

Cerebras uses purpose-built silicon (the Wafer Scale Engine) for inference. The result: the same Llama-3.3-70b model runs **10x+ faster** than on GPU clusters. For real-time chat apps, this matters.

## Provider Status in the Flutter UI

Each provider maps to a status in `AiProviderStatus`:
- `implemented` — API key set, ready to use
- `apiKeyRequired` — Code is ready, waiting for the Supabase Secret
- `paidPlanRequired` — Needs a paid plan subscription
- `notImplemented` — Not yet coded

All 6 new providers are now `apiKeyRequired` — code complete, secrets pending.

## What's Next

The BYOK (Bring Your Own Key) flow lets users supply their own API keys via the AI Provider Status page. As more keys get added, the green `implemented` count grows.

---
Building in public: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #AI
