---
title: "LLM 統合アプリの設計パターン — Function Calling / RAG / Agent の選び方"
tags: AI,個人開発,automation,buildinpublic
published: true
---

# LLM 統合アプリの設計パターン — Function Calling / RAG / Agent の選び方

Claude / GPT-4 をアプリに統合するとき、3つのパターンがある。「どれをいつ使うか」を整理する。

## 3パターンの概観

```
Function Calling: LLM にツールを与える → 構造化データを返す
RAG:             LLM に知識を与える → コンテキスト付きで回答
Agent:           LLM に計画・実行を委ねる → 複数ステップを自律実行
```

複雑さと制御コストのトレードオフ。単純な要件では Function Calling から始める。

## パターン1: Function Calling

LLM が「どの関数を呼ぶか」を判断。構造化データを確実に返せる:

```dart
// Flutter → Supabase EF 経由で Claude API 呼び出し
final response = await supabase.functions.invoke(
  'ai-assistant',
  body: {
    'message': userMessage,
    'mode': 'function_calling',
  },
);
```

```typescript
// Edge Function 側: Function Calling の設定
const tools = [
  {
    name: 'create_task',
    description: 'ユーザーのタスクを作成する',
    input_schema: {
      type: 'object',
      properties: {
        title: { type: 'string', description: 'タスクのタイトル' },
        due_date: { type: 'string', description: 'YYYY-MM-DD 形式の期日' },
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

// ツール使用を検出して実行
if (message.stop_reason === 'tool_use') {
  const toolUse = message.content.find(b => b.type === 'tool_use');
  if (toolUse?.name === 'create_task') {
    await supabase.from('tasks').insert(toolUse.input);
  }
}
```

**適用場面**: フォーム入力の自然言語化 / 予定の自動作成 / データ抽出

## パターン2: RAG (Retrieval-Augmented Generation)

外部知識をベクター検索して LLM に渡す。知識の鮮度と精度が上がる:

```typescript
// Edge Function: RAG パイプライン
async function ragQuery(userQuery: string, supabase: SupabaseClient) {
  // 1. クエリをベクター化
  const embeddingRes = await fetch('https://api.openai.com/v1/embeddings', {
    method: 'POST',
    headers: { Authorization: `Bearer ${Deno.env.get('OPENAI_API_KEY')}` },
    body: JSON.stringify({ model: 'text-embedding-3-small', input: userQuery }),
  });
  const { data } = await embeddingRes.json();
  const embedding = data[0].embedding;

  // 2. pgvector で近傍検索
  const { data: docs } = await supabase.rpc('match_documents', {
    query_embedding: embedding,
    match_threshold: 0.78,
    match_count: 5,
  });

  // 3. コンテキストを組み立てて Claude に渡す
  const context = docs.map(d => d.content).join('\n\n');
  const response = await anthropic.messages.create({
    model: 'claude-haiku-4-5-20251001',
    max_tokens: 1024,
    messages: [{
      role: 'user',
      content: `以下のコンテキストを参考に回答してください:\n\n${context}\n\n質問: ${userQuery}`,
    }],
  });

  return response.content[0].text;
}
```

```sql
-- pgvector: 近傍検索関数
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

**適用場面**: AI大学の質問応答 / ドキュメント検索 / カスタマーサポート自動化

## パターン3: Agent (自律実行)

複数ステップを LLM が計画・実行。人手を最小化できるが、制御が難しい:

```typescript
// Edge Function: 簡易エージェントループ
async function runAgent(goal: string, maxSteps = 5) {
  const messages = [
    {
      role: 'user',
      content: `目標: ${goal}\n利用可能なツール: search_web, create_draft, send_email`,
    },
  ];

  for (let step = 0; step < maxSteps; step++) {
    const response = await anthropic.messages.create({
      model: 'claude-sonnet-4-6',
      max_tokens: 2048,
      tools,
      messages,
    });

    if (response.stop_reason === 'end_turn') break;  // 完了

    if (response.stop_reason === 'tool_use') {
      // ツール実行 → 結果を messages に追加 → 次のループへ
      const toolResult = await executeTool(response.content);
      messages.push({ role: 'assistant', content: response.content });
      messages.push({ role: 'user', content: [{ type: 'tool_result', ...toolResult }] });
    }
  }

  return messages;
}
```

**適用場面**: GHA Schedule タスク / 競合モニタリング / 週次レポート自動生成

## 選び方のフローチャート

```
構造化データが必要? → Function Calling
↓ No
外部知識が必要? → RAG
↓ No
複数ステップが必要? → Agent
↓ No
単純な補完 → raw API (messages のみ)
```

**コスト順**: raw API < Function Calling < RAG < Agent

## まとめ

```
Function Calling: 構造化出力 + ツール実行 → 最もシンプルで確実
RAG:             知識の注入 → 精度が必要な QA に最適
Agent:           自律実行 → GHA タスク / 定期バッチに強い
```

LLM 統合は「一番シンプルなパターン」から始めて、行き詰まったら進化させる。これが個人開発での LLM 活用の鉄則だ。
