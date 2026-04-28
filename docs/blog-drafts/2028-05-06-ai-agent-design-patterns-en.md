---
title: "AI Agent Design Patterns: Tool Use, Memory, and the ReAct Loop"
tags: ai,indiedev,automation,buildinpublic
published: true
---

# AI Agent Design Patterns: Tool Use, Memory, and the ReAct Loop

Go beyond single API calls — give AI the ability to reason, act, and iterate.

## ReAct Pattern: Reason → Act → Observe

```
ReAct = Reasoning + Acting, interleaved

Loop:
  1. Reason: analyze the situation, decide the next action
  2. Act: invoke a tool
  3. Observe: read the result, loop back to Reason
  → repeat until the goal is reached
```

```typescript
// Edge Function: ai-task-agent/index.ts
import Anthropic from "npm:@anthropic-ai/sdk";

const client = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });

const tools: Anthropic.Tool[] = [
  {
    name: "get_tasks",
    description: "Fetch all incomplete tasks",
    input_schema: { type: "object" as const, properties: {}, required: [] },
  },
  {
    name: "complete_task",
    description: "Mark a task as complete",
    input_schema: {
      type: "object" as const,
      properties: { task_id: { type: "string" } },
      required: ["task_id"],
    },
  },
  {
    name: "send_summary",
    description: "Email today's completed task summary",
    input_schema: {
      type: "object" as const,
      properties: { summary: { type: "string" } },
      required: ["summary"],
    },
  },
];

async function runAgent(userGoal: string): Promise<string> {
  const messages: Anthropic.MessageParam[] = [
    { role: "user", content: userGoal },
  ];

  for (let i = 0; i < 5; i++) {  // max 5 iterations
    const response = await client.messages.create({
      model: "claude-haiku-4-5",
      max_tokens: 1024,
      tools,
      messages,
    });

    if (response.stop_reason === "end_turn") {
      const text = response.content.find((b) => b.type === "text");
      return text?.type === "text" ? text.text : "Done";
    }

    const toolResults: Anthropic.ToolResultBlockParam[] = [];
    for (const block of response.content) {
      if (block.type !== "tool_use") continue;

      let result: string;
      if (block.name === "get_tasks") {
        result = JSON.stringify(await getTasks());
      } else if (block.name === "complete_task") {
        await completeTask((block.input as { task_id: string }).task_id);
        result = "completed";
      } else {
        result = "done";
      }

      toolResults.push({ type: "tool_result", tool_use_id: block.id, content: result });
    }

    messages.push({ role: "assistant", content: response.content });
    messages.push({ role: "user", content: toolResults });
  }

  return "Agent reached iteration limit";
}
```

## Memory: Persist Context Across Sessions

```typescript
async function getMemory(userId: string): Promise<string> {
  const { data } = await supabase
    .from("agent_memory")
    .select("content")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(5);

  return data?.map((m) => m.content).join("\n") ?? "";
}

async function saveMemory(userId: string, content: string) {
  await supabase.from("agent_memory").insert({
    user_id: userId,
    content,
    created_at: new Date().toISOString(),
  });
}

// Inject memory before each agent run
const memory = await getMemory(userId);
const systemPrompt = `You are a personal assistant.
Past context: ${memory}`;
```

## Pattern Selection

```
Single turn          → plain LLM call (no agent needed)
Multi-step task      → Orchestrator + ReAct
Long-term memory     → Memory + ReAct
Parallel tasks       → Agent Teams (multiple agents)
```

## Guardrails

```typescript
const MAX_ITERATIONS = 5;   // prevent infinite loops

// Gate dangerous actions behind explicit confirmation
if (block.name === "delete_all_tasks") {
  return new Response(
    "This action requires explicit user confirmation",
    { status: 400 }
  );
}

const timeout = AbortSignal.timeout(30_000);  // 30-second hard limit
```

## Summary

```
ReAct      → Reason → Act → Observe loop for autonomous multi-step tasks
Memory     → persist to Supabase for cross-session context
Guardrails → max iterations + dangerous action gates + timeout
Choose by  → single turn → ReAct → Memory+ReAct → Agent Teams
```

An agent is just "thinking and acting in a loop." Claude's Tool Use IS the
ReAct loop — no extra framework needed.
