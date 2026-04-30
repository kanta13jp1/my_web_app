---
title: "Memory Search Hub: BM25 + pgvector Hybrid Search on Supabase Edge Functions"
tags: Supabase,Deno,buildinpublic,AI,pgvector
published: true
---

# Memory Search Hub: BM25 + pgvector Hybrid Search on Supabase Edge Functions

[自分株式会社](https://my-web-app-b67f4.web.app/) runs a 12-instance development fleet (10 Claude Code + 2 Codex) with cross-session memory. As notes, decisions, and post-mortems piled up across `memory/` markdown files, naive grep stopped scaling. We needed real ranking.

This post walks through the `memory-search-hub` Edge Function — a single Deno Edge Function that combines BM25, vector recall, and an LLM reranker, all backed by Supabase Postgres.

---

## Why Hybrid Instead of Pure Vector

Pure vector search is excellent at semantic recall ("find notes about the migration mistake"), but loses on:

- **Exact identifier match** — file paths, commit SHAs, EF names like `memory-search-hub`
- **Rare terms** — `BM25`, `pg_trgm`, `RLS policy` — short, high-signal tokens that embeddings dilute
- **CJK substrings** — Japanese tokens often span 1–3 characters; ANN distance under-weights them

BM25 dominates those. Vector dominates on paraphrase and intent. Hybrid + rerank wins both.

The hub exposes 4 actions: `memory.search` (hybrid), `memory.rank` (BM25-only), `memory.related` (vector-only), `memory.stats`.

---

## BM25 in TypeScript with CJK Bigrams

The tokenizer has to handle Japanese without a morphological analyzer (no kuromoji on Deno Deploy without bundling). Solution: ASCII word-split + CJK character bigrams.

```ts
function cjkBigrams(text: string): string[] {
  const chars = Array.from(text).filter((char) =>
    /\p{Script=Han}|\p{Script=Hiragana}|\p{Script=Katakana}/u.test(char)
  );
  const grams: string[] = [];
  for (let i = 0; i < chars.length - 1; i++) {
    grams.push(`${chars[i]}${chars[i + 1]}`);
  }
  return grams;
}

export function tokenize(text: string): string[] {
  const normalized = text.toLowerCase();
  const ascii = normalized.match(/[a-z0-9_-]{2,}/g) ?? [];
  return [...ascii, ...cjkBigrams(normalized)];
}
```

Standard BM25 with `K1=1.5`, `B=0.75` works fine for our doc-length distribution (memory notes are 200–2,000 chars). No tuning needed yet.

---

## pgvector Recall

The `memory_index` table stores `embedding vector(1536)` per note plus the raw content for snippet generation. Embeddings come from a sync job (`sync_memory_index.py`) that runs on commit — no online embedding cost at query time.

Vector recall is a single `<=>` call ordered by cosine distance, top-K=50. Result lands in the same `ScoredMemoryDocument` shape as BM25 so the reranker doesn't care which side produced what.

---

## Reranking with Haiku

The two pools (BM25 top-50 + vector top-50) get unioned and deduped on `file_path`, then passed to Claude Haiku 4.5 with a small ranking prompt. The reranker reorders, doesn't filter — final cut happens after, by score threshold.

Why Haiku and not a cross-encoder? Two reasons:

1. **Cost ceiling** — `task_budget.ts` (also shipped this week) caps daily LLM spend per action. Haiku at ~$0.25/M input is well under the cap even at 100 reranks/day.
2. **Reasoning beats lexical re-ranking** for our queries — most are natural language ("did we already solve the duplicate competitor key bug?") rather than keyword bags.

The reranker call is gated behind `effort_router.ts`, which picks `low | medium | high` based on the query class. Stats queries skip it entirely.

---

## Cost Guards: `task_budget` + `effort_router`

Every action invocation increments a row in `task_budget`:

```sql
INSERT INTO task_budget (action, model, input_tokens, output_tokens, cost_usd, day)
VALUES ($1, $2, $3, $4, $5, current_date);
```

If today's `SUM(cost_usd)` for the action exceeds the configured cap, the EF returns `429 budget_exceeded` instead of calling the LLM. BM25 + vector still run — only the rerank degrades. That's the right failure mode: search keeps working, the polish goes away.

---

## Auth: `mcp_auth_guard`

The hub is exposed as an MCP server, so every request goes through `validateBearer` + `requireScope("memory:read")`. Service-role bearer is allowed for internal jobs (sync, audit). Per-user bearers carry scopes from the `mcp_oauth_clients` table. Audit row in `mcp_audit_log` for every invocation — non-negotiable for memory data.

---

## What Shipped

- `supabase/functions/memory-search-hub/` — index.ts + search/{bm25,rerank,vector}.ts
- `_shared/effort_router.ts` — 217 lines, replaces a 30-line stub
- `_shared/task_budget.ts` — 308 lines, replaces a 51-line stub
- 3 migrations: `memory_index`, `task_budget`, `effort_config`
- `scripts/check_budget.py`, `scripts/sync_memory_index.py`
- `.github/workflows/memory-search-sync.yml` — re-syncs the index on push to main

That's 20/50 EFs in our `deploy-prod.yml` — same hub-consolidation pattern we've used to keep the EF count low while feature surface grows.

---

## What Didn't Make This Cut

- **HyDE-style query expansion** — drafted, deferred. Haiku rerank covers most of the gain.
- **Personalized BM25 priors** (user-specific term weights) — needs more usage data first.
- **Streaming results** — current EF blocks until rerank finishes. Fine at this scale.

The principle: ship the cheapest hybrid that beats grep, instrument cost from day one, evolve when usage demands it.

---

## Try It

```bash
curl -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"action":"memory.search","query":"duplicate competitor key bug","limit":10}' \
  https://<project>.supabase.co/functions/v1/memory-search-hub
```

Source: [github.com/kanta13jp1/my_web_app](https://github.com/kanta13jp1) — `supabase/functions/memory-search-hub/`.
