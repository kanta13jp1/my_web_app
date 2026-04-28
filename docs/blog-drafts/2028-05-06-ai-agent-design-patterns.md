---
title: "AI エージェント設計パターン — Tool Use / Memory / ReAct ループ"
tags: AI,個人開発,automation,buildinpublic
published: true
---

# AI エージェント設計パターン — Tool Use / Memory / ReAct ループ

単発の API 呼び出しを超えて、AI に「考えながら実行する」能力を持たせる。

## ReAct パターン: Reason → Act → Observe

```
ReAct = Reasoning + Acting の組み合わせ

ループ:
  1. Reason: 現状を分析して次のアクションを決定
  2. Act: ツールを呼び出す
  3. Observe: 結果を見て次の Reason へ
  → ゴール達成まで繰り返す
```

```typescript
// Edge Function: ai-task-agent/index.ts
import Anthropic from "npm:@anthropic-ai/sdk";

const client = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });

const tools: Anthropic.Tool[] = [
  {
    name: "get_tasks",
    description: "未完了タスク一覧を取得",
    input_schema: { type: "object" as const, properties: {}, required: [] },
  },
  {
    name: "complete_task",
    description: "タスクを完了にする",
    input_schema: {
      type: "object" as const,
      properties: { task_id: { type: "string" } },
      required: ["task_id"],
    },
  },
  {
    name: "send_summary",
    description: "今日の完了タスクをメールで送信",
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

  // ReAct ループ (最大 5 回)
  for (let i = 0; i < 5; i++) {
    const response = await client.messages.create({
      model: "claude-haiku-4-5",
      max_tokens: 1024,
      tools,
      messages,
    });

    if (response.stop_reason === "end_turn") {
      const text = response.content.find((b) => b.type === "text");
      return text?.type === "text" ? text.text : "完了";
    }

    // ツール呼び出し処理
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

  return "エージェントがループ上限に達しました";
}
```

## Memory: セッション間で文脈を保持

```typescript
// Supabase でエージェントのメモリを永続化
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

// エージェント実行前にメモリを注入
const memory = await getMemory(userId);
const systemPrompt = `あなたはパーソナルアシスタントです。
過去の文脈: ${memory}`;
```

## パターン選択基準

```
シングルターン      → 通常の LLM 呼び出し (エージェント不要)
マルチステップ      → Orchestrator-Subagent (ReAct)
長期記憶が必要     → Memory + ReAct
並列タスク処理      → Agent Teams (複数エージェント)
```

## ガードレール

```typescript
// 実行回数上限 (無限ループ防止)
const MAX_ITERATIONS = 5;

// 危険なアクションは確認を挟む
if (block.name === "delete_all_tasks") {
  // 確認なしに実行しない
  return new Response("This action requires explicit user confirmation", { status: 400 });
}

// タイムアウト
const timeout = AbortSignal.timeout(30_000);  // 30秒
```

## まとめ

```
ReAct         → Reason → Act → Observe ループで複雑タスクを自律実行
Memory        → Supabase に永続化してセッション横断の文脈を保持
ガードレール   → 最大反復回数 + 危険アクション確認 + タイムアウト
選択基準      → シングルターン → ReAct → Memory+ReAct → Agent Teams
```

エージェントは「思考と実行を繰り返す」仕組み。Claude の Tool Use がそのまま ReAct になる。
