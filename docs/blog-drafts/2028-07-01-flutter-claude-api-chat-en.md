---
title: "Flutter × Claude API — Build an AI Chat Feature from Scratch"
tags: flutter,ai,indiedev,automation
published: true
---

# Flutter × Claude API — Build an AI Chat Feature from Scratch

Wire Claude API into a Flutter app and ship a polished AI chat UI.

## Proxy Through a Supabase Edge Function

```typescript
// supabase/functions/ai-chat/index.ts
import Anthropic from "npm:@anthropic-ai/sdk";

const client = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });

Deno.serve(async (req) => {
  const { messages, system } = await req.json();

  const response = await client.messages.create({
    model: "claude-haiku-4-5",
    max_tokens: 1024,
    system: system ?? "You are a helpful assistant.",
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

## Flutter Chat UI

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
      appBar: AppBar(title: const Text('AI Chat')),
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
                      style: TextStyle(color: isUser ? Colors.white : null),
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
                      hintText: 'Type a message...',
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

## Streaming for Faster Perceived Response

```typescript
// Stream tokens from the Edge Function
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
// Receive SSE in Flutter via http.Client() + StreamedResponse
```

## Summary

```
Architecture → Flutter → Supabase EF → Claude API (never embed the API key in Flutter)
Core logic   → accumulate a messages array for multi-turn conversation
UI           → Align + Container for chat bubble layout
Streaming    → SSE token-by-token display (dramatically better perceived speed)
```

The Edge Function proxy keeps the API key server-side — zero exposure to the client.
