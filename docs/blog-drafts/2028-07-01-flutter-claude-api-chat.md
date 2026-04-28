---
title: "Flutter × Claude API — AI チャット機能をゼロから実装する"
tags: flutter,AI,個人開発,automation
published: true
---

# Flutter × Claude API — AI チャット機能をゼロから実装する

Claude API を Flutter に組み込んで、本格的な AI チャット UI を作る。

## Supabase Edge Function でプロキシ

```typescript
// supabase/functions/ai-chat/index.ts
import Anthropic from "npm:@anthropic-ai/sdk";

const client = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });

Deno.serve(async (req) => {
  const { messages, system } = await req.json();

  const response = await client.messages.create({
    model: "claude-haiku-4-5",
    max_tokens: 1024,
    system: system ?? "あなたは役に立つアシスタントです。",
    messages,
  });

  const text = response.content
    .filter((b) => b.type === "text")
    .map((b) => b.text)
    .join("");

  return new Response(JSON.stringify({ text }), {
    headers: { "Content-Type": "application/json" },
  });
});
```

## Flutter チャット UI

```dart
class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final _messages = <Map<String, String>>[];
  final _controller = TextEditingController();
  bool _loading = false;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _loading = true;
    });
    _controller.clear();

    final res = await supabase.functions.invoke(
      'ai-chat',
      body: {'messages': _messages},
    );

    final reply = (res.data as Map)['text'] as String;
    setState(() {
      _messages.add({'role': 'assistant', 'content': reply});
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI チャット')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final msg = _messages[i];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg['content']!,
                      style: TextStyle(
                        color: isUser ? Colors.white : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'メッセージを入力...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _loading ? null : _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

## ストリーミング対応 (応答速度を改善)

```typescript
// Edge Function でストリーミング
const stream = await client.messages.stream({
  model: "claude-haiku-4-5",
  max_tokens: 1024,
  messages,
});

return new Response(stream.toReadableStream(), {
  headers: {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
  },
});
```

```dart
// Flutter でストリーミング受信
final channel = supabase.channel('ai-stream');
// または http.Client() + StreamedResponse で SSE 受信
```

## まとめ

```
アーキテクチャ → Flutter → Supabase EF → Claude API (API key を Flutter に直書きしない)
基本実装     → messages 配列を累積してマルチターン会話
UI          → Align + Container で吹き出し UI
ストリーミング → SSE で一文字ずつ表示 (体感速度 ↑)
```

EF をプロキシ層にすることで API key の漏洩リスクをゼロにできる。
