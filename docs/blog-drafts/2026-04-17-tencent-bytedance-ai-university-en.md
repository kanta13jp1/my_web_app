---
title: "China's AI Giants: Adding Tencent Hunyuan & ByteDance Doubao to AI University (74 Providers)"
tags: AI,LLM,buildinpublic,webdev,Flutter
published: true
---

# China's AI Giants: Tencent Hunyuan & ByteDance Doubao — AI University Update

I've added **Tencent Hunyuan** and **ByteDance Doubao** to the AI University in my app, bringing the total provider count to **74 companies**. With Baidu already registered, China's "BAT" trio is now complete.

## Tencent Hunyuan — Open Source Multimodal Powerhouse

Tencent's AI brand stands out by releasing world-class open-source models across ALL modalities: text, image, video, and 3D.

| Model | Scale | Highlight |
|-------|-------|-----------|
| **Hunyuan-Large** | 389B MoE (52B active) | Largest OSS MoE at release / 256K context |
| **Hunyuan Image 3.0** | 80B | World's largest OSS image generation model |
| **HunyuanVideo** | 13B+ | Largest OSS video generation model |
| **Hunyuan 3D 2.0** | — | Single image → 3D mesh |
| **Hunyuan Compact** | 0.5B–7B | 4 variants for edge/device deployment |

### Why it matters

Most AI companies specialize in one modality. Tencent offers competitive open-source models in text, image, video, AND 3D from a single organization — backed by production experience from WeChat and QQ.

```python
# Tencent Cloud SDK
from tencentcloud.hunyuan.v20230901 import hunyuan_client, models

req = models.ChatCompletionsRequest()
req.Model = "hunyuan-turbo"  # Fast + cost-effective
req.Messages = [{"Role": "user", "Content": "Write a Deno Edge Function"}]
```

---

## ByteDance Doubao — The "Agent Era" Model

TikTok's parent company ByteDance launched **Doubao 2.0** in February 2026 with an explicit "Agent Era" focus — multi-step autonomous task execution.

| Model | Highlight |
|-------|-----------|
| **Seed 2.0 Pro** | Highest accuracy, long context |
| **Seed 2.0 Lite** | Lightweight, fast |
| **Seed 2.0 Mini** | Minimal edge model |
| **Seed 2.0 Code** | Code-specialized |
| **Seedance 2.0** | TikTok-integrated video generation |

### Price competitiveness

Doubao API is reportedly **3.7x cheaper than GPT-5.2** — significant for high-volume batch processing.

```typescript
// Doubao in a Supabase Edge Function
const response = await fetch('https://ark.cn-beijing.volces.com/api/v3/chat/completions', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${Deno.env.get('DOUBAO_API_KEY')}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    model: 'doubao-seed-1-6-250615',
    messages: [{ role: 'user', content: 'Hello!' }],
  }),
});
```

---

## AI University: 74 Providers Across All Categories

```
China AI (4 providers — now complete):
  baidu    → ERNIE Bot         ✅ existing
  tencent  → Hunyuan           ✅ new (73rd)
  bytedance → Doubao           ✅ new (74th)
  deepseek → DeepSeek V3/R1    ✅ existing
```

The full 74-provider catalog covers LLM giants, image/video generation, AI infrastructure, code models, and specialized AI tools — all free to explore in the app.

## Key Takeaways

- **Tencent Hunyuan**: Best-in-class OSS coverage across all modalities. If you need a free, large-scale model for text, image, or video, Hunyuan is worth evaluating.
- **ByteDance Doubao**: Agent-focused design + lowest-tier API pricing. Strong candidate for high-volume automation pipelines.

---
Try AI University (74 providers, free): <https://my-web-app-b67f4.web.app/>
#AI #LLM #buildinpublic #FlutterWeb #Supabase
