---
title: "Bulk Summarizing Notes with DeepInfra Llama-3.1-70B — $0.07 per Million Tokens"
tags: AI,Flutter,Supabase,buildinpublic,webdev
published: true
---

# Bulk Summarizing Notes with DeepInfra Llama-3.1-70B

## Why DeepInfra for Bulk Summarization?

Bulk summarization is a **high-volume, cost-sensitive** task. Running it through Claude Sonnet would be expensive; you don't need frontier-model quality to produce a 1–2 sentence summary.

DeepInfra's `meta-llama/Llama-3.1-70B-Instruct` hits the right balance:
- **$0.07/1M input tokens** — roughly 20× cheaper than Claude Sonnet
- OpenAI-compatible API — existing Groq/OpenAI code works with minimal changes
- 70B parameters — accuracy is solid for summarization tasks

## Updated AI Routing Table

| Task | Model | Input cost |
|------|-------|-----------|
| Tag suggestions | Groq llama-3.3-70b | Free tier |
| **Bulk summarization** | **DeepInfra llama-3.1-70b** | **$0.07/1M** |
| Prose balance review | Nebius llama-3.3-70b | $0.10/1M |
| Long-form summaries | Claude Haiku | $0.25/1M |
| Design decisions | Claude Sonnet | $3.00/1M |

Bulk processing follows a simple rule: **cheapest model that meets quality bar**.

## Supabase Edge Function

```typescript
// ai-hub/index.ts (action: "notes.bulk_summarize")
case "notes.bulk_summarize": {
  const { notes } = body; // [{ id: string, content: string }]

  const summaries = await Promise.all(
    notes.map(async (note: { id: string; content: string }) => {
      const response = await fetch(
        "https://api.deepinfra.com/v1/openai/chat/completions",
        {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${Deno.env.get("DEEPINFRA_API_KEY")}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            model: "meta-llama/Llama-3.1-70B-Instruct",
            messages: [
              {
                role: "system",
                content: "Summarize the note in 1–2 sentences. In Japanese.",
              },
              { role: "user", content: note.content.slice(0, 1000) },
            ],
            max_tokens: 100,
            temperature: 0.2,
          }),
        }
      );

      const data = await response.json();
      return {
        id: note.id,
        summary: data.choices[0].message.content,
      };
    })
  );

  return new Response(JSON.stringify({ summaries }), {
    headers: { "Content-Type": "application/json" },
  });
}
```

`Promise.all` parallelizes the calls — 10 notes completes in ~1–2 seconds.

## Flutter Side

```dart
// note_list_page.dart
Future<void> _bulkSummarize(List<Note> notes) async {
  final response = await Supabase.instance.client.functions.invoke(
    'ai-hub',
    body: {
      'action': 'notes.bulk_summarize',
      'notes': notes.map((n) => {
        'id': n.id,
        'content': n.content,
      }).toList(),
    },
  );

  final summaries = (response.data['summaries'] as List)
      .cast<Map<String, dynamic>>();

  setState(() {
    for (final s in summaries) {
      _summaryMap[s['id'] as String] = s['summary'] as String;
    }
  });
}
```

One tap, all notes summarized. The results land in a local map for immediate display.

## Cost Estimate

| Scenario | Cost |
|----------|------|
| 100 notes × 500 tokens avg | $0.0035 |
| 1,000 notes × 500 tokens avg | $0.035 |
| 1,000 users × 100 notes/month | ~$3.50/month |

At indie-app scale, bulk summarization costs **under $5/month**.

## The Pattern

The OpenAI-compatible API means you can swap between Groq, DeepInfra, Nebius, and Fireworks with a one-line URL change. Build your routing layer once, then tune model selection by task cost profile.

---
Building in public: https://my-web-app-b67f4.web.app/
#AI #Flutter #Supabase #buildinpublic
