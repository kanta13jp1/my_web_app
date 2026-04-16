---
title: "How a Missing UNIQUE Constraint Broke Our Production Supabase Deploy (PostgreSQL ON CONFLICT)"
tags: PostgreSQL,Supabase,Flutter,buildinpublic
published: true
---

# How a Missing UNIQUE Constraint Broke Our Production Supabase Deploy (PostgreSQL ON CONFLICT)

## TL;DR

Our GitHub Actions deploy pipeline crashed with `SQLSTATE 42P10` — an obscure PostgreSQL error that means "you used `ON CONFLICT (col)` but there's no UNIQUE constraint on that column." Here's what happened, why, and how we fixed it — plus a bonus milestone: our AI Learning Platform now covers **40 AI providers**.

## Background: AI University Feature

I'm building [自分株式会社](https://my-web-app-b67f4.web.app/) — an AI-integrated life management app built with Flutter Web + Supabase. One of its flagship features is **AI University**: a learning platform covering major AI providers (Google, OpenAI, Anthropic, etc.) with:

- Provider overviews, model listings, API guides
- Quizzes to test knowledge
- Learning scores & streaks
- Leaderboard rankings

Today we hit **40 registered providers** — and simultaneously hit a production deploy failure.

## The Error

```
ERROR: there is no unique or exclusion constraint matching
       the ON CONFLICT specification (SQLSTATE 42P10)
```

Our `deploy-prod.yml` GitHub Actions workflow runs `supabase db push` to apply migrations in order. It failed partway through.

## Root Cause

The original DDL for `ai_university_content`:

```sql
CREATE TABLE IF NOT EXISTS ai_university_content (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider   text NOT NULL,
  category   text NOT NULL,
  title      text NOT NULL,
  content    text,
  published_at date,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Only an INDEX, not a UNIQUE constraint
CREATE INDEX IF NOT EXISTS ai_university_content_provider_idx
  ON ai_university_content (provider, sort_order);
```

Later migrations (around provider #30+) started using upsert syntax:

```sql
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES (...)
ON CONFLICT (provider, category) DO UPDATE
  SET title     = EXCLUDED.title,
      content   = EXCLUDED.content,
      updated_at = now();
```

**The problem**: `ON CONFLICT (provider, category) DO UPDATE` requires a UNIQUE or EXCLUDE constraint on those columns. A plain INDEX is not enough — PostgreSQL needs a formal constraint to enforce uniqueness guarantees during the conflict check.

## PostgreSQL ON CONFLICT: The Rules

| Syntax | Requirement | Behavior |
|--------|-------------|----------|
| `ON CONFLICT DO NOTHING` | None | Silently ignore conflicts |
| `ON CONFLICT (col) DO UPDATE` | UNIQUE or EXCLUDE constraint on `col` | Upsert on conflict |
| `ON CONFLICT ON CONSTRAINT name` | Named constraint | Upsert using named constraint |

We had started with `DO NOTHING` (no constraint needed), then switched to `DO UPDATE` for upsert behavior — but forgot to add the UNIQUE constraint.

## The Fix

New migration `20260412029500_add_unique_constraint.sql` inserted **before** the problematic seed migrations:

```sql
-- Step 1: Remove duplicate rows (keep the most recently updated)
DELETE FROM ai_university_content a
USING ai_university_content b
WHERE a.id < b.id
  AND a.provider = b.provider
  AND a.category = b.category;

-- Step 2: Add the UNIQUE constraint
ALTER TABLE ai_university_content
  ADD CONSTRAINT ai_university_content_provider_category_unique
  UNIQUE (provider, category);
```

**Key insight**: Migration timestamps determine execution order. By giving this fix migration timestamp `20260412029500`, it runs immediately before the upsert migrations that need the constraint.

### Why delete before adding the constraint?

If duplicate rows exist when you run `ALTER TABLE ... ADD CONSTRAINT UNIQUE`, PostgreSQL will reject it. You must clean up duplicates first.

The `DELETE ... USING` self-join pattern:

```sql
DELETE FROM ai_university_content a
USING ai_university_content b
WHERE a.id < b.id              -- delete the older row (smaller id)
  AND a.provider = b.provider
  AND a.category = b.category;
```

This keeps the row with the larger UUID (more recently inserted) for each `(provider, category)` pair.

## Supabase Migration Lessons

1. **Migrations are immutable** — never edit a pushed migration; add a new one instead
2. **Think ahead about upsert patterns** — if you'll ever use `ON CONFLICT (col) DO UPDATE`, add the UNIQUE constraint in the initial DDL migration
3. **Test locally before pushing** — `supabase db reset` + `supabase db push` locally catches these errors before production
4. **Migration order matters** — use timestamps deliberately when inserting a fix between existing migrations

## The 40-Provider Milestone

With the fix deployed, our current provider list:

```
google, openai, anthropic, microsoft, meta, x, deepseek, mistral,
perplexity, groq, cohere, amazon, stability, huggingface, nvidia, ibm,
sakana, baidu, oracle, reka, aleph_alpha, together_ai, fireworks_ai,
replicate, writer, ai21, voyage, elevenlabs, openrouter, ollama,
runway, suno, ideogram, udio, luma, kling, pika, assemblyai, twelve_labs
```

Each provider has content in three categories: `overview`, `models`, `api` — auto-updated every 2 hours via GitHub Actions.

## Conclusion

A single missing UNIQUE constraint caused a production outage. The fix took 20 minutes once we identified the root cause, but the debugging took longer because `SQLSTATE 42P10` isn't an error most developers encounter often.

**Key takeaway**: If you use `ON CONFLICT (col) DO UPDATE`, ensure `col` has a UNIQUE constraint — not just an index.

---

Building in public: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #PostgreSQL #Supabase #Flutter #database
