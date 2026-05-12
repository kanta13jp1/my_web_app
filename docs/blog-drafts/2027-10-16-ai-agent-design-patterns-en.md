---
title: "AI Agent Design Patterns: Tool Use, RAG, and Memory"
tags: ai,indiedev,automation,buildinpublic
published: true
---

# AI Agent Design Patterns: Tool Use, RAG, and Memory

Moving from "just call an LLM" to "an agent that acts autonomously." Three patterns that make it practical.

## Pattern 1: Tool Use (Function Calling)

The LLM decides which tool to use and when.

```python
import anthropic

client = anthropic.Anthropic()

tools = [
  {
    "name": "get_supabase_data",
    "description": "Fetch user data from Supabase",
    "input_schema": {
      "type": "object",
      "properties": {
        "table":   {"type": "string", "description": "Table name"},
        "user_id": {"type": "string", "description": "User ID"}
      },
      "required": ["table", "user_id"]
    }
  },
  {
    "name": "send_email",
    "description": "Send an email via Resend API",
    "input_schema": {
      "type": "object",
      "properties": {
        "to":      {"type": "string"},
        "subject": {"type": "string"},
        "body":    {"type": "string"}
      },
      "required": ["to", "subject", "body"]
    }
  }
]

def run_agent(user_message: str):
  messages = [{"role": "user", "content": user_message}]

  while True:
    response = client.messages.create(
      model="claude-haiku-4-5",
      max_tokens=1024,
      tools=tools,
      messages=messages,
    )

    if response.stop_reason == "end_turn":
      return response.content[0].text

    tool_results = []
    for block in response.content:
      if block.type == "tool_use":
        result = execute_tool(block.name, block.input)
        tool_results.append({
          "type": "tool_result",
          "tool_use_id": block.id,
          "content": str(result)
        })

    messages.append({"role": "assistant", "content": response.content})
    messages.append({"role": "user",      "content": tool_results})
```

## Pattern 2: RAG (Retrieval-Augmented Generation)

Search external documents to improve answer accuracy.

```python
def create_embedding(text: str) -> list[float]:
  return openai.embeddings.create(
    input=text, model="text-embedding-3-small"
  ).data[0].embedding

def index_document(content: str, metadata: dict):
  supabase.table('documents').insert({
    'content':   content,
    'metadata':  metadata,
    'embedding': create_embedding(content)
  }).execute()

def search_documents(query: str, limit: int = 5) -> list[dict]:
  return supabase.rpc('match_documents', {
    'query_embedding': create_embedding(query),
    'match_threshold': 0.7,
    'match_count':     limit
  }).execute().data

def answer_with_rag(question: str) -> str:
  context = "\n\n".join(d['content'] for d in search_documents(question))
  return client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=[{"role": "user", "content": f"Context:\n{context}\n\nQuestion: {question}"}]
  ).content[0].text
```

**pgvector setup (Supabase migration)**:

```sql
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE documents (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content   TEXT NOT NULL,
  metadata  JSONB,
  embedding vector(1536)
);

CREATE FUNCTION match_documents(
  query_embedding vector(1536),
  match_threshold FLOAT,
  match_count     INT
) RETURNS TABLE (id UUID, content TEXT, similarity FLOAT)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT id, content, 1 - (embedding <=> query_embedding) AS similarity
  FROM   documents
  WHERE  1 - (embedding <=> query_embedding) > match_threshold
  ORDER BY similarity DESC
  LIMIT match_count;
END;
$$;
```

## Pattern 3: Memory (Long-Term Context)

Persist context across conversations.

```python
async def save_memory(user_id: str, key: str, value: str):
  await supabase.table('agent_memories').upsert({
    'user_id':    user_id,
    'key':        key,
    'value':      value,
    'updated_at': 'now()'
  }).execute()

async def load_memories(user_id: str) -> dict:
  rows = (await supabase.table('agent_memories')
    .select('key, value').eq('user_id', user_id).execute()).data
  return {r['key']: r['value'] for r in rows}

async def agent_with_memory(user_id: str, message: str) -> str:
  memories = await load_memories(user_id)
  memory_text = "\n".join(f"- {k}: {v}" for k, v in memories.items())

  response = client.messages.create(
    model="claude-haiku-4-5",
    max_tokens=1024,
    system=f"User memories:\n{memory_text}",
    messages=[{"role": "user", "content": message}]
  )
  return response.content[0].text
```

## Combining All Three

```
Practical agent = Tool Use + RAG + Memory

Example: customer support agent
  1. Memory:    load user history + past tickets
  2. RAG:       search FAQ documents for relevant answers
  3. Tool Use:  create ticket / send email / update DB
```

## Summary

```
Simple Q&A            → prompt engineering only
Reference external data → RAG (pgvector + Supabase)
Take actions           → Tool Use (Claude API tools)
Maintain context       → Memory (Supabase upsert)
Production agent       → all three combined
```

Build in order: start with Tool Use, add RAG when accuracy falls short, layer in Memory when you need continuity. Don't add complexity before you need it.

