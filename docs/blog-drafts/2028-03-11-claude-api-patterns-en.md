---
title: "Claude API Patterns: Streaming, Tool Use, and Prompt Caching"
tags: ai,indiedev,automation,buildinpublic
published: true
---

# Claude API Patterns: Streaming, Tool Use, and Prompt Caching

Three implementation patterns for calling the Claude API from a Supabase Edge Function.

## 1. Streaming Responses

Essential for long-form generation (blog drafts, summaries). Dramatically reduces
perceived latency — users see the first tokens in under a second.

```typescript
// supabase/functions/ai-assistant/index.ts
import Anthropic from "npm:@anthropic-ai/sdk";

const client = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });

Deno.serve(async (req) => {
  const { prompt } = await req.json();

  const stream = await client.messages.stream({
    model: "claude-haiku-4-5",
    max_tokens: 1024,
    messages: [{ role: "user", content: prompt }],
  });

  const encoder = new TextEncoder();
  const readable = new ReadableStream({
    async start(controller) {
      for await (const chunk of stream) {
        if (
          chunk.type === "content_block_delta" &&
          chunk.delta.type === "text_delta"
        ) {
          controller.enqueue(
            encoder.encode(`data: ${chunk.delta.text}\n\n`)
          );
        }
      }
      controller.enqueue(encoder.encode("data: [DONE]\n\n"));
      controller.close();
    },
  });

  return new Response(readable, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
    },
  });
});
```

```dart
// Flutter: receive SSE and render in real time
final client = http.Client();
final request = http.Request('POST', Uri.parse(efUrl));
request.body = jsonEncode({'prompt': userPrompt});
final response = await client.send(request);

response.stream
  .transform(utf8.decoder)
  .transform(const LineSplitter())
  .listen((line) {
    if (line.startsWith('data: ') && line != 'data: [DONE]') {
      setState(() => _output += line.substring(6));
    }
  });
```

## 2. Tool Use (Function Calling)

Let the model trigger database lookups, calculations, or API calls.
The foundation for task-management AI, Q&A bots, and agentic features.

```typescript
const tools: Anthropic.Tool[] = [
  {
    name: "search_tasks",
    description: "Search the user's task list",
    input_schema: {
      type: "object" as const,
      properties: {
        query: { type: "string", description: "Search keyword" },
        status: {
          type: "string",
          enum: ["pending", "done", "all"],
        },
      },
      required: ["query"],
    },
  },
];

const response = await client.messages.create({
  model: "claude-haiku-4-5",
  max_tokens: 1024,
  tools,
  messages: [{ role: "user", content: "What tasks are due today?" }],
});

if (response.stop_reason === "tool_use") {
  const toolUse = response.content.find((b) => b.type === "tool_use");
  if (toolUse && toolUse.type === "tool_use") {
    const results = await searchTasks(toolUse.input as SearchInput);
    const final = await client.messages.create({
      model: "claude-haiku-4-5",
      max_tokens: 1024,
      tools,
      messages: [
        { role: "user", content: "What tasks are due today?" },
        { role: "assistant", content: response.content },
        {
          role: "user",
          content: [
            {
              type: "tool_result",
              tool_use_id: toolUse.id,
              content: JSON.stringify(results),
            },
          ],
        },
      ],
    });
    return final.content[0].type === "text" ? final.content[0].text : "";
  }
}
```

## 3. Prompt Caching

When the same system prompt is reused across many requests, caching cuts costs
by up to **88%**.

```typescript
const response = await client.messages.create({
  model: "claude-haiku-4-5",
  max_tokens: 512,
  system: [
    {
      type: "text",
      text: longSystemPrompt,      // FAQ content, docs, etc.
      cache_control: { type: "ephemeral" },
    },
  ],
  messages: [{ role: "user", content: userQuestion }],
});

// cache_read_input_tokens > 0 means cache hit
console.log(response.usage);
```

**Cost comparison** (claude-haiku-4-5):

```
Standard:       $0.25 / 1M input tokens
Cache write:    $0.30 / 1M  (+20%)
Cache read:     $0.03 / 1M  (−88%)
```

Always enable caching for FAQ bots, CS bots, or any pattern that sends
the same long context repeatedly.

## Summary

```
Streaming     → long-form generation / chat UX (perceived latency −90%)
Tool use      → connect AI to DB, calculations, external APIs
Prompt cache  → same system prompt reused → up to 88% cost reduction
```

Edge Functions run on Deno. Import `npm:@anthropic-ai/sdk` directly — no build step.
