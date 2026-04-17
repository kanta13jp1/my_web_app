---
title: "Jibun Corp's AI Hub Reaches 27 Providers — Adding Reka Flash-3 & Writer Palmyra-X5"
tags: Flutter,Supabase,AI,buildinpublic,webdev
published: true
---

# Jibun Corp's AI Hub Reaches 27 Providers

## Two New Additions

| Provider | Model | Highlight |
|---|---|---|
| **Reka AI** | reka-flash-3 | Multimodal (text+image+video), ex-DeepMind team |
| **Writer Palmyra** | palmyra-x5 | Enterprise writing, low hallucination rate |

## Still Just 7 Lines Per Provider

```typescript
reka: {
  displayName: "Reka AI",
  envKey: "REKA_API_KEY",
  chatUrl: "https://api.reka.ai/v1/chat/completions",
  defaultModel: "reka-flash-3",
  buildBody: OPENAI_COMPAT_BODY,
  parseResponse: OPENAI_COMPAT_PARSE,
},
```

The OpenAI-compatibility pattern continues to pay dividends. 24 of 27 providers share the same `OPENAI_COMPAT_BODY` builder — zero custom parsing code needed.

## Why Reka?

Reka was founded by ex-DeepMind and Google Brain researchers. Their `reka-flash-3` model handles text, images, and video natively — rare at this price point. The OpenAI-compatible endpoint means it slots in with no adapter code.

## Why Writer?

Writer focuses exclusively on enterprise use cases: business documents, marketing copy, technical writing. `palmyra-x5` has a notably lower hallucination rate than general-purpose models, making it reliable for content workflows.

## The BYOK Model

All 27 providers use the same BYOK (Bring Your Own Key) pattern: set a Supabase Secret, and the provider becomes active. The Flutter UI's AI Provider Status page shows live status for each provider.

---
Building in public: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #AI
