---
title: "274 AI Tools, One Database: Why I Treat Competitors as Curriculum"
tags: ai,postgresql,indiedev,buildinpublic
published: true
---

# 274 AI Tools, One Database: Why I Treat Competitors as Curriculum

This project has a feature called "AI University" — a database of 274 AI tools and services that users can learn from systematically. Here's the design philosophy behind it, and why I deliberately chose *curriculum* over *competitive intelligence*.

## The Problem That Started It

AI tools are multiplying faster than anyone can track. I knew Claude, GPT-4, and Gemini. But what about MLflow, Ray, BentoML, and Feast? What's the difference between Hugging Face and Weights & Biases?

To go from "AI user" to "AI system designer," I needed structured knowledge of the tooling landscape. Building that knowledge into the product meant I could learn it myself while creating something useful for users.

## The 12-Category Taxonomy

| Category | Examples | ~Count |
|---|---|---|
| Foundation models / APIs | Claude, GPT-4, Gemini | ~40 |
| LLM frameworks | LangChain, LlamaIndex | ~25 |
| Fine-tuning | TRL, PEFT, Unsloth | ~20 |
| MLOps / experiment tracking | MLflow, wandb, Neptune | ~30 |
| Model serving | vLLM, TorchServe, BentoML | ~20 |
| Observability | Arize Phoenix, TruLens | ~15 |
| Vector databases | Pinecone, Weaviate, pgvector | ~20 |
| AI agents | AutoGPT, CrewAI, Dify | ~25 |
| Voice / video AI | ElevenLabs, Sora, Runway | ~30 |
| Coding AI | Claude Code, Copilot, Codex | ~15 |
| Multimodal | GPT-4V, Gemini Vision | ~20 |
| Cloud ML platforms | SageMaker, Vertex AI, Azure ML | ~10 |

## Data Schema

```sql
CREATE TABLE ai_university (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_name TEXT NOT NULL,
  category TEXT NOT NULL,
  description TEXT NOT NULL,
  key_features JSONB NOT NULL,
  github_stars TEXT,           -- "33k+" format
  difficulty_level INTEGER,    -- 1-10
  relevance_score INTEGER,     -- relevance to this project, 1-10
  official_url TEXT,
  content_md TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

Two axes drive the learning paths:
- `difficulty_level`: 1–3 = beginner (call the API), 7–10 = advanced (design distributed systems)
- `relevance_score`: 9–10 = actively used in this project

## Why Curriculum, Not Competitive Intelligence

**The competitor framing creates a problem**: If ElevenLabs is a "competitor," it becomes something to beat. The productive question isn't "how do we beat ElevenLabs?" — it's "why did ElevenLabs become the benchmark for Japanese voice quality, and what can we learn from that?"

Tools built by thousands of engineers and refined over years are free education. Treating them as enemies closes that channel.

**What curriculum framing gives you**:
- Deep understanding of why wandb became the de facto ML experiment tracker → applies to product design decisions
- Pattern extraction from successful products → better feature design
- For users: a navigable map of the AI landscape, not just a product pitch

## AI-Assisted Content Generation

Writing 274 company profiles manually is not realistic. The pipeline:

```
1. Company name + category → Claude generates description
2. GitHub stars → fetched via GitHub API
3. difficulty / relevance → scored against project context
4. Supabase migration → managed as SQL seed files
```

PS#3 instance handles this exclusively: 2–3 companies per session, accumulating daily.

## Learning Paths by Axis

```
Beginner track (difficulty 1-3):
  Claude API → OpenAI API → Gemini API

Practical track (relevance 8-10):
  Supabase → Flutter → Firebase → GitHub Actions

Advanced track (difficulty 8-10):
  Ray/Anyscale → Kubeflow → Seldon Core
```

## What 274 Tools Taught Me

**LLM framework wars**: LangChain vs LlamaIndex vs raw API. In 2026 production, raw API + thin wrapper is the most stable pattern. Heavy frameworks add abstraction cost without enough benefit at small scale.

**MLOps convergence**: Experiment tracking is wandb vs MLflow. OSS deployments → MLflow. Cloud integration → wandb.

**Serving divergence**: Real-time → vLLM. Batch → BentoML. Edge → Ollama. The use case determines the tool, and the tools have diverged accordingly.

## Summary

Building "AI University" as curriculum rather than competitive analysis produced three outcomes:
1. A structured AI tooling map for users — a genuinely useful learning resource
2. Deep domain knowledge for me — better design decisions
3. Content as an asset — SEO, search traffic, user acquisition

274 tools aren't enemies. They're teachers. Solo founders who treat the existing landscape as curriculum learn faster and build better than those who treat it as a threat.
