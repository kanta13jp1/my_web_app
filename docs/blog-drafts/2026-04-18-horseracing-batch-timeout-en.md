---
title: "Bypassing Supabase Edge Function 150s Timeout with Batch Loops"
tags: Supabase,Deno,Flutter,buildinpublic,webdev
published: true
---

# Bypassing Supabase Edge Function 150s Timeout with Batch Loops

## The Problem

My horse racing AI prediction feature kept failing with:

```
TimeoutError: The read operation timed out
```

A GitHub Actions Python script was calling a Supabase Edge Function (`horseracing.predict_all`) to run AI predictions across 4 providers (Anthropic/OpenAI/Google/DeepSeek) for 100+ races — and hitting the **Supabase EF hard limit of 150 seconds**.

## Root Cause

```
4 providers × 100 races × ~0.5s/race ≈ 200s > 150s (EF limit)
```

Supabase forcefully terminates the EF call at 150s. The Python side was hitting its own 120s `urllib` read timeout even earlier.

## Fix: `limit` Parameter + Batch Loop

### EF Side (Deno)

```typescript
case 'horseracing.predict_all': {
  const limit = Math.min(body.limit ?? 20, 50); // default=20, max=50

  const rows = await supabase
    .from('horse_races')
    .select('...')
    .is('ai_prediction', null)
    .limit(limit);

  const results = await processBatch(rows.data);
  return new Response(JSON.stringify({
    processed: results.length,
    remaining: totalUnpredicted - results.length,
    total_unpredicted: totalUnpredicted,
  }));
}
```

### Python Side (GitHub Actions)

```python
MAX_BATCHES = 10
BATCH_SIZE = 20

for batch_num in range(MAX_BATCHES):
    result = invoke_ef('horseracing.predict_all', {'limit': BATCH_SIZE})
    processed = result.get('processed', 0)
    remaining = result.get('remaining', 0)

    if processed == 0:
        break  # Nothing to process, or 2 consecutive empty batches

    if remaining == 0:
        break  # All done
```

## Key Takeaways

1. **Don't try to process everything in one EF call** — 150s is a hard Supabase limit, not a soft one
2. **Cap `limit` on the EF side** — prevents clients from accidentally requesting huge batches
3. **Stop on 2 consecutive empty batches** — safety guard against infinite loops
4. **Return `remaining` count** — lets the caller know when to stop without extra queries

## Result

The `horse-racing-update.yml` workflow went from consistently timing out after 26+ minutes to completing successfully across multiple short batches.

The fix required changes in two places — the Deno EF and the Python orchestrator — but the pattern generalizes to any workflow where you're calling a time-bounded EF for bulk processing.

---
Building in public: https://my-web-app-b67f4.web.app/
#Supabase #Deno #FlutterWeb #buildinpublic
