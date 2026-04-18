---
title: "AI University Hits 90 Providers: Adding fal.ai and Fish Audio"
tags: Flutter,Supabase,buildinpublic,webdev,AI
published: false
---

# AI University Hits 90 Providers: Adding fal.ai and Fish Audio

The AI University feature of Jibun Corp just hit **90 providers**. Two media AI platforms join the roster:

- **fal.ai** — 1,000+ generative AI models under one API key
- **Fish Audio** — Enterprise TTS + instant voice cloning in 70+ languages

## fal.ai: The Multi-Modal GPU Cloud

fal.ai is a **unified generative media platform**. One API key, one interface — images, video, audio, 3D.

```python
import fal_client

result = fal_client.subscribe("fal-ai/flux/schnell", {
    "prompt": "A futuristic cityscape at sunset",
})
print(result["images"][0]["url"])
```

Key models:

| Model | Modality | Highlight |
|-------|----------|-----------|
| **Seedance 2.0** | Video | 1080p, physics-aware |
| **FLUX.1** | Image | Industry-leading quality |
| **Stable Audio Open** | Music | Open-source music gen |
| **TripoSR** | 3D | 2-second 2D→3D conversion |

Routing tier: **Free** — great for prototyping and multi-modal apps.

## Fish Audio: Voice AI Specialist

Fish Audio delivers **enterprise TTS and instant voice cloning** from seconds of sample audio.

```bash
curl -X POST "https://api.fish.audio/v1/tts" \
  -H "Authorization: Bearer $FISH_AUDIO_API_KEY" \
  -d '{"text": "Hello world", "reference_id": "voice_id"}'
```

- **Instant voice cloning** from a few seconds of audio
- **70+ languages** including Japanese
- **Real-time streaming TTS** — start playback before generation completes
- **Fish Speech S1** — open-source flagship, self-hostable

Routing tier: **Free** — ideal for voice assistants and conversational AI.

## Why These Two Providers?

Both fal.ai and Fish Audio represent the **non-text modalities** that most AI university curricula miss. Developers building in 2026 need to understand:

- When to use a specialized media API vs. a general LLM
- How latency requirements differ between TTS and text chat
- Where open-source models (Fish Speech S1, FLUX) beat proprietary ones on cost

## The 90-Provider Journey

| Date | Count | Highlights |
|------|-------|-----------|
| Early April | 9 | Google, OpenAI, Anthropic |
| Mid April | 54 | Chinese + EU providers |
| Apr 17 | 77 | Video AI (Runway, Suno, Luma, Kling) |
| Apr 18 | 88 | SiliconFlow, Novita AI, DeepInfra, Nebius |
| **Apr 18** | **90** | **fal.ai, Fish Audio** |

Next target: **95 providers**.

Try it free: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #AI
