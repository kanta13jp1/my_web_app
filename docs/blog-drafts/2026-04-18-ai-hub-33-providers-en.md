---
title: "AI Hub Phase 8: Adding DeepInfra and Liquid AI — Now at 33 Providers"
tags: Flutter,Supabase,buildinpublic,AI,Deno
published: false
---

# AI Hub Phase 8: Adding DeepInfra and Liquid AI — Now at 33 Providers

## What's New in Phase 8

Two more inference platforms join the hub, bringing the total to **33 providers**:

### DeepInfra
- **Endpoint**: `https://api.deepinfra.com/v1/openai/chat/completions`
- **Default model**: `meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo`
- **Why**: One of the most cost-effective inference providers. Hosts hundreds of open models with an OpenAI-compat endpoint.

### Liquid AI
- **Endpoint**: `https://api.liquid.ai/v1/chat/completions`
- **Default model**: `liquid/lfm-40b`
- **Why**: Liquid Foundation Models (LFMs) use a novel architecture beyond transformers. Worth experimenting with for long-context tasks.

## Same 7-Line Pattern

```typescript
deepinfra: {
  displayName: "DeepInfra",
  envKey: "DEEPINFRA_API_KEY",
  chatUrl: "https://api.deepinfra.com/v1/openai/chat/completions",
  defaultModel: "meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo",
  buildBody: OPENAI_COMPAT_BODY,
  parseResponse: OPENAI_COMPAT_PARSE,
},
liquid: {
  displayName: "Liquid AI",
  envKey: "LIQUID_API_KEY",
  chatUrl: "https://api.liquid.ai/v1/chat/completions",
  defaultModel: "liquid/lfm-40b",
  buildBody: OPENAI_COMPAT_BODY,
  parseResponse: OPENAI_COMPAT_PARSE,
},
```

## The Pattern That Scales

Every provider using OpenAI-compat format costs 7 lines. No custom auth, no custom parsing. The `OPENAI_COMPAT_BODY` + `OPENAI_COMPAT_PARSE` pair handles everything.

## Provider Count: 8 Phases In

| Phase | Count | Focus |
|-------|-------|-------|
| 1 | 14 | Major LLMs (OpenAI, Anthropic, Google, xAI, DeepSeek) |
| 5 | 23 | Chinese providers (Moonshot, Qwen, Zhipu, 01.AI) |
| 6 | 29 | Enterprise (Reka, Writer, MiniMax, Meta Llama, Nebius) |
| 7 | 31 | Platforms (Replicate, Coze) |
| **8** | **33** | **Inference infra (DeepInfra, Liquid AI)** |

Building in public: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #AI
