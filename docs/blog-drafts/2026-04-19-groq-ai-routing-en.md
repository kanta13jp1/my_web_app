---
title: "Using Groq llama-3.3-70b for Tag Suggestions — Low-Latency AI Routing Patterns"
tags: Groq,AI,Flutter,Supabase,buildinpublic
published: false
---

# Using Groq llama-3.3-70b for Tag Suggestions

## Why Groq?

Tag suggestion is a **speed-first** task:
- Users expect tag candidates to appear while they're still typing
- Target: 1–3 second response time
- Accuracy: "good enough" beats "perfect"

Claude Sonnet is excellent — but overkill for tagging.
Groq's `llama-3.3-70b` offers a **free tier + 400 tokens/sec** throughput that's exactly right here.

## AI Routing Reference (this project's decision matrix)

| Task | AI Choice | Reason |
|------|-----------|--------|
| Tag suggestions | Groq llama-3.3-70b | Speed-first, free tier |
| Long-form summaries | Claude Haiku | Cost-effective, consistent quality |
| Design decisions | Claude Sonnet | Accuracy-first |
| Competitor research | NotebookLM | Free, handles large document sets |
| Image generation | Nano Banana API | Gemini Imagen integration |

**Task-based routing beats "Claude for everything"** — better cost *and* latency at the same time.

## Supabase Edge Function Implementation

```typescript
// ai-hub/index.ts (action: "tags.suggest")
case "tags.suggest": {
  const { text } = body;

  const response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${Deno.env.get("GROQ_API_KEY")}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "llama-3.3-70b-versatile",
      messages: [
        {
          role: "system",
          content: "Suggest 3–5 tags, comma-separated. In Japanese.",
        },
        { role: "user", content: text.slice(0, 500) }, // cost control
      ],
      max_tokens: 50,
      temperature: 0.3,
    }),
  });

  const data = await response.json();
  const tags = data.choices[0].message.content
    .split(",")
    .map((t: string) => t.trim())
    .filter((t: string) => t.length > 0);

  return new Response(JSON.stringify({ tags }), {
    headers: { "Content-Type": "application/json" },
  });
}
```

## Flutter Side: Debounce for Real-Time Suggestions

```dart
// note_editor_page.dart
Timer? _tagDebounce;

void _onNoteChanged(String text) {
  _tagDebounce?.cancel();
  _tagDebounce = Timer(const Duration(milliseconds: 800), () {
    if (text.length > 50) {
      _fetchTagSuggestions(text);
    }
  });
}

Future<void> _fetchTagSuggestions(String text) async {
  final response = await Supabase.instance.client.functions.invoke(
    'ai-hub',
    body: {'action': 'tags.suggest', 'text': text},
  );

  final tags = List<String>.from(response.data['tags'] ?? []);
  if (mounted) setState(() => _suggestedTags = tags);
}
```

800ms debounce means "don't call while the user is still typing" — API cost stays minimal.

## Groq Constraints and Mitigations

| Constraint | Mitigation |
|------------|------------|
| Free tier: 30 req/min | 800ms debounce + rate limit guard |
| Context window: 8K tokens | Slice input to 500 chars |
| Japanese quality: slightly lower | Force Japanese via system prompt |

When Groq returns a rate-limit error, fall back to Claude Haiku:

```typescript
if (!response.ok) {
  // Groq rate-limited → fall back to Claude Haiku
  return suggestTagsWithClaude(text);
}
```

## Key Takeaway

For **speed-first, accuracy-optional** tasks like tag suggestions, Groq llama-3.3-70b is the right tool.

Before reaching for Claude Sonnet on a new feature, ask: **does this task actually need Sonnet-level quality?** That question alone cuts AI infrastructure costs significantly.

---
Building in public: https://my-web-app-b67f4.web.app/
#Groq #AI #Flutter #Supabase #buildinpublic
