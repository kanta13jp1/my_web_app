---
title: "Jibun Corp's AI Hub Reaches 29 Providers — Adding Meta Llama API & Nebius AI Studio"
tags: Flutter,Supabase,AI,buildinpublic,webdev
published: false
---

# Jibun Corp's AI Hub Reaches 29 Providers

## Two New Additions

| Provider | Model | Highlight |
|---|---|---|
| **Meta Llama API** | Llama-4-Scout-17B-16E-Instruct | Meta's official API, Llama 4 generation, OpenAI-compatible |
| **Nebius AI Studio** | Llama-3.3-70B-Instruct | Yandex-backed EU GPU cloud, cost-efficient |

## Still Just 7 Lines Per Provider

```typescript
meta: {
  displayName: "Meta Llama",
  envKey: "LLAMA_API_KEY",
  chatUrl: "https://api.llama.com/v1/chat/completions",
  defaultModel: "Llama-4-Scout-17B-16E-Instruct",
  buildBody: OPENAI_COMPAT_BODY,
  parseResponse: OPENAI_COMPAT_PARSE,
},
```

26 of 29 providers share the same `OPENAI_COMPAT_BODY` builder — the pattern continues to pay dividends.

## Why Meta Llama API?

Meta officially launched `api.llama.com` with a fully OpenAI-compatible endpoint. The `Llama-4-Scout-17B-16E-Instruct` model uses a MoE architecture — 17B active parameters with 128K context — making it one of the most capable open-weight models available via API.

## Why Nebius AI Studio?

Nebius is the AI infrastructure spinoff from Yandex, operating EU-based GPU clusters under GDPR compliance. Their OpenAI-compatible endpoint makes integration trivial, and pricing is significantly lower than major US cloud providers for equivalent throughput.

## The BYOK Model at 29 Providers

All 29 providers follow the same BYOK (Bring Your Own Key) pattern: add a Supabase Secret, provider becomes active. No code changes needed — the Flutter UI's AI Provider Status page picks it up automatically.

---
Building in public: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #AI
