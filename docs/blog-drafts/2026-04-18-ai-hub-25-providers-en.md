---
title: "Expanding Jibun Corp's AI Hub to 25 Providers — Qwen, Inflection, AllenAI, HuggingFace & MiniMax"
tags: Flutter,Supabase,AI,buildinpublic,webdev
published: false
---

# Expanding Jibun Corp's AI Hub to 25 Providers

## What Changed

The `ai-hub` Supabase Edge Function now supports **25 AI providers**, up from 20. Five new additions:

| Provider | Highlight | Default Model |
|---|---|---|
| **Alibaba Qwen** | DashScope international, Chinese-origin | qwen-plus |
| **Inflection Pi** | Pi AI's API, conversational focus | inflection_3_pi |
| **Allen AI (OLMo)** | Non-profit, fully open research LLM | OLMo-2-0325-32B-Instruct |
| **Hugging Face** | Largest open model hub (500K+ models) | meta-llama/Llama-3.3-70B |
| **MiniMax** | Chinese multimodal (text + audio + video) | MiniMax-Text-01 |

## The OpenAI-Compatibility Pattern Keeps Paying Off

24 of 25 providers use the same `OPENAI_COMPAT_BODY` function. Adding a new compatible provider is ~7 lines:

```typescript
huggingface: {
  displayName: "Hugging Face",
  envKey: "HUGGINGFACE_TOKEN",
  chatUrl: "https://api-inference.huggingface.co/v1/chat/completions",
  defaultModel: "meta-llama/Llama-3.3-70B-Instruct",
  buildBody: OPENAI_COMPAT_BODY,
  parseResponse: OPENAI_COMPAT_PARSE,
},
```

The pattern reduces provider addition to a config entry — no custom parsing code needed.

## Why Hugging Face Is Special

HuggingFace's Inference API gives access to 500,000+ models with a single API key. By pointing `defaultModel` at any model ID, users can effectively swap models without code changes. It's a shortcut to every open model in existence.

## Why MiniMax Stands Out

MiniMax (香港上場・HKEX listed) goes beyond text: their platform integrates speech synthesis, video generation, and music generation. Text-01 supports up to 1 million tokens of context. The OpenAI-compatible endpoint makes it a drop-in replacement for any workflow.

## Provider Status in Flutter UI

Each provider maps to a status in `AiProviderStatus`:
- `implemented` — API key set, ready to use
- `apiKeyRequired` — Code ready, Supabase Secret pending
- `paidPlanRequired` — Needs paid plan

All 5 new providers are `apiKeyRequired` — implementation complete, keys pending.

## What's Next

The roadmap targets 80 providers for Phase 4. Next candidates include Reka AI, Replicate, IBM WatsonX, and Adept — each requiring API format verification before adding.

---
Building in public: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #AI
