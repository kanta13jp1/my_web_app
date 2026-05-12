---
title: "AIエージェント設計入門 — Dify / LangChain / raw API の選び方"
tags: AI,個人開発,automation,buildinpublic
published: true
---

# AIエージェント設計入門 — Dify / LangChain / raw API の選び方

AI エージェントを作りたいとき、最初に直面する問いは「何を使えばいいか」。Dify / LangChain / raw API の3択を実際に試した結果を公開する。

## 結論から

```
Dify:       ノーコード・ローコード / プロトタイプ / チームが非エンジニア中心
LangChain:  Python / 複雑なチェーン / OSS エコシステムが必要
raw API:    本番 / 制御が最重要 / Flutter + Supabase 統合
```

うちのプロジェクトは **raw API (Anthropic SDK + Deno Edge Function)** に落ち着いた。

## Dify が向くケース

```
# Dify のワークフロー設計画面
[入力] → [LLM ノード] → [条件分岐] → [ツールノード] → [出力]
```

Difyは GUI でフローを組むツール。**プロトタイプを3日で作れる**のが最大の強み。

```
✅ 向くケース:
- 非エンジニアメンバーがフロー編集する
- RAG パイプラインを素早く試したい
- ホスティング・インフラを触りたくない

❌ 向かないケース:
- 既存コードベースへの密な統合が必要
- カスタムロジックが複雑
- Dify の実行コストが高くなってきた
```

## LangChain が向くケース

```python
from langchain.agents import initialize_agent, Tool
from langchain.chat_models import ChatAnthropic

tools = [
    Tool(name="search", func=search_function, description="Web検索"),
    Tool(name="calculator", func=calc_function, description="計算"),
]

agent = initialize_agent(tools, ChatAnthropic(model="claude-haiku-4-5"), ...)
result = agent.run("今日の東京の天気は？")
```

LangChain は Python エコシステムが強力。**Vector Store / Retriever / Memory** の統合が豊富。

```
✅ 向くケース:
- RAG パイプラインの本格実装
- 多様な LLM を切り替えたい
- Python ベースのデータパイプラインがある

❌ 向かないケース:
- Flutter/Dart/Deno が主スタック → バインディングが薄い
- シンプルなAPIコール → オーバーヘッドが大きい
```

## raw API が向くケース (うちの選択)

```typescript
// Deno Edge Function での実装例
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

**raw API を選んだ理由**:

1. **Supabase Edge Function (Deno) が主環境** — LangChain の Python バインディング不要
2. **コスト制御** — haiku / sonnet / opus をロジック内で切り替えられる
3. **依存が最小** — ライブラリの破壊的変更に引きずられない
4. **RLS との統合** — Supabase の auth.uid() と直結できる

## 3択の判定フロー

```
エージェントを作りたい
  ↓
チームに非エンジニアがいる?
  Yes → Dify
  No ↓
Python が主スタック?
  Yes → LangChain
  No ↓
既存スタックへの密な統合が必要?
  Yes → raw API
  No → Dify (プロトタイプとして)
```

## Tool Use (Function Calling) のパターン

raw API で Tool Use を使う例:

```typescript
const tools = [
  {
    name: "get_race_data",
    description: "競馬レースデータを取得する",
    input_schema: {
      type: "object",
      properties: {
        race_id: { type: "string", description: "レースID" },
        date: { type: "string", description: "YYYY-MM-DD形式の日付" },
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
    messages: [{ role: 'user', content: '明日の中山競馬の予想をして' }],
  }),
});
```

Claude が `get_race_data` を呼ぶべきと判断したら、`tool_use` ブロックが返ってくる。

## コスト設計: モデル切り替え戦略

```typescript
// タスク種別でモデルを切り替える
function selectModel(taskType: string): string {
  switch (taskType) {
    case 'simple_qa':      return 'claude-haiku-4-5-20251001';   // $0.00025/1K
    case 'analysis':       return 'claude-sonnet-4-6';            // $0.003/1K
    case 'complex_design': return 'claude-opus-4-7';              // $0.015/1K
    default: return 'claude-haiku-4-5-20251001';
  }
}
```

うちの競馬予測システムでは:
- 基本分析: haiku ($0.00045/予測)
- 上位レース詳細分析: sonnet
- アーキテクチャ設計判断: opus (セッション単位)

## まとめ

AIエージェント設計の選択基準:

| 観点 | Dify | LangChain | raw API |
| --- | --- | --- | --- |
| 開発速度 | ◎ | ○ | △ |
| カスタマイズ性 | △ | ○ | ◎ |
| 既存スタック統合 | △ | ○ | ◎ |
| 運用コスト | △ | ○ | ◎ |
| 非エンジニア対応 | ◎ | △ | ✗ |

Flutter + Supabase 環境には raw API が最適。シンプルさと制御を両立できる。
