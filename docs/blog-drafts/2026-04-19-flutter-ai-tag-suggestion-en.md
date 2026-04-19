---
title: "Adding AI Tag Suggestions to Flutter Notes — Free Groq API for Real-Time Tagging"
tags: Flutter,Supabase,Groq,AI,buildinpublic,webdev
published: false
---

# Adding AI Tag Suggestions to Flutter Notes

## The Problem with Manual Tagging

After writing a note, deciding which tags to apply is cognitive overhead. You've just finished organizing your thoughts — now you have to switch mental modes to classify them. AI can handle this automatically.

## Architecture Choice

Rather than creating a new Supabase Edge Function, I reused the **existing `ai-hub` EF's `provider.chat` action**:

```
Flutter → AIService.suggestTags() → ai-hub:provider.chat (Groq llama-3.3-70b) → TagSuggestion
```

Groq's llama-3.3-70b has a **free tier and responds in under 100ms** — perfect for lightweight tasks like tag generation.

## Implementation

### TagSuggestion Model

```dart
class TagSuggestion {
  final List<String> tags;
  final String category;
  final String reason;

  const TagSuggestion({
    required this.tags,
    required this.category,
    required this.reason,
  });

  factory TagSuggestion.fromJson(Map<String, dynamic> json) => TagSuggestion(
    tags: List<String>.from(json['tags'] ?? []),
    category: json['category'] ?? '',
    reason: json['reason'] ?? '',
  );
}
```

### AIService.suggestTags()

```dart
Future<TagSuggestion> suggestTags({
  required String content,
  String? title,
}) async {
  final prompt = '''
Suggest 5-10 relevant tags for the following note.
Title: ${title ?? '(none)'}
Content: $content

Respond in JSON:
{
  "tags": ["tag1", "tag2", ...],
  "category": "category name",
  "reason": "why these tags"
}
''';

  final response = await _callAiHub(
    action: 'provider.chat',
    provider: 'groq',
    model: 'llama-3.3-70b-versatile',
    prompt: prompt,
  );

  // Strip code blocks if present
  final cleaned = response['content']
    .replaceAll(RegExp(r'```json\s*'), '')
    .replaceAll(RegExp(r'```\s*'), '')
    .trim();

  return TagSuggestion.fromJson(json.decode(cleaned));
}
```

### UI Page

```dart
class AiSuggestTagsPage extends StatefulWidget {
  const AiSuggestTagsPage({super.key});
}

class _AiSuggestTagsPageState extends State<AiSuggestTagsPage> {
  final _aiService = AIService();
  TagSuggestion? _suggestion;
  bool _isLoading = false;

  Future<void> _suggestTags() async {
    setState(() => _isLoading = true);
    try {
      final result = await _aiService.suggestTags(
        content: _controller.text.trim(),
      );
      setState(() => _suggestion = result);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Tag Suggestions')),
      body: Column(
        children: [
          TextField(controller: _controller, maxLines: 5),
          if (_isLoading) const CircularProgressIndicator(),
          if (_suggestion != null)
            Wrap(
              spacing: 8,
              children: _suggestion!.tags
                .map((tag) => Chip(label: Text('#$tag')))
                .toList(),
            ),
          ElevatedButton(
            onPressed: _suggestTags,
            child: const Text('Suggest Tags'),
          ),
        ],
      ),
    );
  }
}
```

## Gotchas

### The old `ai-suggest-tags` EF was actually an SVG generator

There was a dedicated EF named `ai-suggest-tags` but its actual implementation was a quote SVG generator — a naming mismatch. It was removed during EF cap cleanup.

The fix: call `ai-hub:provider.chat` directly. No new EF needed, no cap slot consumed.

### Groq sometimes wraps JSON in code fences

```dart
String cleanJson(String raw) => raw
  .replaceAll(RegExp(r'```json\s*'), '')
  .replaceAll(RegExp(r'```\s*'), '')
  .trim();
```

## Results

| Metric | Value |
|--------|-------|
| Implementation effort | 1 new method in AIService |
| New EFs created | 0 (reuses ai-hub) |
| Response time | ~100ms (Groq) |
| Cost | Free tier |

The hub pattern lets you add AI features without consuming EF cap slots. `ai-hub:provider.chat` becomes a universal AI gateway.

---
Building in public: https://my-web-app-b67f4.web.app/
#Flutter #Groq #AI #buildinpublic #EdgeFunctions
