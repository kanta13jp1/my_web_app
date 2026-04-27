---
title: "260 AI Tools Catalogued: Why I Built a Personal AI University"
tags: ai,education,saas,indiedev
published: true
---

# 260 AI Tools Catalogued: Why I Built a Personal AI University

The AI University feature in my app just crossed **260 registered providers**. Here's why a solo developer keeps cataloguing AI tools, and how the system is designed to scale.

## What Is AI University?

AI University is a structured learning feature for AI tools. Each provider entry includes:

- **Category**: image generation, code assistance, text, voice synthesis, etc.
- **Difficulty score (1-10)**: how hard is it to get value from this tool?
- **Japan support score (1-10)**: how usable is this for Japanese users?
- **Official URL**
- **Key features summary**

Data lives in Supabase. The Flutter Web frontend supports full-text search and category filtering.

## Why 260 Providers?

The AI tool explosion could be treated as noise to ignore or signal to organize. I chose to organize.

Three reasons:

### 1. It's my own decision-making tool

When I evaluate a new AI tool, I need to know: how does this compare to the 10 similar tools I already know? A 260-provider database makes that comparison fast.

### 2. SEO content at scale

Each provider page becomes independent content. Queries like `"{tool} tutorial"`, `"{tool} alternatives"`, `"{tool} Japan support"` become answerable.

### 3. AI generates the content

Provider entries follow a standardized SQL template. Codex CLI generates new entries from the template. Each provider takes about 15 minutes to add at scale.

```sql
INSERT INTO ai_university_content (
  provider_id, provider_name, category,
  description_ja, description_en,
  difficulty_score, japan_support_score,
  official_url, key_features
) VALUES (
  '${id}', '${name}', '${category}',
  '${description_ja}', '${description_en}',
  ${difficulty}, ${japan_support},
  '${url}', '${features}'
) ON CONFLICT (provider_id) DO NOTHING;
```

## What I Actually Learned

**LLM fine-tuning stack** (Unsloth, Axolotl, TRL, PEFT, Mergekit): The speed of low-VRAM, PEFT-based fine-tuning caught me off guard. GPU requirements dropped faster than I expected.

**Evaluation + observability** (Langfuse, DeepEval, Promptfoo, TruLens): RAG quality measurement is an unsolved problem. These tools are converging on RAGAS + G-Eval frameworks.

**Distributed compute** (Ray/Anyscale, BentoML): The abstraction layer for scale-out is maturing. vLLM integration is becoming the common denominator.

## The Design Tradeoff

260 is only ~10% of the actual AI tool market. Gartner projects 2,000+ AI tools by end of 2026.

My target is not "comprehensive" but "decision-useful":
- Top 5 tools per category, deeply documented
- Japan support score based on actual Japanese user experience
- 300 providers total before shifting to depth over breadth

Depth on 300 providers beats shallow coverage of 2,000.

## The Unexpected Benefit

Building this database forced me to read documentation, release notes, and research papers for 260 tools. The byproduct was understanding which categories are saturated, which are nascent, and where the real differentiation lies.

As of today, the highest-value unsaturated categories are:
1. **AI evaluation / observability** — most teams don't do this at all
2. **Distributed AI inference** — still complex to operate
3. **Multimodal RAG** — image + text retrieval is surprisingly hard

The act of cataloguing is itself a research methodology.

If you're building an AI-integrated product, I'd recommend maintaining your own tool registry — even at 50 entries. The clarity it brings to architectural decisions pays for the maintenance cost many times over.
