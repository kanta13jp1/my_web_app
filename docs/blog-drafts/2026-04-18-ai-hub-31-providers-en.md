---
title: "Jibun Corp's AI Hub Hits 31 Providers: Adding Replicate and Coze"
tags: Flutter,Supabase,buildinpublic,AI,Deno
published: false
---

# Jibun Corp's AI Hub Hits 31 Providers: Adding Replicate and Coze

## Background

Building in public: I've been expanding the AI Hub Edge Function in my "Jibun Corp" life management app. Phase 7 adds **Replicate** (model hosting platform) and **Coze** (ByteDance's AI agent platform), bringing the total to 31 providers.

## What's New

### Replicate
- **Endpoint**: `https://openai-compat.replicate.com/v1/chat/completions`
- **Default model**: `meta/llama-4-scout-instruct`
- **Why**: Thousands of open-source models, now accessible via a single OpenAI-compat endpoint

### Coze (ByteDance)
- **Endpoint**: `https://api.coze.com/v1/chat/completions`
- **Why**: ByteDance's AI agent platform growing fast in Japan and Asia

## The 7-Line Pattern

Every new provider is just 7 lines:

```typescript
replicate: {
  displayName: "Replicate",
  envKey: "REPLICATE_API_TOKEN",
  chatUrl: "https://openai-compat.replicate.com/v1/chat/completions",
  defaultModel: "meta/llama-4-scout-instruct",
  buildBody: OPENAI_COMPAT_BODY,
  parseResponse: OPENAI_COMPAT_PARSE,
},
```

`OPENAI_COMPAT_BODY` builds the standard request. `OPENAI_COMPAT_PARSE` extracts `choices[0].message.content`. Zero custom code needed for OpenAI-compat providers.

## Provider Count Progress

| Phase | Count | Added |
|-------|-------|-------|
| Phase 1 | 14 | Major LLMs |
| Phase 5 | 23 | Specialized + infra |
| Phase 6 | 29 | Meta Llama API, Nebius |
| **Phase 7** | **31** | **Replicate, Coze** |

## Takeaway

The OpenAI-compat pattern makes scaling to 31 providers trivial. Each new provider adds ~7 lines, no custom auth code, no custom parsing.

Building in public: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #AI
