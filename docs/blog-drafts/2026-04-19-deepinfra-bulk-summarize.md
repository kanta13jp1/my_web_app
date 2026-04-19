---
title: "DeepInfra Llama-3.1-70BでノートのAIバルク要約を実装した — コスト$0.07/1Mトークン"
tags: AI,Flutter,Supabase,個人開発,buildinpublic
published: false
---

# DeepInfra Llama-3.1-70BでノートのAIバルク要約を実装した

## なぜ DeepInfra か

ノートのバルク要約は「大量テキスト × 繰り返し処理」のユースケース。
コストが積み上がる処理に Claude Sonnet を使うのは割高すぎる。

DeepInfra の `meta-llama/Llama-3.1-70B-Instruct` は:
- **$0.07/1M tokens** (入力) — Sonnet の約20分の1
- OpenAI 互換 API — 既存 Groq/OpenAI コードをほぼそのまま流用可
- 70Bモデルなので要約精度は実用レベル

## AI振り分けの最新版

| タスク | 選択AI | 単価 (入力) |
|-------|-------|------------|
| タグ提案 | Groq llama-3.3-70b | 無料枠 |
| **バルク要約** | **DeepInfra llama-3.1-70b** | **$0.07/1M** |
| バランス推敲 | Nebius llama-3.3-70b | $0.10/1M |
| 長文要約 | Claude Haiku | $0.25/1M |
| 設計判断 | Claude Sonnet | $3.00/1M |

バルク処理は「安いモデル × 大量」が最適解。

## Supabase Edge Function 実装

```typescript
// ai-hub/index.ts (action: "notes.bulk_summarize")
case "notes.bulk_summarize": {
  const { notes } = body; // [{ id: string, content: string }]

  const summaries = await Promise.all(
    notes.map(async (note: { id: string; content: string }) => {
      const response = await fetch(
        "https://api.deepinfra.com/v1/openai/chat/completions",
        {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${Deno.env.get("DEEPINFRA_API_KEY")}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            model: "meta-llama/Llama-3.1-70B-Instruct",
            messages: [
              {
                role: "system",
                content: "ノートを1〜2文で要約してください。日本語で。",
              },
              { role: "user", content: note.content.slice(0, 1000) },
            ],
            max_tokens: 100,
            temperature: 0.2,
          }),
        }
      );

      const data = await response.json();
      return {
        id: note.id,
        summary: data.choices[0].message.content,
      };
    })
  );

  return new Response(JSON.stringify({ summaries }), {
    headers: { "Content-Type": "application/json" },
  });
}
```

`Promise.all` で並列処理 → 10件でも約1〜2秒で完了。

## Flutter 側: 一括取得して表示

```dart
// note_list_page.dart
Future<void> _bulkSummarize(List<Note> notes) async {
  final response = await Supabase.instance.client.functions.invoke(
    'ai-hub',
    body: {
      'action': 'notes.bulk_summarize',
      'notes': notes.map((n) => {
        'id': n.id,
        'content': n.content,
      }).toList(),
    },
  );

  final summaries = (response.data['summaries'] as List)
      .cast<Map<String, dynamic>>();

  setState(() {
    for (final s in summaries) {
      _summaryMap[s['id'] as String] = s['summary'] as String;
    }
  });
}
```

ノート一覧画面で「AIで全要約」ボタンを押すと一括更新。

## コスト試算

| 条件 | コスト |
|------|--------|
| ノート100件 × 平均500tokens | $0.0035 (0.35円) |
| ノート1000件 × 平均500tokens | $0.035 (3.5円) |
| 月1000ユーザー × 各100件 | $3.5/月 |

個人開発の規模なら **月$3.5以下** に収まる計算。

## まとめ

バルク処理は「安いモデルで量をこなす」が正解。
DeepInfra はOpenAI互換なので移行コストが低く、
既存の Groq/Claude コードを数行書き換えるだけで使える。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#AI #Flutter #Supabase #buildinpublic #個人開発
