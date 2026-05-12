---
title: "AI Agent Design: Dify vs LangChain vs Raw API — How to Choose"
tags: ai,automation,indiedev,programming
published: true
---

# AI Agent Design: Dify vs LangChain vs Raw API — How to Choose

When you decide to build an AI agent, the first question is "what do I use?" I've run all three in production. Here's the honest breakdown.

## The Short Answer

```
Dify:       No-code/low-code / prototypes / non-engineer teams
LangChain:  Python / complex chains / OSS ecosystem needed
Raw API:    Production / full control / Flutter + Supabase integration
```

My project landed on **raw API (Anthropic SDK + Deno Edge Function)**.

## When Dify Wins

```
# Dify workflow design view
[Input] → [LLM Node] → [Condition Branch] → [Tool Node] → [Output]
```

Dify lets you build flows in a GUI. Its biggest strength: **working prototype in 3 days**.

```
✅ Use Dify when:
- Non-engineers need to edit workflows
- You want to test a RAG pipeline fast
- You don't want to manage hosting/infra

❌ Not Dify when:
- You need tight integration with existing code
- Custom logic is complex
- Dify's execution cost is climbing
```

## When LangChain Wins

```python
from langchain.agents import initialize_agent, Tool
from langchain.chat_models import ChatAnthropic

tools = [
    Tool(name="search", func=search_fn, description="Web search"),
    Tool(name="calculator", func=calc_fn, description="Math"),
]

agent = initialize_agent(tools, ChatAnthropic(model="claude-haiku-4-5"), ...)
result = agent.run("What's the weather in Tokyo today?")
```

LangChain's Python ecosystem is powerful. Rich integrations for **Vector Store / Retriever / Memory**.

```
✅ Use LangChain when:
- Building a serious RAG pipeline
- Need to swap between multiple LLMs
- Python-based data pipelines already exist

❌ Not LangChain when:
- Flutter/Dart/Deno is your main stack — bindings are thin
- Simple API calls — overhead is disproportionate
```

## When Raw API Wins (My Choice)

```typescript
// Deno Edge Function implementation
const response = await fetch('https://api.anthropic.com/v1/messages', {
  method: 'POST',
  headers: {
    'x-api-key': Deno.env.get('ANTHROPIC_API_KEY')!,
    'anthropic-version': '2023-06-01',
    'content-type': 'application/json',
  },
  body: JSON.stringify({
    model: 'claude-haiku-4-5-20251001',
    max_tokens: 1024,
    messages: [{ role: 'user', content: userMessage }],
  }),
});

const data = await response.json();
return data.content[0].text;
```

**Why I chose raw API**:

1. **Supabase Edge Function (Deno) is home** — no need for Python LangChain bindings
2. **Cost control** — switch haiku/sonnet/opus inside business logic
3. **Minimal dependencies** — not dragged by library breaking changes
4. **RLS integration** — wire directly to Supabase `auth.uid()`

## The Decision Flow

```
Want to build an AI agent?
  ↓
Non-engineers editing workflows?
  Yes → Dify
  No ↓
Python is your main stack?
  Yes → LangChain
  No ↓
Tight integration with existing stack needed?
  Yes → Raw API
  No → Dify (as prototype)
```

## Tool Use (Function Calling) Pattern

Using Tool Use with raw API:

```typescript
const tools = [
  {
    name: "get_race_data",
    description: "Fetch horse racing data",
    input_schema: {
      type: "object",
      properties: {
        race_id: { type: "string", description: "Race ID" },
        date: { type: "string", description: "Date in YYYY-MM-DD" },
      },
      required: ["race_id"],
    },
  },
];

const response = await fetch('https://api.anthropic.com/v1/messages', {
  method: 'POST',
  headers: { 'x-api-key': API_KEY, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
  body: JSON.stringify({
    model: 'claude-sonnet-4-6',
    max_tokens: 2048,
    tools,
    messages: [{ role: 'user', content: 'Predict tomorrow\'s Nakayama races' }],
  }),
});
```

When Claude decides it should call `get_race_data`, it returns a `tool_use` block. Your code handles the dispatch.

## Cost Design: Model Switching Strategy

```typescript
function selectModel(taskType: string): string {
  switch (taskType) {
    case 'simple_qa':      return 'claude-haiku-4-5-20251001';  // $0.00025/1K
    case 'analysis':       return 'claude-sonnet-4-6';           // $0.003/1K
    case 'complex_design': return 'claude-opus-4-7';             // $0.015/1K
    default: return 'claude-haiku-4-5-20251001';
  }
}
```

My horse racing prediction system uses:
- Standard analysis: haiku ($0.00045/prediction)
- Top race deep analysis: sonnet
- Architecture decisions: opus (session-level only)

## Summary

| Factor | Dify | LangChain | Raw API |
| --- | --- | --- | --- |
| Development speed | ◎ | ○ | △ |
| Customizability | △ | ○ | ◎ |
| Existing stack integration | △ | ○ | ◎ |
| Operational cost | △ | ○ | ◎ |
| Non-engineer support | ◎ | △ | ✗ |

For Flutter + Supabase environments, raw API is the right call. Simplicity and control in one package.

The toolchain you choose shapes what you can build. Match it to your stack, not the hype.
