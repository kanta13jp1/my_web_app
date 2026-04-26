---
title: "LiteLLM: One API for Every AI Model — A Practical Guide to the OpenAI-Compatible Gateway"
tags: ai,programming,api,webdev
published: false
---

# LiteLLM: One API for Every AI Model — A Practical Guide to the OpenAI-Compatible Gateway

## The "Every AI Gets Its Own SDK" Problem

Claude API, OpenAI API, Gemini API — implement each separately and your code fragments across three different patterns:

```python
# ❌ Three SDKs, three code paths
from anthropic import Anthropic
from openai import OpenAI
from google.generativeai import GenerativeModel
```

LiteLLM solves this with a single OpenAI-compatible interface that routes to 100+ LLM providers. One codebase, one interface, one place to manage fallbacks and costs.

---

## What LiteLLM Is

| | |
|---|---|
| Type | Open source (MIT License) |
| Supported providers | 100+ (OpenAI, Anthropic, Gemini, Cohere, Mistral, etc.) |
| Interface | OpenAI API compatible |
| Deployment | Python package / Docker (LiteLLM Proxy) |
| Primary uses | Unified API, cost tracking, fallback routing |

---

## Basic Usage

### Install

```bash
pip install litellm
```

### Unified calls

```python
from litellm import completion

# Claude
response = completion(
    model="claude-sonnet-4-6",
    messages=[{"role": "user", "content": "Hello"}]
)

# GPT-4o — same code, change the model name
response = completion(
    model="gpt-4o",
    messages=[{"role": "user", "content": "Hello"}]
)

# Gemini
response = completion(
    model="gemini/gemini-1.5-pro",
    messages=[{"role": "user", "content": "Hello"}]
)
```

Switch providers by changing a single `model` parameter. No code restructuring.

---

## Fallback Configuration

Auto-fallback to GPT-4o when Claude hits a 429 rate limit:

```python
from litellm import completion

response = completion(
    model="claude-sonnet-4-6",
    messages=[{"role": "user", "content": "Analyze this"}],
    fallbacks=["gpt-4o", "gemini/gemini-1.5-pro"],
    context_window_fallback_dict={"claude-sonnet-4-6": "claude-haiku-4-5"}
)
```

This eliminates the "one API goes down and the whole feature breaks" problem in production.

---

## Cost Tracking

```python
import litellm

litellm.success_callback = ["langfuse"]  # or custom handler

response = completion(
    model="claude-sonnet-4-6",
    messages=[{"role": "user", "content": "hello"}]
)

# Check cost in response metadata
print(response._hidden_params["response_cost"])  # e.g. 0.00015
```

Automatically aggregate monthly token usage and costs per provider. Useful for comparing actual spend across Claude, GPT, and Gemini.

---

## LiteLLM Proxy: For Teams and Projects

Run a proxy server via Docker so all team members hit the same endpoint:

```yaml
# config.yaml
model_list:
  - model_name: claude-default
    litellm_params:
      model: claude-sonnet-4-6
      api_key: os.environ/ANTHROPIC_API_KEY

  - model_name: gpt-fallback
    litellm_params:
      model: gpt-4o
      api_key: os.environ/OPENAI_API_KEY

router_settings:
  routing_strategy: least-busy
  fallbacks: [{"claude-default": ["gpt-fallback"]}]
```

```bash
docker run -p 4000:4000 ghcr.io/berriai/litellm:main \
  --config /config.yaml
```

Team members use `http://localhost:4000` as an OpenAI-compatible endpoint. API key management is centralized on the server.

---

## Real Usage in Jibun Kaisha

Jibun Kaisha's Supabase Edge Functions use LiteLLM Proxy for Claude/Gemini fallback:

```typescript
// Supabase Edge Function (Deno)
const response = await fetch("https://litellm-proxy.example.com/v1/chat/completions", {
  method: "POST",
  headers: {
    "Authorization": `Bearer ${Deno.env.get("LITELLM_API_KEY")}`,
    "Content-Type": "application/json"
  },
  body: JSON.stringify({
    model: "claude-default",
    messages: [{ role: "user", content: prompt }],
    fallbacks: ["gpt-fallback"]
  })
});
```

When Claude quota is exceeded, Gemini takes over automatically. Features keep running.

---

## LiteLLM Caveats

- **Streaming**: Implemented, but behavior varies slightly across providers
- **Multimodal**: Image inputs only work on supported providers (Claude, GPT-4V, Gemini)
- **Latency**: Proxy adds ~10-30ms overhead
- **Version pinning**: LiteLLM updates can change how provider APIs are called — pin versions in production

---

## Summary

LiteLLM handles AI switching, fallback routing, and cost tracking in one library.

It's most useful when:
- **You use multiple AI providers** → unified interface simplifies management
- **You need production availability** → fallback routing removes single points of failure
- **You want cost visibility** → per-request cost tracking across all providers

For solo developers running multi-AI workflows, LiteLLM is quickly becoming essential infrastructure.

→ [Learn AI development tools in Jibun Kaisha's AI University](https://my-web-app-b67f4.web.app/)
