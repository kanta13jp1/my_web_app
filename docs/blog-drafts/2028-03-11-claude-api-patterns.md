---
title: "Claude API 活用パターン — ストリーミング / ツール使用 / プロンプトキャッシュ"
tags: AI,個人開発,automation,buildinpublic
published: true
---

# Claude API 活用パターン — ストリーミング / ツール使用 / プロンプトキャッシュ

Supabase Edge Function から Claude API を呼ぶ実装パターン3選。

## 1. ストリーミングレスポンス

長文生成 (ブログ下書き / 要約) では必須。ユーザーが最初のトークンを受け取るまでの
体感レイテンシを大幅に削減できる。

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

  // Server-Sent Events でフロントへ流す
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
// Flutter 側: SSE を受信してリアルタイム表示
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

## 2. ツール使用 (Function Calling)

AI に「データベース検索」「計算」「API 呼び出し」を実行させる。
タスク管理 AI や Q&A Bot の構築に直結する。

```typescript
const tools: Anthropic.Tool[] = [
  {
    name: "search_tasks",
    description: "ユーザーのタスク一覧を検索します",
    input_schema: {
      type: "object" as const,
      properties: {
        query: { type: "string", description: "検索キーワード" },
        status: {
          type: "string",
          enum: ["pending", "done", "all"],
          description: "フィルター条件",
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
  messages: [{ role: "user", content: "今日締め切りのタスクを教えて" }],
});

// tool_use ブロックを処理
if (response.stop_reason === "tool_use") {
  const toolUse = response.content.find((b) => b.type === "tool_use");
  if (toolUse && toolUse.type === "tool_use") {
    const results = await searchTasks(toolUse.input as SearchInput);
    // 結果を渡して再度 API 呼び出し
    const final = await client.messages.create({
      model: "claude-haiku-4-5",
      max_tokens: 1024,
      tools,
      messages: [
        { role: "user", content: "今日締め切りのタスクを教えて" },
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

## 3. プロンプトキャッシュ

同じシステムプロンプトを繰り返し使う場合、**最大 90% のコスト削減**が可能。

```typescript
const systemPrompt = `あなたは${appName}のカスタマーサポートです。
以下のFAQを参考に回答してください:
${faqContent}  // 長いFAQドキュメント
`;

const response = await client.messages.create({
  model: "claude-haiku-4-5",
  max_tokens: 512,
  system: [
    {
      type: "text",
      text: systemPrompt,
      cache_control: { type: "ephemeral" }, // キャッシュ対象
    },
  ],
  messages: [{ role: "user", content: userQuestion }],
});

// レスポンスヘッダーでキャッシュ状態を確認
// cache_read_input_tokens > 0 ならキャッシュヒット
console.log(response.usage);
```

**コスト比較** (claude-haiku-4-5):

```
通常: $0.25 / 1M input tokens
キャッシュ書き込み: $0.30 / 1M (1.2倍)
キャッシュ読み取り: $0.03 / 1M (0.12倍 → 88% 削減)
```

FAQ Bot や CS Bot など、同じ長文コンテキストを何度も使う場合は必ずキャッシュ有効化。

## まとめ

```
ストリーミング → 長文生成 / チャット UX (体感レイテンシ激減)
ツール使用    → DB 検索 / 計算 / 外部 API と AI を接続
キャッシュ    → 同一システムプロンプト繰り返しで最大 88% コスト削減
```

Edge Function は Deno ランタイム。`npm:@anthropic-ai/sdk` で直接インポート可能。
