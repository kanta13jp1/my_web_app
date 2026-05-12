---
title: "LLM Integration Patterns: Function Calling, RAG, or Agent — How to Choose"
tags: ai,indiedev,automation,buildinpublic
published: true
---

# LLM Integration Patterns: Function Calling, RAG, or Agent — How to Choose

When integrating Claude or GPT-4 into your app, there are three core patterns. Here's how to pick the right one.

## The Three Patterns

```
Function Calling: give the LLM tools → get structured output
RAG:             give the LLM knowledge → context-aware answers
Agent:           let the LLM plan and execute → multi-step autonomous work
```

These trade off simplicity vs. control. Start with Function Calling. Escalate only when needed.

## Pattern 1: Function Calling

The LLM decides which function to call. Reliable way to get structured data:

```dart
// Flutter → Supabase EF → Claude
final response = await supabase.functions.invoke(
  'ai-assistant',
  body: {
    'message': userMessage,
    'mode': 'function_calling',
  },
);
```

```typescript
// Edge Function: tool definition
const tools = [
  {
    name: 'create_task',
    description: 'Create a task for the user',
    input_schema: {
      type: 'object',
      properties: {
        title: { type: 'string', description: 'Task title' },
        due_date: { type: 'string', description: 'Due date in YYYY-MM-DD format' },
        priority: { type: 'string', enum: ['high', 'medium', 'low'] },
      },
      required: ['title'],
    },
  },
];

const message = await anthropic.messages.create({
  model: 'claude-haiku-4-5-20251001',
  max_tokens: 1024,
  tools,
  messages: [{ role: 'user', content: userMessage }],
});

if (message.stop_reason === 'tool_use') {
  const toolUse = message.content.find(b => b.type === 'tool_use');
  if (toolUse?.name === 'create_task') {
    await supabase.from('tasks').insert(toolUse.input);
  }
}
```

**Use when**: turning natural language into form data / creating tasks from chat / extracting structured info.

## Pattern 2: RAG (Retrieval-Augmented Generation)

Retrieve external knowledge via vector search and pass it to the LLM:

```typescript
async function ragQuery(userQuery: string, supabase: SupabaseClient) {
  // 1. Embed the query
  const embeddingRes = await fetch('https://api.openai.com/v1/embeddings', {
    method: 'POST',
    headers: { Authorization: `Bearer ${Deno.env.get('OPENAI_API_KEY')}` },
    body: JSON.stringify({ model: 'text-embedding-3-small', input: userQuery }),
  });
  const { data } = await embeddingRes.json();
  const embedding = data[0].embedding;

  // 2. Vector search via pgvector
  const { data: docs } = await supabase.rpc('match_documents', {
    query_embedding: embedding,
    match_threshold: 0.78,
    match_count: 5,
  });

  // 3. Build context and call Claude
  const context = docs.map(d => d.content).join('\n\n');
  const response = await anthropic.messages.create({
    model: 'claude-haiku-4-5-20251001',
    max_tokens: 1024,
    messages: [{
      role: 'user',
      content: `Answer using this context:\n\n${context}\n\nQuestion: ${userQuery}`,
    }],
  });

  return response.content[0].text;
}
```

```sql
CREATE OR REPLACE FUNCTION match_documents(
  query_embedding vector(1536),
  match_threshold float,
  match_count int
)
RETURNS TABLE (id UUID, content TEXT, similarity float)
LANGUAGE sql STABLE
AS $$
  SELECT id, content, 1 - (embedding <=> query_embedding) AS similarity
  FROM documents
  WHERE 1 - (embedding <=> query_embedding) > match_threshold
  ORDER BY embedding <=> query_embedding
  LIMIT match_count;
$$;
```

**Use when**: AI University Q&A / document search / customer support automation.

## Pattern 3: Agent (Autonomous Execution)

The LLM plans and executes multiple steps:

```typescript
async function runAgent(goal: string, maxSteps = 5) {
  const messages = [
    {
      role: 'user',
      content: `Goal: ${goal}\nAvailable tools: search_web, create_draft, send_email`,
    },
  ];

  for (let step = 0; step < maxSteps; step++) {
    const response = await anthropic.messages.create({
      model: 'claude-sonnet-4-6',
      max_tokens: 2048,
      tools,
      messages,
    });

    if (response.stop_reason === 'end_turn') break;

    if (response.stop_reason === 'tool_use') {
      const toolResult = await executeTool(response.content);
      messages.push({ role: 'assistant', content: response.content });
      messages.push({ role: 'user', content: [{ type: 'tool_result', ...toolResult }] });
    }
  }

  return messages;
}
```

**Use when**: GHA schedule tasks / competitor monitoring / weekly report generation.

## Decision Tree

```
Need structured output? → Function Calling
↓ No
Need external knowledge? → RAG
↓ No
Need multi-step execution? → Agent
↓ No
Simple completion → raw messages API
```

**Cost order**: raw API < Function Calling < RAG < Agent

## Summary

```
Function Calling: structured output + tool execution → simplest, most reliable
RAG:             inject knowledge → best for accuracy-critical Q&A
Agent:           autonomous execution → great for GHA batch tasks
```

Start with the simplest pattern that solves the problem. Escalate only when you hit limits. That's the golden rule for LLM integration in indie development.
