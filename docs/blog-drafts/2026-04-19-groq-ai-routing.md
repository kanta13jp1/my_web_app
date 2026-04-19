---
title: "Groq llama-3.3-70bをタグ提案に使う — 低レイテンシAIルーティングの実装パターン"
tags: Groq,AI,Flutter,Supabase,個人開発
published: false
---

# Groq llama-3.3-70bをタグ提案に使う

## なぜ Groq か

タグ提案は「速さが命」の処理です:
- ユーザーがノートを書きながらリアルタイムでタグ候補を表示したい
- 1〜3秒のレスポンスを期待している
- 精度はそこそこでよい (完璧でなくて良い)

Claude Sonnet は精度が高いが、タグ提案には **過剰** です。
Groq の `llama-3.3-70b` は **無料枠あり + 400トークン/秒** の高速推論で
このユースケースにちょうど合います。

## AI振り分け早見表 (このプロジェクトの基準)

| タスク | 選択AI | 理由 |
|-------|-------|------|
| タグ提案 | Groq llama-3.3-70b | 速度優先・無料枠あり |
| 長文要約 | Claude Haiku | コスト安・品質安定 |
| 設計判断 | Claude Sonnet | 精度最優先 |
| 競合調査 | NotebookLM | 無料・大量ドキュメント処理 |
| 画像生成 | Nano Banana API | Gemini Imagen 統合 |

「何でもClaude」より **タスク別最適ルーティング** の方がコスト/速度ともに有利です。

## Supabase Edge Function での実装

```typescript
// ai-hub/index.ts (action: "tags.suggest")
case "tags.suggest": {
  const { text } = body;
  
  const response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${Deno.env.get("GROQ_API_KEY")}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "llama-3.3-70b-versatile",
      messages: [
        {
          role: "system",
          content: "タグを3〜5個、カンマ区切りで提案してください。日本語で。",
        },
        { role: "user", content: text.slice(0, 500) }, // コスト節約
      ],
      max_tokens: 50,
      temperature: 0.3,
    }),
  });

  const data = await response.json();
  const tags = data.choices[0].message.content
    .split(",")
    .map((t: string) => t.trim())
    .filter((t: string) => t.length > 0);

  return new Response(JSON.stringify({ tags }), {
    headers: { "Content-Type": "application/json" },
  });
}
```

## Flutter 側: debounce でリアルタイム提案

```dart
// note_editor_page.dart
Timer? _tagDebounce;

void _onNoteChanged(String text) {
  _tagDebounce?.cancel();
  _tagDebounce = Timer(const Duration(milliseconds: 800), () {
    if (text.length > 50) {
      _fetchTagSuggestions(text);
    }
  });
}

Future<void> _fetchTagSuggestions(String text) async {
  final response = await Supabase.instance.client.functions.invoke(
    'ai-hub',
    body: {'action': 'tags.suggest', 'text': text},
  );
  
  final tags = List<String>.from(response.data['tags'] ?? []);
  if (mounted) setState(() => _suggestedTags = tags);
}
```

800msのdebounceで「入力中は呼ばない」→ API コスト削減。

## Groq の制約と対処

| 制約 | 対処 |
|------|------|
| 無料枠: 30リクエスト/分 | debounce 800ms + rate limit ガード |
| コンテキスト長: 8K tokens | 入力を500文字にスライス |
| 日本語精度: やや低め | system promptで「日本語で」を強制 |

Groq の無料枠を超えたらエラーになるので、フォールバックを用意しておく:

```typescript
if (!response.ok) {
  // Groqがレート制限 → Claude Haiku にフォールバック
  return suggestTagsWithClaude(text);
}
```

## まとめ

タグ提案のような「速度優先・精度そこそこ」タスクには Groq llama-3.3-70b が最適。
AI機能を設計するとき「このタスクに本当にClaude Sonnetが必要か?」を問うことが
コスト削減の第一歩です。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#Groq #AI #Flutter #Supabase #個人開発
