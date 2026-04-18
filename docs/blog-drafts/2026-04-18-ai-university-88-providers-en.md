---
title: "AI University Hits 88 Providers: Adding DeepInfra and Nebius AI Studio"
tags: Flutter,Supabase,buildinpublic,webdev,AI
published: false
---

# AI University Hits 88 Providers: Adding DeepInfra and Nebius AI Studio

The AI University feature of Jibun Corp just hit **88 providers**. Two inference-focused platforms join the roster:

- **DeepInfra** — 200+ open models at industry-low prices
- **Nebius AI Studio** — High-performance AI cloud from the former Yandex group, EU-based

## What is AI University?

AI University is a **gamified learning experience** for AI providers and models. Each provider gets three content cards:

- 📖 **Overview** — Company background and key differentiators
- 🤖 **Models** — Main model specs and comparisons
- 🔌 **API** — Endpoints, auth, and code examples

Learners earn scores on quizzes, track streaks, and compete on leaderboards.

## DeepInfra

DeepInfra is the **cost champion** of open model inference.

```
Endpoint: https://api.deepinfra.com/v1/openai/chat/completions
Default model: meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo
Tier: Budget (4-Tier auto-routing)
```

Run Llama 3.1 70B at **1/10th the cost of GPT-4o**. 200+ models, one API key, OpenAI-compat interface.

## Nebius AI Studio

Nebius is the **EU-compliant performance option**.

```
Endpoint: https://api.studio.nebius.com/v1/chat/completions
Default model: meta-llama/Llama-3.3-70B-Instruct
Tier: Performance (4-Tier auto-routing)
```

Built by the former Yandex AI team. GDPR-compliant European data centers. Llama 3.3 70B (successor to 3.1) delivers strong reasoning quality.

## 4-Tier Auto-Routing Integration

Our AI Hub uses 4-tier cost auto-routing (`provider.chat_auto`):

| Tier | Examples | Use case |
|------|----------|----------|
| Free | DeepSeek, Groq, **DeepInfra** | Zero-cost tasks |
| Budget | Together AI, Fireworks | Low-cost inference |
| Performance | OpenAI, Google, **Nebius** | Quality-critical tasks |
| Premium | Claude, GPT-4o | Maximum quality |

DeepInfra fills the Free tier and Nebius strengthens the Performance tier.

## The 88-Provider Journey

AI University grew fast in April:

| Date | Count | Highlights |
|------|-------|-----------|
| Early April | 9 | Google, OpenAI, Anthropic |
| Mid April | 54 | Chinese + EU providers |
| Apr 17 | 77 | Video AI (Runway, Suno, Luma, Kling) |
| **Apr 18** | **88** | SiliconFlow, Novita AI, DeepInfra, Nebius |

Next target: **90 providers**.

Try it free: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #AI
