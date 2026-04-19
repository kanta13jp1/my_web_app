---
title: "NebiusのLlama-3.3-70BでFlutterノートのバランス推敲機能を実装した"
tags: AI,Flutter,Supabase,個人開発,buildinpublic
published: true
---

# NebiusのLlama-3.3-70BでFlutterノートのバランス推敲機能を実装した

## バランス推敲とは

「バランス推敲」は文章の **構造的なアンバランスを検出して修正提案する** 機能。

具体的には:
- 段落の長さが偏っている (1段落だけ極端に長い)
- 箇条書きの粒度が統一されていない
- 結論が弱い / 導入が長すぎる

これはスペルチェックより高度だが、Claude Sonnetほどの精度は不要。
Nebius の `llama-3.3-70b` ($0.10/1M tokens) がコスト/品質バランスに最適だった。

## AI振り分けの位置づけ

| タスク | 選択AI | 理由 |
|-------|-------|------|
| タグ提案 | Groq | 速度 |
| バルク要約 | DeepInfra | 量×低コスト |
| **バランス推敲** | **Nebius Llama-3.3-70b** | **中程度のコスト、分析品質** |
| 文書全体の改善提案 | Claude Haiku | 品質優先 |

## Supabase Edge Function 実装

```typescript
// ai-hub/index.ts (action: "notes.balance_review")
case "notes.balance_review": {
  const { content } = body;

  const response = await fetch(
    "https://api.studio.nebius.ai/v1/chat/completions",
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${Deno.env.get("NEBIUS_API_KEY")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "meta-llama/Llama-3.3-70B-Instruct",
        messages: [
          {
            role: "system",
            content: `文章のバランスを分析して改善点を3点以内で提案してください。
JSON形式で返してください: {"issues": [{"type": "段落バランス|箇条書き粒度|結論強化", "description": "...", "suggestion": "..."}]}`,
          },
          { role: "user", content: content.slice(0, 2000) },
        ],
        max_tokens: 300,
        temperature: 0.3,
        response_format: { type: "json_object" },
      }),
    }
  );

  const data = await response.json();
  const result = JSON.parse(data.choices[0].message.content);

  return new Response(JSON.stringify(result), {
    headers: { "Content-Type": "application/json" },
  });
}
```

`response_format: { type: "json_object" }` でJSON強制 → パースエラー回避。

## Flutter 側の実装

```dart
// note_editor_page.dart
Future<void> _requestBalanceReview() async {
  setState(() => _reviewLoading = true);

  try {
    final response = await Supabase.instance.client.functions.invoke(
      'ai-hub',
      body: {
        'action': 'notes.balance_review',
        'content': _controller.text,
      },
    );

    final issues = (response.data['issues'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    if (mounted) {
      setState(() {
        _reviewIssues = issues;
        _reviewLoading = false;
      });
    }
  } catch (e) {
    setState(() => _reviewLoading = false);
  }
}
```

エディタ下部に「バランスチェック」ボタン → 結果をカードで表示。

## Nebius の特徴と制約

| 項目 | 内容 |
|------|------|
| エンドポイント | `api.studio.nebius.ai/v1/` (OpenAI互換) |
| 対応モデル | Llama-3.3-70B / DeepSeek-V3 等 |
| 料金 | $0.10/1M tokens (入力) |
| JSON mode | ✅ サポート |
| 日本語精度 | 実用レベル (70Bクラス) |

Groq (速度優先) と DeepInfra (コスト優先) の中間に位置する選択肢。

## まとめ

ルーティングの考え方:
- **即時フィードバック (タグ提案)** → Groq (速度最優先)
- **大量バッチ (要約)** → DeepInfra (コスト最優先)
- **品質要求が中程度の分析** → Nebius (バランス)
- **最高品質が必要** → Claude

OpenAI互換APIでどのプロバイダーも同じコードで切り替え可能な点が強み。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#AI #Flutter #Supabase #buildinpublic #個人開発
