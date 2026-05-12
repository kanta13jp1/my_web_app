---
title: "AI University: Turning 280 Competitors into a Content Strategy"
tags: ai,indiedev,buildinpublic,postgresql
published: true
---

# AI University: Turning 280 Competitors into a Content Strategy

I built a database of 280 competing AI tools inside my own app. Sounds counterintuitive — here's why it works as a content strategy.

## The Core Idea: Competitors as Content

```
Common approach: ignore or avoid mentioning competitors
My approach:    make competitors a learning resource → SEO × education × differentiation
```

By positioning 280 AI tools as "something you can learn about here":
- Users searching for competitor names land on my site (SEO)
- Learning about competitors helps users understand my product's value (education)
- "We even include our competitors" signals confidence (differentiation)

## Database Schema

```sql
-- ai_university_content table (actual structure)
CREATE TABLE ai_university_content (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_name TEXT NOT NULL UNIQUE,
  category TEXT NOT NULL,        -- 'llm', 'mlops', 'vector_db', etc
  description TEXT NOT NULL,
  key_features TEXT[] NOT NULL,
  use_cases TEXT[] NOT NULL,
  pricing_model TEXT,            -- 'freemium', 'usage', 'subscription'
  github_stars INT,
  popularity_score INT,          -- 1-10
  maturity_score INT,            -- 1-10
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

280 entries in Supabase, fetched via Edge Function, displayed in Flutter.

## Category Design

```
AI University categories:
  LLM providers:   OpenAI / Anthropic / Google / Meta
  MLOps:          MLflow / Weights&Biases / Kubeflow / SageMaker
  Vector DB:      Pinecone / Weaviate / Qdrant / pgvector
  LLM Frameworks: LangChain / LlamaIndex / Dify / Haystack
  Evaluation:     DeepEval / TruLens / Promptfoo / RAGAS
  Fine-tuning:    Unsloth / TRL / PEFT / Axolotl
  Serving:        BentoML / Ray Serve / vLLM / Ollama
  Data:           DVC / Pachyderm / Great Expectations / Label Studio
```

Value = helping users pick the right tool across categories.

## SEO Strategy: Long-Tail from Competitor Names

```
Example queries:
  "LangChain tutorial" → lands on AI University's LangChain page
  "Weights&Biases pricing" → lands on W&B page
  "MLflow vs Kubeflow comparison" → comparison page
```

Each tool gets a `/vs-{competitor}` route:

```dart
// Flutter dynamic routing
GoRoute(
  path: '/vs-:competitor',
  builder: (context, state) {
    final competitor = state.pathParameters['competitor']!;
    return CompetitorDetailPage(competitorSlug: competitor);
  },
),
```

280 companies × SEO pages = 280 long-tail search entry points.

## Content Update Strategy

Manual updates don't scale. Automated via GHA Schedule:

```yaml
# .github/workflows/ai-university-update.yml
on:
  schedule:
    - cron: '0 */4 * * *'  # every 4 hours

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - name: Fetch latest AI news
        run: |
          # Pull RSS feeds for updates
          # Update ai_university_content in Supabase
```

Auto-tracks GitHub Stars, latest releases, pricing changes. Always current.

## Actual Results

```
Signups from AI University pages: ~50/month
Average session duration: 4min 12sec (2.3x vs normal pages)
Bounce rate: 34% (vs 58% for normal pages)
```

Users researching competitor tools have high learning intent — and convert well to your own product.

## What I Learned

```
1. Competitors aren't enemies — they're part of the ecosystem
2. "We cover all the competitors" builds trust
3. Users compare before choosing — own the comparison
4. 280 entries is a moat — hard to replicate quickly
```

Building a "data asset" as an indie developer is a powerful competitive differentiator.

## Summary

Why I databased 280 competitors:
- **SEO**: 280 long-tail queries answered
- **Education**: users learn the AI ecosystem in one place
- **Trust**: "all-knowing" product branding
- **Moat**: collecting and maintaining 280 entries takes real effort to replicate

Turning competitors into content was the most efficient way to establish my niche.
